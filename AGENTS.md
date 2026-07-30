# AGENTS.md

## Context Files

Read these first for full project context:

- @context/project-overview.md
- @context/coding-standards.md
- @context/ai-interactions.md
- @context/current-feature.md
- @context/flows/articles_flow.md — Mainware module flow and Excel import pipeline
- @context/flows/inventories_flow.md — Inventory, movements, and warehouse flow
- @context/flows/production_flow.md — Production orders, prow rows, and tempesta stage tracking

## Commands

```bash
# Dev server (run both web + CSS watcher)
bin/dev
# Or run separately:
bin/rails server -p 3000
bin/rails tailwindcss:watch

# Setup / reset database
bin/setup
bin/rails db:prepare

# Run tests
bin/rails test                          # all tests
bin/rails test test/models/tempesta_test.rb  # single test

# Generate/import assets
bin/rails importmap:pin <package>
```

## Tech Stack

- Ruby 3.2.2, Rails 7.2.3.1 (application.rb loads defaults 7.0)
- SQLite in dev, test, and production (currently); MariaDB migration script exists at `bin/migrate_to_mariadb.sh`
- Puma 5.6.x
- TailwindCSS via `tailwindcss-rails` gem (~> 3.3.1)
- Hotwire: Turbo + Stimulus via importmap
- Sprockets asset pipeline; no JS bundler, no Node build step
- Devise authentication
- Custom authorization: `Ability` + `UserAbility` + `UserRole`; `godlike` flag bypasses all checks
- Grape REST API mounted at `/` (`API::Base`) and nested `/api/v1` routes
- PDFs: `wicked_pdf` + `wkhtmltopdf-binary`
- QR codes: `rqrcode`
- Spreadsheets: `roo` (import), `caxlsx` (export)
- Uploads: CarrierWave (photos), Active Storage + image_processing (attachments)
- Rich text: Action Text / Trix (used lightly, e.g., `Rassegna`)
- Search: Ransack ~> 4.0
- Pagination: Pagy ~> 7.0
- Calendar: simple_calendar
- Redis: Action Cable adapter in dev/production (`config/cable.yml`)
- Deployment: Capistrano 3.x + rbenv + Passenger to `/home/deploy/dg`

## Test Framework

- Minitest (not RSpec). Fixtures in `test/fixtures/*.yml`.
- System tests use Capybara + Selenium.
- No lint or typecheck tooling is configured.

## Repo Conventions

- Default locale is Italian (`config.i18n.default_locale = :it`); many UI labels and business terms are Italian.
- Controllers often use custom actions beyond REST; check `config/routes.rb` for the real routing.
- Production is deployed via Capistrano; linked files are `config/master.key` and `db/production.sqlite3` (see `config/deploy.rb`).
- `opencode.json` defines two subagents (`dez`, `odb`) with skill permissions; respect it when delegating.

## Workflow

From `context/ai-interactions.md`:

- Document the feature in `@context/current-feature.md` before implementing.
- Create a branch (`feature/<name>` or `fix/<name>`).
- Do not commit or push without explicit permission.
- Keep commits focused and use conventional commits (`feat:`, `fix:`, `chore:`, etc.).
- Verify before claiming done: tests pass, build/dev server works, no generic AI markers in commit messages.

## Gotchas

- `bin/dev` is the canonical way to start the dev server; it runs both Rails and the Tailwind watcher via Foreman.
- No `package.json` dependencies; JavaScript is managed through `config/importmap.rb` and vendored pins.
- The API is mounted at root by Grape (`mount API::Base, at: "/"`) in addition to Rails namespace routes under `/api/v1`.
- MariaDB migration is documented only in `bin/migrate_to_mariadb.sh`; current database.yml and Capistrano still use SQLite.

## Documentation Files Worth Consulting

- `context/project-overview.md` — domain modules and section purposes
- `context/ai-interactions.md` — branching, commit, and review workflow
- `context/current-feature.md` — active feature spec
- `application-strategy.md`, `operator-strategy.md`, `style-guide.md`, `structure.md` — additional design/structure notes
- `api_schema_for_app_controller.json` — API schema for mobile/client integrations
