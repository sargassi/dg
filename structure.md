# DG Production Tracking App - Structure

## 1. Tech Stack
- **Framework**: Rails 7.0.7, Ruby 3.2.2 
- **Database**: SQLite
- **Styling**: TailwindCSS (via tailwindcss-rails)
- **Auth**: Devise
- **PDF**: wicked_pdf + wkhtmltopdf
- **QR Codes**: rqrcode
- **API**: Grape
- **Frontend**: Importmaps, Turbo (Hotwire), Stimulus

---

## 2. Data Models

### Core Domain (Production Tracking)

| Model | Description | Key Fields |
| :--- | :--- | :--- |
| **Proforma** | Order/batch containing prow items | id, code, customer, closed, date |
| **Prow** | Individual item in a proforma | id, proforma_id, itemcode, fabricode, varcode, tg, color, qty, fabric, materiale, description, qr, identifier, done, done_date |
| **Tempesta** | Production check for each Prow (stages F1-F5) | id, prow_id, proforma_id, qrcode, order, f1/f1date, f2/f2date, f3/f3date, f4/f4date, f5/f5date, is_done, user_id |

### Fabric/Lab Samples

| Model | Description |
| :--- | :--- |
| **Etilab** | Lab sample items (grouped) |
| **Eticamp** | Campaign/sample items |
| **Etigen** | Generic sample items |
| **Fabriclu** | Fabric inventory/lookup |

### Warehouse/Stock

| Model | Description |
| :--- | :--- |
| **Station** | Work station |
| **Area** | Warehouse area |
| **Rail** | Storage rail |
| **Product**, **Item**, **Inventory** | Stock management |
| **Itemin**, **Itemout** | In/out records |

### Other

| Model | Description |
| :--- | :--- |
| **User** | Devise user (auth) |
| **Operator** | Machine operator |
| **Event**, **Eventype** | Activity logging |
| **Taglium**, **Rassegna** | Additional domain |

---

## 3. Controllers

### Main Controllers
- `dashboard_controller.rb` - Main dashboard (\`/dashboard/home\`)
- `production_controller.rb` - Production flow (\`/production/*\`)
- `tempesta_controller.rb` - Tempesta CRUD (\`/tempesta/set_f\`)
- `prows_controller.rb` - Prow management
- `proformas_controller.rb` - Proforma management
- `app_controller.rb` - General app routes (\`/app/*\`)
- `stages_controller.rb` - Stage handling (\`/stages/*\`)

### Import Controllers
- `etilabs_controller.rb` - Lab imports
- `eticamps_controller.rb` - Campaign imports
- `etigens_controller.rb` - Generic imports
- `products_imports_controller.rb` - Product imports
- `fabriclus_controller.rb` - Fabric data

### Utility Controllers
- `utilities_controller.rb` - Labels/QR generation (\`/utilities/*\`)
- `basic_qr_codes_controller.rb` - QR scanning

### API Controllers
- `api/v1/base.rb` - Grape API base
- `api/v1/prows.rb` - Prow API
- `api/v1/tempestas.rb` - Tempesta API

---

## 4. Services

| Service | Purpose |
| :--- | :--- |
| **DashboardService** | Returns dashboard sections (F1-F5) |
| **ProwSearchService** | Search prows with ransack |
| **TempestaCheckService** | Process QR scan, update stages, finalize prow |
| **GetAvanzamentoService** | Calculate production progress |
| **CreateQrService** | Generate QR code images |
| **CheckQrCodeService** | (stub - incomplete) |
| **ImportProformasService** | Import proforma spreadsheets |
| **ImportEtilabService** | Import lab samples |
| **ImportEticampService** | Import campaign items |
| **ImportHistoryTextService** | Import fabric history |
| **CreateCanvasPagesService** | Generate sample pages |

---

## 5. Key Routes

### Dashboard
\`\`\`
GET /dashboard/home
GET /app/dashboard
GET /app/sez
\`\`\`

### Production
\`\`\`
GET /production/research         # Search prows
GET /production/research_qr    # Search by QR
GET /production/checkpoint     # Stage checkpoint
GET /production/checkpoint_single
\`\`\`

### Tempesta / Stages
\`\`\`
GET /tempesta/set_f
GET /stages/dashboard
GET /stages/sections
\`\`\`

### Imports
\`\`\`
GET  /etilabs/import
POST /utilities/etilabimp       # Import lab
POST /utilities/eticampimp    # Import campaign
POST /utilities/etilgenimp   # Import generic
\`\`\`

### Utilities / Labels
\`\`\`
GET /utilities/etichette
GET /utilities/etichette_camp
GET /utilities/etichette_lab
GET /utilities/etichette_gen
GET /eticamps/etichette
GET /etigens/etichette
GET /products/etichette
GET /basic-qr-code-reader
GET /basic_qr_codes/qrcheck
\`\`\`

### API
\`\`\`
GET /api/v1/home/index
GET /api/v1/home/list_qrs
\`\`\`

---

## 6. API Endpoints

Base path: \`/api/v1/\`

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| \`/home/index\` | GET | Dashboard data |
| \`/home/list_qrs\` | GET | List QR codes |

---

## 7. Production Flow

\`\`\`
1. Create Proforma (order/batch)
2. Import Prows (items) via ImportProformasService
3. For each Prow, Tempesta records created (qty = number of checks)
4. Stage scanning via QR:
   - F1 → F2 → F3 → F4 → F5
   - Each stage sets flag + date on Tempesta
5. When all stages done → Prow marked done
\`\`\`

---

## 8. Known Issues (to fix)

- **prow_search_service.rb:6** - \`params\` undefined (need method parameter)
- **import_etilab_service.rb:9** - Variable inconsistency (\`lastNum\` vs \`lastnum\`)
- **import_eticamp_service.rb:9** - References wrong model (\`Etilab\` instead of \`Eticamp\`)
- **create_qr_service.rb** - Returns nil (PNG not returned properly)
- **check_qr_code_service.rb** - Empty stub (no implementation)

---

## 9. File Structure

\`\`\`
app/
├── controllers/
├── models/
├── services/
├── views/
config/
├── routes.rb
db/
test/
\`\`\`

---

*Generated: 2026-04-24*
