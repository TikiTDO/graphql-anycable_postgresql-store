# frozen_string_literal: true

module GraphQL
  module AnyCable
    module PostgreSQLStore
      class Store
        class Cleaner
          def initialize(connection_provider:, subscriptions_table:, events_table:, channels_table:)
            @connection_provider = connection_provider
            @subscriptions_table = subscriptions_table
            @events_table = events_table
            @channels_table = channels_table
          end

          def clean
            clean_subscriptions
            clean_fingerprint_subscriptions
            clean_channels
            clean_topic_fingerprints
          end

          def clean_channels
            with_connection do |conn|
              conn.exec_params(<<~SQL)
                DELETE FROM #{channels_table} channels
                WHERE NOT EXISTS (
                  SELECT 1
                  FROM #{subscriptions_table} subscriptions
                  WHERE subscriptions.id = channels.subscription_id
                )
              SQL
            end
          end

          def clean_subscriptions
            with_connection do |conn|
              conn.exec_params(<<~SQL)
                DELETE FROM #{subscriptions_table}
                WHERE expires_at IS NOT NULL
                  AND expires_at <= CURRENT_TIMESTAMP
              SQL
            end
          end

          def clean_fingerprint_subscriptions
            with_connection do |conn|
              conn.exec_params(<<~SQL)
                DELETE FROM #{events_table} events
                WHERE NOT EXISTS (
                  SELECT 1
                  FROM #{subscriptions_table} subscriptions
                  WHERE subscriptions.id = events.subscription_id
                )
              SQL
            end
          end

          def clean_topic_fingerprints
            nil
          end

          private

          attr_reader :channels_table, :connection_provider, :events_table, :subscriptions_table

          def with_connection(&block)
            connection_provider.call(&block)
          end
        end
      end
    end
  end
end
