# graphql-anycable_postgresql-store Agent Notes

This repo is a small Ruby gem that provides a PostgreSQL subscription store for
`graphql-anycable`. Keep changes narrow, explicit, and aligned with the upstream
`graphql-anycable` custom subscription-store contract.

## What This Gem Does

- Persists GraphQL subscription state in PostgreSQL.
- Registers `:postgresql` and `:postgres` store aliases with
  `GraphQL::AnyCable.register_subscription_store`.
- Does not deliver websocket broadcasts. AnyCable broadcast delivery still uses
  the application's configured AnyCable broadcast adapter.
- Uses PostgreSQL tables for subscriptions, subscription events, and channel
  subscriptions. Foreign keys with `ON DELETE CASCADE` are part of the cleanup
  model.

## Contract With graphql-anycable

The store must satisfy the current `graphql-anycable` store interface:

- `stream_for(fingerprint)`
- `fingerprints_for_topic(topic)`
- `subscription_ids_for_fingerprints(fingerprints)`
- `subscription_exists?(subscription_id)`
- `write_subscription(subscription_id, channel_id:, data:, events:, expiration_seconds:)`
- `read_subscription(subscription_id)`
- `delete_channel_subscriptions(channel_id)`
- `delete_subscription(subscription_id)`
- `stats(scan_count:, include_subscriptions:)`
- `cleaner`

`stats` must return `total:` counters for `:subscription`, `:fingerprints`,
`:subscriptions`, and `:channel`; when `include_subscriptions` is true, include
a `subscriptions:` hash grouped by topic.

`cleaner` must return an object responding to `clean`, `clean_channels`,
`clean_subscriptions`, `clean_fingerprint_subscriptions`, and
`clean_topic_fingerprints`. PostgreSQL has no separate topic-fingerprint store,
so `clean_topic_fingerprints` may be a no-op when the relational model already
keeps that state consistent.

## Development Workflow

- Use `bundle exec rspec` for the test suite.
- Set `POSTGRES_URL` or `DATABASE_URL` to run database-backed examples.
- When validating against an unreleased local `graphql-anycable` interface, set
  `GRAPHQL_ANYCABLE_PATH=../graphql-anycable`.
- Build packages with `bundle exec rake build`.
- The gemspec uses `git ls-files`; new files must be staged before the built gem
  can include them.
- Keep public docs free of personal local examples, one-off OTP values, or
  account-specific release commands.

## Release Definition

A release is complete only when both distribution surfaces are updated:

- RubyGems has the versioned `.gem` published.
- GitHub has a matching `vX.Y.Z` release/tag with the same `.gem` artifact
  attached and release notes matching the changelog entry.

Follow `RELEASE.md` for the exact workflow. Do not treat a local build, a pushed
commit, or a GitHub release alone as a completed gem release.

## History And Related Work

This gem was split out of the `graphql-anycable` PostgreSQL store work so the
core gem could ship a storage adapter interface independently while PostgreSQL
support lived as an external adapter. Version `0.1.0` introduced the PostgreSQL
store and Rails generator. Version `0.2.0` aligned the gem with the newer
store-backed stats and cleanup design by adding `Store::Stats` and
`Store::Cleaner`.
