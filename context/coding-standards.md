# Coding Standards — DG

Guidelines specific to this Rails application. Generic advice is omitted; default to Rails conventions and the patterns already in the codebase.

## Stack

- Ruby 3.2.2, Rails 7.2.3.1 (defaults loaded as 7.0 in `config/application.rb`)
- SQLite 3 in dev/test/production; MariaDB migration planned via `bin/migrate_to_mariadb.sh`
- Hotwire (Turbo + Stimulus), importmaps, TailwindCSS, Sprockets
- Minitest + fixtures for testing

## Code Style

- Follow the Ruby Style Guide for idiomatic Ruby.
- Use snake_case for files, methods, and variables; CamelCase for classes and modules.
- Prefer single-quoted strings unless interpolation is needed.
- Use Rails helpers and built-in methods; avoid reinventing framework behavior.
- Keep methods small and descriptive; extract service objects or concerns for complex business logic.

## Architecture

- Follow Rails conventions: MVC, concerns, helpers, partials.
- Controllers use many custom actions beyond REST — always check `config/routes.rb` before adding or changing routes.
- Use concerns for shared model/controller behavior.
- Use strong parameters in controllers.
- Eager-load associations to avoid N+1 queries.

## UI and Styling

- Build dynamic interactions with Turbo and Stimulus.
- Style with Tailwind CSS; use Rails view helpers and partials to keep views DRY.
- Responsive design is expected.

## Testing

- Use Minitest, not RSpec. Tests live in `test/`.
- Test data comes from `test/fixtures/*.yml` — no FactoryBot is configured.
- System tests use Capybara + Selenium.

## Security

- Authorization uses the custom `Ability`/`UserAbility`/`UserRole` system. `godlike` users bypass all checks.
- Always enforce authorization checks in controllers; do not rely on UI alone.
- Protect against XSS, CSRF, and SQL injection using Rails defaults.

## Localization

- Default locale is Italian (`config.i18n.default_locale = :it`).
- UI labels and many business terms are in Italian; preserve existing Italian terminology.

## Background Jobs

- No Active Job queue adapter is currently configured. Do not introduce background jobs without updating the deployment setup.

## Documentation

- Document new features in `@context/current-feature.md` before implementing.
- Update this file only when repo-specific conventions change.
