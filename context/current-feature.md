# Current Feature

Mainware / Articles module UX and import workflow improvements.

## Status

In Progress — implementing Phase 2 from `context/refactor/mainware_refactor.md`.

## Goals (phase 1 — done)

- Make the Mainware dashboard less redundant and surface the most-used workflows.
- Make the Excel import flow safer and more transparent: template download, upload validation, deferred collection/warehouse creation, and a confirm summary page.
- Fix small quality issues: duplicate header keys in the import mapper, exact QR search, nil-safe QR SVG rendering.

## Phase 2 candidates

- Row-level validation in the import preview (duplicate gencodes, missing required fields, malformed prices).
- Create vs. update row highlighting in the preview table.
- Better import error display (cell values, grouped messages).
- Import history / `ImportLog` model for audit and rollback of updates.
- Progress timeout / failure handling and a cancel-during-processing action.
- Column visibility toggle and saved filters on the item list.
- Wire or remove the empty `mainware/search` and `mainware/stage` pages.

## Notes

- Branch: `feature/mainware-ux-improvements`
- Keep changes inside the `mainware` surface (controllers, views, services) and avoid touching unrelated inventory/production flows.
- Do not introduce a background job queue adapter; keep imports inline/compatible with the current setup.
- Preserve existing Italian labels and Tailwind styling patterns.

## History

- Project setup and boilerplate cleanup
- 2026-07-30: Started Mainware UX / import improvements branch
- 2026-07-30: Phase 1 — dashboard cleanup, import template/validation/confirm summary, exact QR search, service refactor
