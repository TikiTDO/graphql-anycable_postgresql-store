# frozen_string_literal: true

require_relative "lib/graphql/anycable/postgresql_store/version"

Gem::Specification.new do |spec|
  spec.name = "graphql-anycable_postgresql-store"
  spec.version = GraphQL::AnyCable::PostgreSQLStore::VERSION
  spec.authors = ["TikiTDO"]

  spec.summary = "PostgreSQL subscription store for graphql-anycable."
  spec.description = "Stores graphql-anycable subscription state in PostgreSQL."
  spec.homepage = "https://github.com/TikiTDO/graphql-anycable_postgresql-store"
  spec.license = "MIT"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/TikiTDO/graphql-anycable_postgresql-store/issues",
    "changelog_uri" => "https://github.com/TikiTDO/graphql-anycable_postgresql-store/releases",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => spec.homepage
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |file|
      file.start_with?("spec/", ".github/", ".git", "Gemfile")
    end
  end
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0.0"

  spec.add_dependency "anyway_config", ">= 1.3", "< 3"
  spec.add_dependency "graphql-anycable", ">= 1.3.1"
  spec.add_dependency "pg", ">= 1.2"

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
end
