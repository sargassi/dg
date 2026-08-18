# Mainware Refactor Proposal

## Context

Mainware is the legacy/general warehouse module in DG. It wraps the `Item` catalog (articles/products), collections, prices, bulk Excel imports, and QR-based lookup. All routes under `mainware/` require the `manage_mainware` ability.

Current core files:

- `app/controllers/mainware_controller.rb`
- `app/services/import_general_service.rb`
- `app/jobs/import_job.rb`
- `app/views/mainware/*`
- `app/javascript/controllers/search_filter_controller.js`
- `app/javascript/controllers/qr_scanner_controller.js`
- `app/javascript/controllers/inline_edit_controller.js`
- `app/javascript/controllers/import_progress_controller.js`

## Goals

1. Make the dashboard and navigation less redundant.
2. Make the Excel import flow transparent, safe, and recoverable.
3. Improve item search/QR workflows.
4. Reduce accidental data mutations (auto-created collections/warehouses, silent updates).
5. Improve test coverage and observability.

---

## Phase 1 — Done

Implemented on branch `feature/mainware-ux-improvements`.

### Dashboard

- [x] Removed the redundant **Azioni** section that duplicated the top cards.
- [x] Added a **Collezioni** count badge in the **Generale** section.
- [x] Kept the top three primary action cards: Inserimento, Importa, Ricerca Articoli.

### Import safety and transparency

- [x] Added `GET /mainware/import/template` to download an `.xlsx` template with expected headers and an example row.
- [x] Added client-side (`accept=".xlsx"`) and server-side (extension + 5 MB max size) file validation.
- [x] Moved collection/warehouse creation from the **parse** step to the **confirm** step so cancelling a preview no longer leaves orphan records.
- [x] Added a confirm summary page that shows:
  - total rows
  - new items vs. updated items
  - any new collections or warehouses that will be created
- [x] Normalized import header mapping and removed duplicate keys in `FIELD_MAP`.
- [x] Re-evaluate collection/warehouse resolution when `Note:` or `dove` are edited inline in the preview.
- [x] Wrapped dependency creation in `ensure_dependencies!` inside an `ActiveRecord::Base.transaction`.
- [x] Added preview validation for missing item code, missing collection, and duplicate gencodes, disabling confirm until resolved.

### Search / QR

- [x] Made `mainware/searchqr` try an exact `gencode` match first, falling back to the existing `LIKE` search only if needed.
- [x] Fixed nil-safe rendering of `qrcode_svg` in item rows.

### Tests and docs

- [x] Fixed `MainwareControllerTest` to sign in via Devise integration helpers.
- [x] Added tests for template download and `.xlsx` rejection.
- [x] Updated `context/current-feature.md` and `context/flows/articles_flow.md`.

---

## Phase 2 — Done (quick wins + preview safety)

Implemented on branch `feature/mainware-ux-improvements`.

### 1. Row-level validation with visual feedback in the preview table

Validation warnings now appear above the table **and** highlight the offending cells/rows.

**Files involved:**
- `app/services/import_general_service.rb` (`validation_details`)
- `app/views/mainware/import.html.erb`

### 2. Create vs. update indicators in the preview table

Rows are colored green (new) / amber (update) based on whether the computed gencode already exists.

**Files involved:**
- `app/services/import_general_service.rb` (`classify_rows`)
- `app/views/mainware/import.html.erb`

### 3. Wire or remove stub pages

`mainware/search` and `mainware/stage` routes, views, and empty actions were removed.

**Files involved:**
- `config/routes.rb`
- `app/controllers/mainware_controller.rb`
- `app/views/mainware/search.html.erb`
- `app/views/mainware/stage.html.,erb`

### 4. File MIME-type validation

