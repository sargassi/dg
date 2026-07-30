# Production Flow

## Module purpose

The Production module tracks manufacturing orders from upload to completion.

- `Proforma` is the production order (customer, dates, note, Excel upload).
- `Prow` is a production row / article to be produced (one per Excel row).
- `Tempesta` is per-unit stage tracking: six boolean flags `f0`–`f5` with optional dates.
- QR codes on each unit are used to advance stages via mobile scanners.

All production actions require the appropriate ability, typically `manage_proformas` and/or `checkpoint_scan`.

## Model relationships

- `Proforma` `has_many :prows`, `has_many :tempestas`.
- `Prow` `belongs_to :proforma`, `has_many :tempestas`.
- `Tempesta` `belongs_to :prow`, `belongs_to :proforma`.
- `Station` and `Area` are bare configuration tables; they are not currently wired into the production workflow.

## Stage semantics

| Flag | UI label | Notes |
|---|---|---|
| `f0` | Start state | Hidden, default `true`; marks the unit as created. |
| `f1` | Consegna | First production stage. |
| `f2` | Controllo | Quality/control stage. |
| `f3` | Messo da lavare | Sent to washing stage. |
| `f4` | Lavato | Washed stage. |
| `f5` | Stage 5 | Final tracked stage. |

Progress per stage is shown with color coding: green = all units completed, amber = some completed, red = none completed.

## Subsections

### 1. Desktop production hub — `ProductionController`

| Path | Action | Purpose |
|---|---|---|
| `production/dashboard` | `#dashboard` | Landing page with cards for Lanci, Ricerca, Ricerca QR and a list of open proformas with progress percentage. |
| `production/research` | `#research` | Text search across open `Prow` rows (Ransack, live filter, Pagy). |
| `production/research_qr` | `#research_qr` | QR search for open `Prow` rows; renders the full stage grid (`_avanzamento_full`). |
| `production/checkpoint` | `#checkpoint` | State-advance endpoint. Receives `tid`, `stage` (`F1`–`F5`) and `date`, sets the matching `Tempesta` flag/date, and marks the `Prow` done when all units are complete. |
| `production/checkpoint_single` | `#checkpoint_single` | Single-QR scan page; renders the scanner partial and posts to `app_check_single_qr_path`. |

### 2. Proformas — `Production::ProformasController`

| Path | Action | Purpose |
|---|---|---|
| `production/proformas` | `#index` | Lists all proformas that have at least one prow, newest first, with progress percentage. |
| `production/proformas/:id` | `#show` | Proforma detail with its rows; supports `?done=y/n` filters; responds to `.pdf` for QR label printing. |
| `production/proformas/new` / `create` | `#new` / `#create` | Creates a proforma and calls `ImportProformasService` to parse the uploaded Excel file and generate `Prow` + `Tempesta` records. |
| `production/proformas/:id/edit` / `update` | `#edit` / `#update` | Edit customer, dates, note, and the `closed` flag. |
| `production/proformas/:id` (DELETE) | `#destroy` | Destroys the proforma, all its prows, and all their tempestas. |

### 3. Prows — `ProwsController`

| Path | Action | Purpose |
|---|---|---|
| `prows` | `#index` | Full list of all `Prow` records. |
| `prows/:id` | `#show` | Row detail modal; renders `_prow` and `_avanzamento_full`. |
| `prows/new` / `create` | `#new` / `#create` | Manual creation of a prow. |
| `prows/:id` (PATCH) | `#update` | Manual update of a prow. |
| `prows/:id` (DELETE) | `#destroy` | Deletes the prow and all of its `Tempesta` children. |

### 4. Tempesta stage tracking — `TempestaController`

| Path | Action | Purpose |
|---|---|---|
| `tempesta/set_f` | `#set_f` | Mobile action: reads `sez` (`f1`–`f5`) and `tid`, sets the matching flag + today's date, then redirects back to `app_sez_path(place: sez)`. |
| `resources :tempesta` | standard | Scaffold for `Tempesta` records (mostly admin/debug). |

### 5. Mobile production flow — `AppController`

| Path | Action | Purpose |
|---|---|---|
| `app/dashboard_produzione` | `#dashboard_produzione` | Mobile production dashboard with the Avanzamento card. |
| `app/sez` | `#sez` | Choose a section (`F1`–`F5`) and open the QR scanner; submits to `app_check_single_qr_path`. |
| `app/check_single_qr` | `#check_single_qr` | Receives `place` and scanned QR; finds a `Tempesta` whose selected flag is still null and renders the check button. |

### 6. Stages / sections — `StagesController`

