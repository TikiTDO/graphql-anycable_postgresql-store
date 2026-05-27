# GraphQL AnyCable PostgreSQL Store

[![Tests](https://github.com/TikiTDO/graphql-anycable_postgresql-store/actions/workflows/test.yml/badge.svg)](https://github.com/TikiTDO/graphql-anycable_postgresql-store/actions/workflows/test.yml)

PostgreSQL subscription store for [`graphql-anycable`](https://github.com/anycable/graphql-anycable).

This gem stores GraphQL subscription state in PostgreSQL. It does not deliver AnyCable broadcasts itself; delivery still goes through the AnyCable broadcast adapter configured by the application.

This gem requires a `graphql-anycable` version that supports custom subscription stores.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "graphql-anycable_postgresql-store"
```

Then configure `graphql-anycable` to use the store:

```ruby
GraphQL::AnyCable.configure do |config|
  config.subscription_store = :postgresql
end
```

The gem also registers `:postgres` as an alias for `:postgresql`.

## Configuration

Configure the PostgreSQL connection and table names with environment variables:

```.env
GRAPHQL_ANYCABLE_POSTGRESQL_STORE_POSTGRES_URL=postgres://localhost:5432/postgres
GRAPHQL_ANYCABLE_POSTGRESQL_STORE_SUBSCRIPTIONS_TABLE=graphql_anycable_subscriptions
GRAPHQL_ANYCABLE_POSTGRESQL_STORE_SUBSCRIPTION_EVENTS_TABLE=graphql_anycable_subscription_events
GRAPHQL_ANYCABLE_POSTGRESQL_STORE_CHANNEL_SUBSCRIPTIONS_TABLE=graphql_anycable_channel_subscriptions
```

Or configure the gem from application code:

```ruby
GraphQL::AnyCable::PostgreSQLStore.configure do |config|
  config.postgres_url = ENV["DATABASE_URL"]
  config.subscriptions_table = "graphql_anycable_subscriptions"
  config.subscription_events_table = "graphql_anycable_subscription_events"
  config.channel_subscriptions_table = "graphql_anycable_channel_subscriptions"
end
```

If `postgres_url` is not configured, the store falls back to `AnyCable.config.postgres_url` when available, then to `DATABASE_URL`. If none are set, `PG.connect` uses libpq defaults.

## Database schema

Rails applications with ActiveRecord can install the migration:

```sh
bin/rails generate graphql:anycable:postgresql_store:install
bin/rails db:migrate
```

The generator skips migration creation when ActiveRecord generator support is not available.

Applications can also create the tables directly:

```sql
CREATE TABLE graphql_anycable_subscriptions (
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

CREATE TABLE graphql_anycable_subscription_events (
  subscription_id text NOT NULL REFERENCES graphql_anycable_subscriptions(id) ON DELETE CASCADE,
  topic text NOT NULL,
  fingerprint text NOT NULL,
  created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (subscription_id, topic, fingerprint)
);

CREATE INDEX index_graphql_anycable_subscription_events_topic_fingerprint
  ON graphql_anycable_subscription_events (topic, fingerprint);

CREATE TABLE graphql_anycable_channel_subscriptions (
  channel_id text NOT NULL,
  subscription_id text NOT NULL REFERENCES graphql_anycable_subscriptions(id) ON DELETE CASCADE,
  created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (channel_id, subscription_id)
);
```

## Stats

`GraphQL::AnyCable.stats` delegates to this store when `subscription_store` is
configured as `:postgresql` or `:postgres`. The store reports active
subscriptions, topics, fingerprints, and channels with SQL aggregate queries;
`scan_count` is accepted for graphql-anycable interface compatibility and is not
used by PostgreSQL.

## Development

Install dependencies and run tests:

```sh
GRAPHQL_ANYCABLE_PATH=../graphql-anycable bundle exec rspec
```

Set `POSTGRES_URL` or `DATABASE_URL` to run the store integration spec against PostgreSQL.

CI runs the spec suite against a PostgreSQL service and checks out the `graphql-anycable` interface branch until the custom store API is released.
