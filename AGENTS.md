# AGENTS.md

## Commands

```bash
# Dev server (run both web + css)
bin/rails server -p 3000
bin/rails tailwindcss:watch

# Run single test
bin/rails test test/models/tempesta_test.rb

# Run all tests
bin/rails test
```

## Tech Stack

- Rails 7.0.7, Ruby 3.2.2
- SQLite (dev: db/development.sqlite3)
- TailwindCSS via tailwindcss-rails gem
- Devise authentication
- Capistrano 3.x deployment (deploys to /home/deploy/dg)
- Grape for REST APIs
- wicked_pdf + wkhtmltopdf for PDFs
- rqrcode for QR codes

## Test Framework

Minitest (not RSpec). Fixtures in test/fixtures/*.yml.

## Quirks

- Uses importmaps for JavaScript (modern approach)
- Uses Turbo (Hotwire SPA) and Stimulus
- API schema defined in api_schema_for_app_controller.json