# Changelog

## 0.2.0 - 2026-05-28

- Add a PostgreSQL store cleaner matching the `graphql-anycable` store cleanup contract.
- Extract PostgreSQL stats into a `Store::Stats` object to match the core store design.

## 0.1.0 - 2026-05-27

- Add PostgreSQL subscription store for `graphql-anycable`.
- Register `:postgresql` and `:postgres` subscription store aliases.
- Add Rails install generator for the PostgreSQL store tables.
- Add store-backed stats support for `GraphQL::AnyCable.stats`.