| Path | Action | Purpose |
|---|---|---|
| `stages/dashboard` | `#dashboard` | Placeholder view. |
| `stages/sections?section=…` | `#sections` | Renders a QR checkpoint field only; largely unimplemented. |

### 7. Supporting configuration

- `resources :stations` — CRUD for production stations (`description`, `note`).
- `resources :areas` — CRUD for production areas (`description`).

Neither table is referenced by `Proforma`, `Prow`, or `Tempesta` at this time.

## API endpoints (`/api/v1`)

| Endpoint | File | Behaviour |
|---|---|---|
| `GET /api/v1/prows` | `app/controllers/api/v1/prows.rb` | Returns all `Prow` records. |
| `GET /api/v1/prows/:id` | `app/controllers/api/v1/prows.rb` | Returns one `Prow`. |
| `GET /api/v1/tempesta?station=F1&prow_id=…&qrcode=…` | `app/controllers/api/v1/tempestas.rb` | Lookup only: returns tempestas whose selected flag is still null. Does **not** update state. |

## General flow

1. **Create a production order**
   - Navigate to `production/proformas/new`.
   - Fill customer, dates, note, and upload an Excel file.
   - On `create`, the `Proforma` is saved and `ImportProformasService` parses the Excel file.
   - One `Prow` is created per Excel row; each `Prow` gets a generated `qr` string.
   - For each `Prow`, `qty` `Tempesta` records are created with sequential `order`, unique `qrcode = prow.qr + index`, `f0 = true`, and `f1`–`f5` unset.

2. **Monitor progress**
   - `production/dashboard` and `production/proformas` list open proformas with progress percentage.
   - `GetAvanzamentoService` sums completed flags across all tempestas of a prow.
   - `calc_percentage` divides by `qty × 5` to produce the percentage.
   - `_avanzamento` renders the per-stage color grid.

3. **Advance stages — desktop**
   - From `production/research_qr` or the prow detail modal, the full stage grid (`_avanzamento_full`) shows each unit.
   - Each empty stage links to `production_checkpoint_path(tid:, stage:, date:)`.
   - `ProductionController#checkpoint` sets the flag/date, then checks `hasDoneTempestas?`.
   - When the count of fully completed tempestas equals `prow.qty`, `setProwDone` marks the prow `done = true` and records `datedone`.

4. **Advance stages — mobile QR**
   - Operator opens `app/dashboard_produzione` → Avanzamento → `app/sez`.
   - Picks `F1`–`F5`, scans a unit QR code.
   - The scanner submits to `app_check_single_qr?place=F1`.
   - If a matching Tempesta with that flag null is found, a check button links to `tempesta/set_f?sez=f1&tid=…`.
   - `TempestaController#set_f` sets the flag and date, then redirects back to `app/sez?place=f1`.
   - The same prow-done logic triggers when all units are complete.

5. **Completion & closing**
   - A `Prow` is considered done when all of its `Tempesta`s have `f1`–`f5` set to true.
   - Proformas can be closed manually via the edit form (`closed` flag + `data_out`).

6. **Labels**
   - `production/proformas/:id.pdf` prints one QR label per unit using the prow-level `qr` string (`CreateQrService`).

## Operational gotchas

- The Tempesta state machine is implemented purely with flags on the `Tempesta` model; there is no `Stage` model.
- Completion logic is duplicated: `ApplicationController#hasDoneTempestas?` / `#setProwDone` are used by the desktop flow, while `TempestaCheckService` exists but is currently unused.
- `Stations`, `Areas`, and the `Stages` dashboard/sections pages are not wired into the active production workflow.
- Proforma import is only possible via Excel upload at create time; there is no separate production import pipeline.
- QR label sheets use the prow-level `qr`, but mobile scanning validates against individual `Tempesta#qrcode`.
- There is currently no Excel export for production data; the only output is the PDF label sheet.

## Key files

- Controllers: `app/controllers/production_controller.rb`, `app/controllers/production/proformas_controller.rb`, `app/controllers/prows_controller.rb`, `app/controllers/tempesta_controller.rb`, `app/controllers/stages_controller.rb`, `app/controllers/app_controller.rb`, `app/controllers/application_controller.rb`.
- Models: `app/models/proforma.rb`, `app/models/prow.rb`, `app/models/tempesta.rb`.
- Services: `app/services/import_proformas_service.rb`, `app/services/get_avanzamento_service.rb`, `app/services/create_qr_service.rb`.
- Helpers: `app/helpers/application_helper.rb` (`assign_fs`, `calc_percentage`, `hasDoneTempestas?`, `setProwDone`).
