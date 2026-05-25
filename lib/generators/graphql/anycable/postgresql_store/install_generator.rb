# frozen_string_literal: true

require "rails/generators"

begin
  require "rails/generators/active_record"
rescue LoadError
  # ActiveRecord is optional; non-ActiveRecord applications can use the SQL from the README.
end

module GraphQL
  module AnyCable
    module PostgreSQLStore
      class InstallGenerator < Rails::Generators::Base
        namespace "graphql:anycable:postgresql_store:install"

        source_root File.expand_path("templates", __dir__)

        include ActiveRecord::Generators::Migration if defined?(ActiveRecord::Generators::Migration)

        def self.next_migration_number(dirname)
          if defined?(ActiveRecord::Generators::Base)
            ActiveRecord::Generators::Base.next_migration_number(dirname)
          else
            Time.now.utc.strftime("%Y%m%d%H%M%S")
          end
        end

        def create_migration
          unless respond_to?(:migration_template, true)
            say_status :skip, "ActiveRecord generators are not available", :yellow
            return
          end

          migration_template(
            "create_graphql_anycable_postgresql_store_tables.rb",
            "db/migrate/create_graphql_anycable_postgresql_store_tables.rb"
          )
        end

        private

        def migration_version
          return "" unless defined?(ActiveRecord::Migration) && ActiveRecord::Migration.respond_to?(:[])

          "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
        end
      end
    end
  end
end
