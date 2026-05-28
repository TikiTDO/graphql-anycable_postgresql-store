# Release Workflow

Use this workflow for publishing `graphql-anycable_postgresql-store`. A release
is a combined RubyGems and GitHub release; both must use the same version and
the same built gem artifact.

## Preflight

1. Confirm the worktree is clean except for intentional release changes.
2. Update `lib/graphql/anycable/postgresql_store/version.rb`.
3. Add a matching section to `CHANGELOG.md`.
4. Confirm `README.md` and this file do not contain stale version-specific
   commands.
5. If the `graphql-anycable` store contract changed, update this gem's store,
   stats, cleaner, tests, and runtime dependency once the core release version
   is known.

## Validate

Run the suite against the released core dependency:

```sh
bundle exec rspec
```

When validating against a local or unreleased core checkout:

```sh
GRAPHQL_ANYCABLE_PATH=../graphql-anycable bundle exec rspec
```

Run database-backed examples by setting a PostgreSQL URL appropriate for the
task:

```sh
POSTGRES_URL=postgres://user:password@localhost:5432/database bundle exec rspec
```

Build the gem:

```sh
bundle exec rake build
```

Verify the package includes the expected files and version:

```sh
version=$(ruby -Ilib -rgraphql/anycable/postgresql_store/version -e 'puts GraphQL::AnyCable::PostgreSQLStore::VERSION')
gem spec "pkg/graphql-anycable_postgresql-store-${version}.gem" version dependencies files
```

## Commit And Push

Commit the version, changelog, and any required implementation/docs changes,
then push the branch before publishing:

```sh
git status --short
git commit -m "Prepare PostgreSQL store ${version} release"
git push
```

## Publish To RubyGems

Publish the built artifact:

```sh
gem push "pkg/graphql-anycable_postgresql-store-${version}.gem"
```

If RubyGems requires MFA, provide the OTP interactively or through the CLI's
supported `--otp` option for that one command only. Do not commit or document
OTP values.

Verify RubyGems sees the version:

```sh
gem info --remote graphql-anycable_postgresql-store
```

## Create The GitHub Release

Create release notes containing the current version's `CHANGELOG.md` entry,
then create the GitHub release and attach the same gem artifact:

```sh
awk -v version="$version" '
  $0 ~ "^## " version "([ -]|$)" { capture = 1; next }
  capture && /^## / { exit }
  capture { print }
' CHANGELOG.md > /tmp/graphql-anycable_postgresql-store-release-notes.md

gh release create "v${version}" \
  "pkg/graphql-anycable_postgresql-store-${version}.gem" \
  --target "$(git rev-parse HEAD)" \
  --title "v${version}" \
  --notes-file /tmp/graphql-anycable_postgresql-store-release-notes.md
```

If a release already exists, inspect it before editing or uploading assets.
Avoid overwriting release artifacts without a clear reason.

## Final Verification

Verify both release surfaces:

```sh
gem info --remote graphql-anycable_postgresql-store
gh release view "v${version}" --json tagName,url,targetCommitish,assets
```

The GitHub asset digest should match the built gem artifact. The release is not
complete until RubyGems and GitHub both show the expected version.
