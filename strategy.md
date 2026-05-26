# Frontend Redesign Strategy — DG

## Goal

Make the UI more readable while preserving Swiss/International style and monospace search inputs.

## Phases

### Phase 1 — Rationalize Helpers (`application_helper.rb`)

- Collapse ~50 style helpers into ~20 with clear groups: `style_*`, `form_*`, `comp_*`, `util_*`
- Delete duplicates: `input_class` / `style_input`, `button_class` / `style_main_btn`
- Merge table helpers (`style_table_th` / `style_table_th_children` → parameterized `style_th`)
- Merge button helpers (7 variants → 1 `style_btn` with variants)
- Merge form input helpers (5 helpers → 1 `style_input` with variants)
- Parameterize where padding differs

### Phase 2 — Clean Custom CSS (`application.tailwind.css`)

- Delete ~250 lines of legacy selectors: `.linx`, `.sez`, `.sidelinx`, `.pagination`, `.note`, `.out`, `.simple-calendar`
- Migrate overlay patterns (`.linx`, `#report`, `#success`) to Stimulus + Tailwind
- Remove duplicate `flipV` in `application.tailwind.css` (keep only in `pdf.css`)

### Phase 3 — Component Partials (`app/views/components/`)

- `_btn.html.erb` — single partial for all button styles
- `_card.html.erb` — replaces `style_main_card` + `style_main_card_header` pattern
- `_form_field.html.erb` — wraps label + input blocks
- `_input_group.html.erb` — search icon + input + count

### Phase 4 — Re-theme Views

1. Dashboard home, production/research, atoms/search_rows (fix color drift: `bg-blue-50` → `bg-accent-50`, remove inline `<style>`)
2. Admin users, proformas CRUD, partials (use component partials, consistent `rounded-sm`)
3. Events CRUD, Devise login, scaffolding (kill `bg-gray-100`, `rounded-md`)

### Phase 5 — Edge Cases

- `simple-calendar` CSS → Tailwind utilities via existing helper
- Standardize gaps: `gap-4` forms, `gap-8` sections
- `rounded-sm` everywhere, `<hr>` → `border-t`
- Fix ~12 color drift locations (`bg-blue-50`, `text-blue-500`, `border-gray-*`)
- Preserve `font-mono text-blue-600` on all search inputs

## Non-goals

- PDF styles (`pdf.css` for label printing) — left untouched
- Business logic helpers — renamed/grouped but not refactored
