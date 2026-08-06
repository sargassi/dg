# Current Feature

Godlike root home "Command Center" (`/` → `dashboard#index`).

## Status

Planned.

## Goals

- Add a root landing page shown **only** to godlike users, aggregating links to every section of the app.
- Render inside the existing shell (side menu + page header), so it drops straight into `dashboard#index`.
- Keep all non-godlike behavior intact (`ufficio`/`lab` partials, `pedone` redirect).
- Include a light live quick-stats strip (counts from the DB) plus a section card grid and a config strip.

## Summary

- No route change: `root` stays `dashboard#index`.
- `DashboardController#index` gains a `portal_counts` private method feeding the stats strip.
- New `DashboardHelper#portal_sections` returns card data reusing the existing `*_section_toolbar` helpers (`skip_config: true`) so labels/icons stay consistent.
- New partial `app/views/dashboard/_portal.html.erb`.
- `dashboard/index.html.erb` branches on `current_user.godlike?`.

## Files changed (planned)

- `context/current-feature.md` (this file)
- `app/controllers/dashboard_controller.rb`
- `app/helpers/dashboard_helper.rb` (new)
- `app/views/dashboard/_portal.html.erb` (new)
- `app/views/dashboard/index.html.erb`

## Notes

- Only godlike bypasses all checks; stats use plain `count` queries.