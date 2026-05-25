# frozen_string_literal: true

require "json"
require "pg"

RSpec.describe GraphQL::AnyCable::PostgreSQLStore do
  it "registers PostgreSQL store aliases with graphql-anycable" do
    registry = GraphQL::AnyCable.send(:subscription_store_registry)

    expect(registry).to include(:postgresql, :postgres)
  end

  it "builds PostgreSQL stores through the registered graphql-anycable aliases" do
    original_subscription_store = GraphQL::AnyCable.config.subscription_store
    original_memoized_store = GraphQL::AnyCable.instance_variable_get(:@subscription_store)
    had_memoized_store = GraphQL::AnyCable.instance_variable_defined?(:@subscription_store)

    [:postgresql, :postgres].each do |subscription_store|
      GraphQL::AnyCable.remove_instance_variable(:@subscription_store) if GraphQL::AnyCable.instance_variable_defined?(:@subscription_store)
      GraphQL::AnyCable.config.subscription_store = subscription_store

      expect(GraphQL::AnyCable.subscription_store).to be_a(GraphQL::AnyCable::PostgreSQLStore::Store)
    end
  ensure
    GraphQL::AnyCable.config.subscription_store = original_subscription_store
    GraphQL::AnyCable.remove_instance_variable(:@subscription_store) if GraphQL::AnyCable.instance_variable_defined?(:@subscription_store)
    GraphQL::AnyCable.instance_variable_set(:@subscription_store, original_memoized_store) if had_memoized_store
  end
end

