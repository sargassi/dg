# DG (Okam) — Project Overview

A Rails 7.2 inventory, production tracking, and archive management application for Gregis (Italian fashion/textile manufacturing).

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Ruby on Rails 7.2 (Ruby 3.2.2) |
| **Database** | SQLite 3 (dev/test), MariaDB/MySQL optional (docker-compose.yml) |
| **Frontend** | Hotwire (Turbo + Stimulus), importmaps, TailwindCSS |
| **Auth** | Devise (database_authenticatable, lockable, trackable, recoverable) |
| **APIs** | Grape (REST), `rabl` + `grape-active_model_serializers` |
| **PDF** | wicked_pdf + wkhtmltopdf |
| **QR Codes** | rqrcode |
| **Spreadsheets** | roo (import), caxlsx (export) |
| **Rich Text** | Trix (Action Text) |
| **File Uploads** | CarrierWave (photos), Active Storage (attachments) |
| **Image Processing** | image_processing (~1.2) |
| **Pagination** | Pagy (~7.0) |
| **Search** | Ransack (~4.0) |
| **Calendar** | simple_calendar |
| **Deployment** | Capistrano 3.x (rbenv + Passenger) |
| **CORS** | rack-cors |
| **Redis** | redis (~4.0, Action Cable) |
| **Reorder** | SortableJS (vendor) |

---

## Section Purposes

### 1. Inventory & Warehouse Management (`inventories/`, `warehouses/`, `locations/`)

Core inventory tracking. Manages stock levels across warehouses/locations, inbound receipts (`itemins`), outbound shipments (`itemouts`), movements between locations (`itemmovements`), and stock adjustments. Uses QR codes on items/locations/warehouses for scanning workflows.

Key pages:
- **inventories/import** — bulk CSV/Excel import pipeline (parse → verify → confirm → summary)
- **inventories/seleziona** — stock selection for picking
- **inventories/movements** — movement log with PDF label generation
- **inventories/dashboard** — inventory overview
- **warehouses/merge** — merge two warehouses
- **warehouses/qrcodes** — print QR codes for locations/warehouses

### 2. Items & Products (`items/`, `products/`)

Item catalog (raw materials/garments) and product catalog (finished goods). Items carry QR codes, pricing, collections association, photo galleries. Products are production-ready items with status tracking.

### 3. Production / Tempesta System (`production/`, `prows/`, `tempesta/`, `proformas/`)

Production workflow management. A **proforma** (production order) contains multiple **prows** (production rows). Each prow is worked through **tempestas** — a state-machine with 6 boolean flags (f0–f5, each with optional date) representing production stages (e.g., cutting, sewing, finishing). Tempestas have QR codes for scan-to-advance.

Key pages:
- **production/dashboard** — production overview
- **production/research** / **research_qr** — search production items
- **production/checkpoint** / **checkpoint_single** — QR scan to advance tempesta stages
- **tempesta/set_f** — manually set tempesta flags
- **stages/dashboard** / **sections** — production stages overview

### 4. Archive System (`archive/`)

A separate asset tracking module for non-production inventory (tools, equipment, etc.). Items have categories, types, and locations in a hierarchy. Supports check-in/check-out workflows with transaction history, QR codes, and bulk import from inventory.

### 5. Etichette (Labels) (`etichecks/`, `eticamps/`, `etilabs/`, `etigens/`)

Four label printing modules for different item types:
- **etichecks** — check labels (items with fabric/color/qty details)
- **eticamps** — sample/campione labels
- **etilabs** — laboratory labels
- **etigens** — generic labels (multi-line text with quantities)

### 6. Directory & Events (`directory/`, `events/`, `eventypes/`)

Employee directory (users list with profiles). Event calendar system with types (eventypes), start/end dates, recurrence, and enable/disable toggling.

### 7. User & Role Management (`admin/`)

Admin section for user CRUD, permission management via **abilities** (granular permissions, granted by godlike users), and **roles** (e.g., `pedone` for warehouse operator).

### 8. App / Mobile Interface (`app/`)

A simplified mobile-friendly interface for warehouse operators (role: `pedone`). Supports:
- **in_warehouse** — scan-to-receive items
- **out_warehouse** — scan-to-ship items
- **move_products** — scan-to-move between locations
- **inserimento** — quick item creation
- **check_single_qr** — QR lookup
- **sez** — selection/research

### 9. Collections (`collections/`)

Product collections (e.g., seasonal lines) with drag-and-drop reordering (SortableJS). Items can belong to a collection.

### 10. RAS Segnalazioni / Press Review (`rassegnas/`)

Press review / press clippings database (Italian "rassegna stampa"). Stores articles with metadata (title, journalist, publication, date, photographer, etc.).

### 11. Fabric Library (`fabriclus/`)

Fabric catalog with technical details (weight mtkg, pricing, materials, colors, supplier/customer). Used by items and products.

### 12. Utilities (`utilities/`)

Bulk import tools for label data (eticheck, eticamp, etilab, etigen imports from spreadsheets).

### 13. Configuration / System

- **operationtypes** — types of inventory operations (receipt, shipment, adjustment, etc.)
- **uoms** — units of measure
- **stations** — production stations/checkpoints
- **areas** — production areas
- **taglia** — sizes
- **toolbar_configs** — customizable navigation toolbar
- **rails** — racks/shelving units
- **Mainware** — legacy main warehouse import module with multi-step Excel import pipeline

### 14. API Layer

Grape-based REST API served at two mounts:
- `API::Base` mounted at `/` (`mount API::Base, at: "/"` in `config/routes.rb`)
- Rails namespace routes under `/api/v1`

Endpoints serve JSON for home/index, QR code listing, inventory data, prow/tempesta data (for mobile scanners or external clients).

### 15. Authentication & Authorization

Devise-based with custom ability system:
- **user_types** — company_operator, customer, supplier
- **roles** — assigned via `user_roles` (e.g., `pedone`)
- **abilities** — fine-grained permissions managed in admin panel
- **godlike** — superadmin flag bypasses all checks
