# frozen_string_literal: true

require "anyway"

module GraphQL
  module AnyCable
    module PostgreSQLStore
      class Config < Anyway::Config
        config_name :graphql_anycable_postgresql_store
        env_prefix :graphql_anycable_postgresql_store

        attr_config postgres_url: nil
        attr_config subscriptions_table: "graphql_anycable_subscriptions"
        attr_config subscription_events_table: "graphql_anycable_subscription_events"
        attr_config channel_subscriptions_table: "graphql_anycable_channel_subscriptions"
      end
    end
  end
end
