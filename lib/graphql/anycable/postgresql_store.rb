# frozen_string_literal: true

require "graphql-anycable"

unless GraphQL::AnyCable.respond_to?(:register_subscription_store)
  raise LoadError, "graphql-anycable_postgresql-store requires a graphql-anycable version with custom subscription stores"
end

require_relative "postgresql_store/version"
require_relative "postgresql_store/config"
require_relative "postgresql_store/store"
require_relative "postgresql_store/railtie" if defined?(Rails::Railtie)

module GraphQL
  module AnyCable
    module PostgreSQLStore
      class << self
        def config
          @config ||= Config.new
        end

        def configure
          yield(config) if block_given?
        end
      end
    end
  end
end

GraphQL::AnyCable.register_subscription_store(:postgresql) do
  GraphQL::AnyCable::PostgreSQLStore::Store.new
end

GraphQL::AnyCable.register_subscription_store(:postgres) do
  GraphQL::AnyCable::PostgreSQLStore::Store.new
end
