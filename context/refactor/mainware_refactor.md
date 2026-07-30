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

### 1. Better import error summary

When rows fail during the job, show actual cell values and group repeated errors. Add CSV/Excel export of the failed rows so the user can fix and re-import.

**Files involved:**
- `app/services/import_general_service.rb` (`save` error collection)
- `app/views/mainware/import_summary.html.erb`

### 2. Import history / audit log

Introduce an `ImportLog` model to record each import run: user, file name, row counts, created/updated IDs, errors. This enables:

- rollback of updates (today only creates can be rolled back)
- re-running a previous import
- audit trail

**New files:**
- `app/models/import_log.rb`
- migration for `import_logs`

**Files involved:**
- `app/controllers/mainware_controller.rb` (`import_confirm`, `import_rollback`)
- `app/jobs/import_job.rb`
- `app/services/import_general_service.rb`

### 3. Progress failure handling and cancel action

- Detect when `import:progress:*` cache disappears or the job errors out.
- Offer a "Cancel / rollback" button on the processing page.
- Surface job errors in the summary page instead of leaving the spinner running.

**Files involved:**
- `app/javascript/controllers/import_progress_controller.js`
- `app/views/mainware/import_processing.html.erb`
- `app/controllers/mainware_controller.rb`

### 4. Column visibility toggle and saved filters on `mainware/index`

The item table is very dense. Add:

- a dropdown to show/hide columns
- persist the user’s preference in `localStorage`
- keep collection filter + search in the URL for shareability

**Files involved:**
- `app/views/mainware/index.html.erb`
- new/partial Stimulus controller for column toggles

---

## Long-term structural improvements

| Idea | Rationale | Effort |
|---|---|---|
| **Replace session cache with an import record** | `ImportLog` could hold parsed rows, making imports resumable and shareable across tabs. | High |
| **Split `ImportGeneralService`** | Separate `Parser`, `Validator`, `Persister`, and `DependencyResolver` concerns. | Medium |
| **Background-job safety** | The project has no Active Job queue adapter. Either configure one or make imports synchronous with a streaming progress response. | High |
| **Batch / transaction-safe persistence** | Wrap the whole import in a transaction, or process in batches so partial failures are recoverable. | Medium |
| **Bulk actions on item list** | Select rows, move collection, delete, export. | Medium |

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