Upload now checks the `.xlsx` extension **and** allows known MIME types (`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `application/octet-stream`).

**Files involved:**
- `app/controllers/mainware_controller.rb` (`import_parse`)

### 5. Collection override behavior clarity

When a collection override is selected at upload, the `Note:` column is disabled in the preview and a message explains that the collection is locked. Server-side edits to `Note:` are ignored in this case.

**Files involved:**
- `app/services/import_general_service.rb`
- `app/controllers/mainware_controller.rb` (`import_parse`, `import_update_row`)
- `app/views/mainware/import.html.erb`

---

## Phase 3 — Recommended next steps

### 1. Better import error summary — Done

Errors are now grouped by message, show the actual row/gencode/cell values, and can be exported as `.xlsx`.

**Files involved:**
- `app/services/import_general_service.rb` (`save` error collection)
- `app/views/mainware/import_summary.html.erb`
- `app/controllers/mainware_controller.rb` (`import_failed_rows`)

### 2. Import history / audit log — Done

Every confirmed import creates an `ImportLog` record. The job updates it with counts, created/updated IDs, and error details. Rollback now uses the log as a fallback if the cache is gone. A simple index/show UI lists all imports.

**New files:**
- `app/models/import_log.rb`
- `db/migrate/*_create_import_logs.rb`
- `app/controllers/import_logs_controller.rb`
- `app/views/import_logs/index.html.erb`
- `app/views/import_logs/show.html.erb`

**Files involved:**
- `app/controllers/mainware_controller.rb` (`import_parse`, `import_confirm`, `import_rollback`, `import_summary`)
- `app/jobs/import_job.rb`
- `app/services/import_general_service.rb`
- `app/views/mainware/dashboard.html.erb`
- `app/views/mainware/import_summary.html.erb`

### 3. Progress failure handling and cancel action — Done

The processing page now detects a missing/stuck progress cache or a job error, shows a message, and offers links to the summary / cancel. Cancelling an import also marks the `ImportLog` as `cancelled`.

**Files involved:**
- `app/javascript/controllers/import_progress_controller.js`
- `app/views/mainware/import_processing.html.erb`
- `app/controllers/mainware_controller.rb` (`import_cancel`)

### 4. Column visibility toggle and saved filters on `mainware/index` — Done

The item list now has a "Colonne" dropdown to show/hide columns, persisted in `localStorage`. Filters already keep the URL via the existing search form.

**Files involved:**
- `app/views/mainware/index.html.erb`
- `app/javascript/controllers/column_toggle_controller.js`

---

## Long-term structural improvements

| Idea | Rationale | Effort |
|---|---|---|
| **Replace session cache with an import record** | `ImportLog` could hold parsed rows, making imports resumable and shareable across tabs. | High |
| **Split `ImportGeneralService`** | Separate `Parser`, `Validator`, `Persister` concerns. | Medium |
| **Background-job safety** | The project has no Active Job queue adapter. Either configure one or make imports synchronous with a streaming progress response. | High |
| **Batch / transaction-safe persistence** | Wrap the whole import in a transaction, or process in batches so partial failures are recoverable. | Medium |
| **Bulk actions on item list** | Select rows, move collection, delete, export. | Medium |

---

## Phase 4 — Service split + bug fixes — Done

Implemented on branch `main` (merged `feature/mainware-ux-improvements`).

### 1. Split `ImportGeneralService` into three specialized classes

- **`ImportParser`** — `parse`, `find_header_row`, `normalize_header`, `resolve_collection`, `resolve_warehouse`, `gencode_for` (class method), all constants (`ITEM_CODE_KEY`, `FABRIC_CODE_KEY`, `VAR_CODE_KEY`, `NOTE_KEY`, `DOVE_KEY`, `GCODE_KEYS`, `KNOWN_HEADERS`, `TEMPLATE_HEADERS`, `FIELD_MAP`)
- **`ImportValidator`** — `validate_rows`, `validation_details`, `classify_rows`, `summarize`
- **`ImportPersister`** — `ensure_dependencies!`, `save`, `rollback`, `parse_price` (private)

`ImportGeneralService` is now a thin delegator for backward compatibility; all callers in `mainware_controller.rb` and `import_job.rb` use the new classes directly.

### 2. Bugs fixed during the split

| Bug | Severity | Fix |
|---|---|---|
| `to_f.round` truncated prices to integers | P0 | Changed to `parse_price()` with `.round(2)` |
| Non-numeric prices (e.g. "N/A") silently imported as 0.0 | P0 | `parse_price` now raises `ArgumentError` for non-numeric input; row is captured as `stats[:errors]` |
| QR code generated twice per item during `save` | P1 | Removed explicit `RQRCode::QRCode.new(gencode).as_svg(...)` from `save`; `Item` model's `before_save :regenerate_qr` callback handles it |
| `summarize` used nil `_collection_id` in gencode, producing gencodes with trailing `_` | P1 | Uses `ImportParser.gencode_for` with `_collection_description` fallback |
| Duplicate gencode formula (5+ places) | P2 | Extracted to `ImportParser.gencode_for` class method, shared by all three services |
| Magic strings for header keys (`'Item Code:'`, `'Fabric code:'`, `'var. code:'`, `'Note:'`, `'dove'`) | P2 | Extracted to `ImportParser` constants; `GCODE_KEYS` array used in `import_update_row` |

### Files changed / created

- **New:** `app/services/import_parser.rb`
- **New:** `app/services/import_validator.rb`
- **New:** `app/services/import_persister.rb`
- **New:** `test/services/import_parser_test.rb`
- **New:** `test/services/import_validator_test.rb`
- **New:** `test/services/import_persister_test.rb`
- **Modified:** `app/services/import_general_service.rb` → thin delegator
- **Modified:** `app/controllers/mainware_controller.rb` → uses new classes
- **Modified:** `app/jobs/import_job.rb` → uses `ImportPersister`

---

## Risks and considerations

- **Silent overwrites** are still possible: an import row whose gencode matches an existing item will update it. Phase 3 should make this fully explicit (e.g., via `ImportLog` and a failed-row export).
- **Collection-less rows** still fail at persistence time. Phase 2 validation already prevents confirming them; Phase 3 could add a friendlier repair flow.
- **No audit trail** means accidental imports are hard to undo. `ImportLog` is the highest-value Phase 3 item.
- **Active Job** runs inline in dev/test. In production, the lack of a queue adapter could block requests for large imports.

---

## Suggested phase 3 order

1. Improve error summary with failed-row export (high usability).
2. Introduce `ImportLog` model and use it for rollback/history (largest payoff).
3. Progress failure handling + cancel action (safety).
4. Column visibility toggle (polish).