RSpec.describe GraphQL::AnyCable::PostgreSQLStore::Store do
  StoreConfig = Struct.new(
    :postgres_url,
    :subscriptions_table,
    :subscription_events_table,
    :channel_subscriptions_table,
    keyword_init: true
  )
  GraphQLConfig = Struct.new(:redis_prefix, keyword_init: true)

  let(:postgres_url) { ENV["POSTGRES_URL"] || ENV["DATABASE_URL"] }
  let(:config) do
    store_config(
      postgres_url: postgres_url,
      subscriptions_table: "graphql_anycable_test_subscriptions",
      subscription_events_table: "graphql_anycable_test_subscription_events",
      channel_subscriptions_table: "graphql_anycable_test_channel_subscriptions"
    )
  end
  let(:store) { described_class.new(config: config, graphql_config: graphql_config) }
  let(:graphql_config) { GraphQLConfig.new(redis_prefix: "graphql") }
  let(:subscription_id) { "postgresql-store-subscription" }
  let(:channel_id) { "postgresql-store-channel" }
  let(:events) { [double(topic: "productUpdated", fingerprint: "fingerprint-1")] }
  let(:data) do
    {
      query_string: "subscription { productUpdated { id } }",
      variables: "{}",
      context: "serialized-context",
      operation_name: "ProductUpdated",
      events: {"productUpdated" => "fingerprint-1"}.to_json
    }
  end

  describe "without a database connection" do
    let(:config) { store_config(postgres_url: "postgres://configured") }

    it "builds stream names with the configured graphql-anycable prefix" do
      expect(store.stream_for("fingerprint-1")).to eq("graphql-subscriptions:fingerprint-1")
    end

    it "returns an empty fingerprint result without opening a database connection" do
      expect(PG).not_to receive(:connect)

      expect(store.subscription_ids_for_fingerprints([])).to eq({})
    end

    it "uses the configured PostgreSQL URL when opening the connection" do
      result = double("PG::Result")
      connection = double("PG::Connection")

      allow(result).to receive(:getvalue).with(0, 0).and_return("t")
      allow(connection).to receive(:exec_params).and_return(result)
      expect(PG).to receive(:connect).with("postgres://configured").and_return(connection)

      expect(store.subscription_exists?("subscription-1")).to be true
    end

    it "quotes configured table names before interpolating them into SQL" do
      captured_sql = nil
      connection = double("PG::Connection")
      config = store_config(
        subscriptions_table: "store_schema.subscriptions",
        subscription_events_table: "store_schema.subscription_events",
        channel_subscriptions_table: "store_schema.channel_subscriptions"
      )
      store = described_class.new(config: config, graphql_config: graphql_config)

      allow(connection).to receive(:exec_params) do |sql, _params|
        captured_sql = sql
        []
      end
      store.instance_variable_set(:@connection, connection)

      store.fingerprints_for_topic("productUpdated")

      expect(captured_sql).to include('"store_schema"."subscription_events"')
      expect(captured_sql).to include('"store_schema"."subscriptions"')
    end

    it "rejects empty and over-qualified table names" do
      expect do
        described_class.new(config: store_config(subscriptions_table: ""), graphql_config: graphql_config)
      end.to raise_error(ArgumentError, "PostgreSQL table name cannot be empty")

      expect do
        described_class.new(config: store_config(subscriptions_table: "one.two.three"), graphql_config: graphql_config)
      end.to raise_error(ArgumentError, "PostgreSQL table name must be table or schema.table")
    end
  end

  describe "with PostgreSQL" do
    before do
      skip "POSTGRES_URL or DATABASE_URL is required" unless postgres_url

      create_tables
    end

    after do
      drop_tables if postgres_url
      connection.close if postgres_url && !connection.finished?
    end

    it "stores, indexes, reads, and deletes subscriptions" do
      store.write_subscription(
        subscription_id,
        channel_id: channel_id,
        data: data,
        events: events,
        expiration_seconds: nil
      )

      expect(store.stream_for("fingerprint-1")).to eq("graphql-subscriptions:fingerprint-1")
      expect(store.fingerprints_for_topic("productUpdated")).to eq(["fingerprint-1"])
      expect(store.subscription_ids_for_fingerprints(["fingerprint-1"])).to eq("fingerprint-1" => [subscription_id])
      expect(store.subscription_exists?(subscription_id)).to be true
      expect(store.read_subscription(subscription_id)).to include(data.slice(:query_string, :variables, :context, :operation_name))

      store.delete_channel_subscriptions(channel_id)

      expect(store.subscription_exists?(subscription_id)).to be false
      expect(store.fingerprints_for_topic("productUpdated")).to eq([])
    end

    it "filters expired subscriptions from reads and indexes" do
      store.write_subscription(
        subscription_id,
        channel_id: channel_id,
        data: data,
        events: events,
        expiration_seconds: -1
      )

      expect(store.subscription_exists?(subscription_id)).to be false
      expect(store.read_subscription(subscription_id)).to be_nil
      expect(store.fingerprints_for_topic("productUpdated")).to eq([])
      expect(store.subscription_ids_for_fingerprints(["fingerprint-1"])).to eq("fingerprint-1" => [])
    end

    it "replaces indexed events and channel bindings when a subscription is rewritten" do
      store.write_subscription(
        subscription_id,
        channel_id: "channel-old",
        data: data.merge(events: {"topicOld" => "fingerprint-old"}.to_json),
        events: [double(topic: "topicOld", fingerprint: "fingerprint-old")],
        expiration_seconds: nil
      )
      store.write_subscription(
        subscription_id,
        channel_id: "channel-new",
        data: data.merge(events: {"topicNew" => "fingerprint-new"}.to_json),
        events: [double(topic: "topicNew", fingerprint: "fingerprint-new")],
        expiration_seconds: nil
      )

      expect(store.fingerprints_for_topic("topicOld")).to eq([])
      expect(store.fingerprints_for_topic("topicNew")).to eq(["fingerprint-new"])
      expect(store.subscription_ids_for_fingerprints(["fingerprint-old", "fingerprint-new"])).to eq(
        "fingerprint-old" => [],
        "fingerprint-new" => [subscription_id]
      )

      store.delete_channel_subscriptions("channel-old")
      expect(store.subscription_exists?(subscription_id)).to be true

      store.delete_channel_subscriptions("channel-new")
      expect(store.subscription_exists?(subscription_id)).to be false
    end

    it "groups fingerprints by topic and returns subscriptions for each requested fingerprint" do
      write_subscription("subscription-1", "channel-1", "topic", "fingerprint-b")
      write_subscription("subscription-2", "channel-2", "topic", "fingerprint-a")
      write_subscription("subscription-3", "channel-3", "topic", "fingerprint-b")
      write_subscription("subscription-4", "channel-4", "other-topic", "fingerprint-c")

      expect(store.fingerprints_for_topic("topic")).to eq(["fingerprint-a", "fingerprint-b"])
      expect(store.subscription_ids_for_fingerprints(["fingerprint-a", "fingerprint-b", "fingerprint-missing"])).to eq(
        "fingerprint-a" => ["subscription-2"],
        "fingerprint-b" => ["subscription-1", "subscription-3"],
        "fingerprint-missing" => []
      )
    end

    it "deletes one subscription without deleting other subscriptions on the same fingerprint" do
      write_subscription("subscription-1", "channel-1", "topic", "fingerprint-shared")
      write_subscription("subscription-2", "channel-2", "topic", "fingerprint-shared")

      store.delete_subscription("subscription-1")

      expect(store.subscription_exists?("subscription-1")).to be false
      expect(store.subscription_exists?("subscription-2")).to be true
      expect(store.subscription_ids_for_fingerprints(["fingerprint-shared"])).to eq(
        "fingerprint-shared" => ["subscription-2"]
      )
    end
  end

  private

  def store_config(overrides = {})
    StoreConfig.new({
      postgres_url: nil,
      subscriptions_table: "graphql_anycable_subscriptions",
      subscription_events_table: "graphql_anycable_subscription_events",
      channel_subscriptions_table: "graphql_anycable_channel_subscriptions"
    }.merge(overrides))
  end

  def connection
    @connection ||= PG.connect(postgres_url)
  end

  def write_subscription(subscription_id, channel_id, topic, fingerprint)
    store.write_subscription(
      subscription_id,
      channel_id: channel_id,
      data: data.merge(events: {topic => fingerprint}.to_json),
      events: [double(topic: topic, fingerprint: fingerprint)],
      expiration_seconds: nil
    )
  end

  def create_tables
    drop_tables
    connection.exec(<<~SQL)
      CREATE TABLE graphql_anycable_test_subscriptions (
        id text PRIMARY KEY,
        query_string text NOT NULL,
        variables text NOT NULL,
        context text NOT NULL,
        operation_name text NOT NULL,
        events jsonb NOT NULL DEFAULT '{}',
        expires_at timestamp,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE graphql_anycable_test_subscription_events (
        subscription_id text NOT NULL REFERENCES graphql_anycable_test_subscriptions(id) ON DELETE CASCADE,
        topic text NOT NULL,
        fingerprint text NOT NULL,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (subscription_id, topic, fingerprint)
      );

      CREATE INDEX index_graphql_anycable_test_events_topic_fingerprint
        ON graphql_anycable_test_subscription_events (topic, fingerprint);

      CREATE TABLE graphql_anycable_test_channel_subscriptions (
        channel_id text NOT NULL,
        subscription_id text NOT NULL REFERENCES graphql_anycable_test_subscriptions(id) ON DELETE CASCADE,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (channel_id, subscription_id)
      );
    SQL
  end

  def drop_tables
    connection.exec(<<~SQL)
      DROP TABLE IF EXISTS graphql_anycable_test_channel_subscriptions;
      DROP TABLE IF EXISTS graphql_anycable_test_subscription_events;
      DROP TABLE IF EXISTS graphql_anycable_test_subscriptions;
    SQL
  end
end
