# frozen_string_literal: true

module GraphQL
  module AnyCable
    module PostgreSQLStore
      class Store
        class Stats
          def initialize(connection_provider:, subscriptions_table:, events_table:, channels_table:, scan_count:, include_subscriptions:)
            @connection_provider = connection_provider
            @subscriptions_table = subscriptions_table
            @events_table = events_table
            @channels_table = channels_table
            @scan_count = scan_count
            @include_subscriptions = include_subscriptions
          end

          def collect
            # PostgreSQL uses aggregate queries rather than key scans; scan_count
            # is accepted to match graphql-anycable's store stats interface.
            raise ArgumentError, "scan_count must be positive" if scan_count.to_i <= 0

            with_connection do |conn|
              result = {total: total_stats(conn)}
              result[:subscriptions] = subscription_stats(conn) if include_subscriptions
              result
            end
          end

          private

          attr_reader :channels_table, :connection_provider, :events_table, :include_subscriptions, :scan_count, :subscriptions_table

          def with_connection(&block)
            connection_provider.call(&block)
          end

          def total_stats(conn)
            conn.exec_params(<<~SQL).first.transform_values(&:to_i).transform_keys(&:to_sym)
              SELECT
                (
                  SELECT COUNT(*)
                  FROM #{subscriptions_table}
                  WHERE #{active_subscription_sql}
                ) AS subscription,
                (
                  SELECT COUNT(DISTINCT events.topic)
                  FROM #{events_table} events
                  INNER JOIN #{subscriptions_table} subscriptions
                    ON subscriptions.id = events.subscription_id
                  WHERE #{active_subscription_sql("subscriptions")}
                ) AS fingerprints,
                (
                  SELECT COUNT(DISTINCT events.fingerprint)
                  FROM #{events_table} events
                  INNER JOIN #{subscriptions_table} subscriptions
                    ON subscriptions.id = events.subscription_id
                  WHERE #{active_subscription_sql("subscriptions")}
                ) AS subscriptions,
                (
                  SELECT COUNT(DISTINCT channels.channel_id)
                  FROM #{channels_table} channels
                  INNER JOIN #{subscriptions_table} subscriptions
                    ON subscriptions.id = channels.subscription_id
                  WHERE #{active_subscription_sql("subscriptions")}
                ) AS channel
            SQL
          end

          def subscription_stats(conn)
            conn.exec_params(<<~SQL).to_h { |row| [row.fetch("topic"), row.fetch("subscriptions").to_i] }
              SELECT events.topic, COUNT(DISTINCT events.subscription_id) AS subscriptions
              FROM #{events_table} events
              INNER JOIN #{subscriptions_table} subscriptions
                ON subscriptions.id = events.subscription_id
              WHERE #{active_subscription_sql("subscriptions")}
              GROUP BY events.topic
              ORDER BY events.topic ASC
            SQL
          end

          def active_subscription_sql(table_name = nil)
            prefix = table_name ? "#{table_name}." : ""
            "(#{prefix}expires_at IS NULL OR #{prefix}expires_at > CURRENT_TIMESTAMP)"
          end
        end
      end
    end
  end
end
