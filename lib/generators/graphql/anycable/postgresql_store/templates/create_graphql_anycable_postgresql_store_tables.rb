# frozen_string_literal: true

class CreateGraphqlAnycablePostgresqlStoreTables < ActiveRecord::Migration<%= migration_version %>
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS graphql_anycable_subscriptions (
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

      CREATE TABLE IF NOT EXISTS graphql_anycable_subscription_events (
        subscription_id text NOT NULL REFERENCES graphql_anycable_subscriptions(id) ON DELETE CASCADE,
        topic text NOT NULL,
        fingerprint text NOT NULL,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (subscription_id, topic, fingerprint)
      );

      CREATE INDEX IF NOT EXISTS index_graphql_anycable_subscription_events_topic_fingerprint
        ON graphql_anycable_subscription_events (topic, fingerprint);

      CREATE TABLE IF NOT EXISTS graphql_anycable_channel_subscriptions (
        channel_id text NOT NULL,
        subscription_id text NOT NULL REFERENCES graphql_anycable_subscriptions(id) ON DELETE CASCADE,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (channel_id, subscription_id)
      );
    SQL
  end

  def down
    execute <<~SQL
      DROP TABLE IF EXISTS graphql_anycable_channel_subscriptions;
      DROP TABLE IF EXISTS graphql_anycable_subscription_events;
      DROP TABLE IF EXISTS graphql_anycable_subscriptions;
    SQL
  end
end
