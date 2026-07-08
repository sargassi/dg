# Application Strategy: Pedone Web App (React + API)

> **Type:** Living strategy document  
> **Author:** ODB — Refactoring & Optimization Agent  
> **Updated:** 2026-06-19  
> **Status:** Pivot — ERB approach abandoned, React approach adopted  
> **Related docs:** `operator-strategy.md` (legacy operator model autopsy), `AGENTS.md` (dev setup)

---

## Table of Contents

1. [Why We Pivoted](#1-why-we-pivoted)
2. [API Gap Analysis](#2-api-gap-analysis)
3. [React App Architecture](#3-react-app-architecture)
4. [API Auth Design](#4-api-auth-design)
5. [Effort Comparison](#5-effort-comparison)
6. [Recommendations](#6-recommendations)
7. [Open Questions](#7-open-questions)

---

## 1. Why We Pivoted

The previous strategy (ERB-based simplified views in AppController) was abandoned for one reason: **the Rails views are a tangled mess, and untangling them is not worth the effort.**

The existing views (`move_products.html.erb` at 177 lines, `out_warehouse.html.erb` at 210 lines, `in_warehouse.html.erb` at 236 lines) have:
- Dual mobile/desktop DOM trees with `lg:hidden` / `hidden lg:block` pattern (~2x code for no benefit)
- Stimulus controllers for QR scanning, autocomplete, nested forms, cascading selects
- A sticky sidebar that fights with itself on mobile
- A nav menu that duplicates the same conditional logic 12 times

Every "simplification" in the ERB approach would be a battle against the existing complexity. We'd end up with ~220 new lines of ERB and a fragile permission gate. For what? The same old server-rendered experience.

**The better bet:** Cut the knot entirely. Build a proper API client in React, served from a separate repo. The Rails API (Grape) already handles the core business logic — it just needs a few missing endpoints and an auth layer.

### What stays the same

The backend doesn't change. The same services handle the same logic:

```
┌──────────────────────┐          ┌──────────────────────┐
│   React SPA (Vite)   │  HTTP    │   Rails API (Grape)  │
│                      │◄────────►│                      │
│  - VAR form          │  JSON    │  - /api/v1/* endpoints│
│  - OUT form          │          │  - MovementBuilder    │
│  - Auth              │          │  - StockLevel services │
│  - QR scan           │          │  - QrParser           │
│  - Confirmation      │          │  - CreateInventories* │
└──────────────────────┘          └──────────────────────┘
                                          │
                                          ▼
                                  ┌──────────────────┐
                                  │  Rails Models    │
                                  │  (no changes)    │
                                  └──────────────────┘
```

---

## 2. API Gap Analysis

### 2.1 What the API Currently Provides

The Grape API is mounted at `/` in routes.rb (`mount API::Base, at: "/"`) and serves under the `/api/v1/` prefix. Here's every endpoint:

| Method | Path | What it does | Needs auth? |
|--------|------|-------------|-------------|
| `GET` | `/api/v1/inventories/lookup?q=` | Returns item info + stock positions by QR/gencode | Yes |
| `POST` | `/api/v1/inventories/inbound` | Goods receipt (IN) | Yes |
| `POST` | `/api/v1/inventories/outbound` | Goods issue (OUT) | Yes |
| `POST` | `/api/v1/inventories/transfer` | Warehouse transfer (VAR) | Yes |
| `GET` | `/api/v1/inventories/stock` | Stock levels with warehouse/location/gencode filters | Yes |
| `GET` | `/api/v1/tempesta` | Production checkpoint query | Yes |
| `GET` | `/api/v1/prows` | List all production rows | Yes |
| `GET` | `/api/v1/prows/:id` | Single production row | Yes |

**None of these have authentication.** There's an `APIToken` model and an `encrypts :token` setup, but no middleware validates it. The API is completely open.

### 2.2 What's Missing for VAR + OUT

Here's every piece of data the forms need, mapped to whether the API provides it:

#### VAR Form (Warehouse Transfer)

| Data needed | API status | Action |
|-------------|-----------|--------|
| List of warehouses (source + dest dropdowns) | **MISSING** | New endpoint: `GET /api/v1/warehouses` |
| Locations by warehouse (cascading dropdown) | **MISSING** | New endpoint: `GET /api/v1/warehouses/:id/locations` |
| Current user info (for operator_id + display) | **MISSING** | Return in login response |
| QR scan → item + stock lookup | **EXISTS** | `GET /api/v1/inventories/lookup?q=` works |
| Autocomplete by itemcode | **PARTIAL** | `lookup` endpoint can serve this (search by any text) |
| Stock validation before submit | **EXISTS** | Done in `POST /api/v1/inventories/transfer` (returns 422) |
| Submit transfer | **EXISTS** | `POST /api/v1/inventories/transfer` |
| Confirmation after submit | **WEAK** | Returns `{ success: true }` — needs movement IDs |

#### OUT Form (Goods Issue)

| Data needed | API status | Action |
|-------------|-----------|--------|
| List of warehouses | **MISSING** | Same endpoint above |
| Locations by warehouse | **MISSING** | Same endpoint above |
| Current user info | **MISSING** | Return in login response |
| QR scan → item + stock lookup | **EXISTS** | Same lookup endpoint |
| Autocomplete by itemcode | **PARTIAL** | Same lookup endpoint |
| Stock validation before submit | **EXISTS** | Done in `POST /api/v1/inventories/outbound` |
| Submit outbound | **EXISTS** | `POST /api/v1/inventories/outbound` |
| Confirmation after submit | **MINIMAL** | Returns `{ id, details_count }` |

#### Auth

| Data needed | API status | Action |
|-------------|-----------|--------|
| Login (email + password) | **MISSING** | New endpoint: `POST /api/v1/auth/login` |
| Token validation on every request | **MISSING** | New Grape middleware |
| Current user profile | **MISSING** | Return with login, or new endpoint |
| CORS | **DONE** | `origins '*'` in cors.rb |

### 2.3 API Response Audits

#### `POST /api/v1/inventories/outbound` — Current response:
```json
{ "id": 42, "details_count": 3 }
```

This is enough for a confirmation screen. The React app can show "OUT #42 created with 3 items." The user trusts the system. If we need detail, we can add a `GET /api/v1/inventories/outbound/:id` endpoint later.

**Verdict:** Usable as-is. But lacking item-level detail for the confirmation page.

#### `POST /api/v1/inventories/transfer` — Current response:
```json
{ "success": true }
```

This is **too minimal**. The frontend has no way to show a meaningful confirmation. The VAR endpoint creates multiple `Itemmovement` records (grouped by source/dest pairs) but doesn't return their IDs.

**Fix needed:** Return the movement IDs:
```json
{ "movement_ids": [1, 2, 3], "success": true, "details_count": 5 }
```

#### `GET /api/v1/inventories/lookup?q=<gencode>` — Current response:
```json
{
  "item": {
    "id": 1, "gencode": "ABC_123", "itemcode": "ABC-001",
    "fabricode": "FAB-01", "varcode": "VAR-001",
    "description": "Blue Widget", "collection": "Spring 2026"
  },
  "stock": [
    { "warehouse_id": 1, "location_id": 5,
      "warehouse": "WH01", "location": "A-12",
      "current_qty": 42 }
  ],
  "inbound": { ... } // optional
}
```

This is **excellent**. Returns item info, stock positions with warehouse/location codes and quantities. The React app can show this immediately in a row after scanning.

#### `GET /api/v1/inventories/stock` — Current response (via entity):
```json
[
  { "gencode": "ABC_123", "current_qty": 42,
    "warehouse_id": 1, "location_id": 5 }
]
```

Note: `warehouse` and `location` objects are **not included** because the entity uses `if: { type: :full }` but the endpoint never passes `type: :full`. This is a bug — stock positions without warehouse/location names are nearly useless in a UI.

**Fix needed:**
```ruby
present stock, with: API::V1::Entities::InventoryDetail, type: :full
```

### 2.4 Summary of API Changes Required

```
┌──────────────────────────────────────────────────────────┐
│  NEW ENDPOINTS (3)                                       │
├──────────────────────────────────────────────────────────┤
│  POST   /api/v1/auth/login           Auth + token        │
│  GET    /api/v1/warehouses           List warehouses      │
│  GET    /api/v1/warehouses/:id/locations  Locations by WH │
├──────────────────────────────────────────────────────────┤
│  ENDPOINT FIXES (2)                                      │
├──────────────────────────────────────────────────────────┤
│  POST   /api/v1/inventories/transfer  Return movement_ids│
│  GET    /api/v1/inventories/stock     Include WH/LOC names│
├──────────────────────────────────────────────────────────┤
│  AUTH MIDDLEWARE (1)                                      │
├──────────────────────────────────────────────────────────┤
│  All endpoints except /auth/login     Validate Bearer token│
└──────────────────────────────────────────────────────────┘
```

---

## 3. React App Architecture

### 3.1 Stack

| Layer | Choice | Why |
|-------|--------|-----|
| **Framework** | React 18+ with TypeScript | Typed, huge ecosystem, RN skill transfer |
| **Build tool** | Vite | Fast dev, simple config, tree-shaking |
| **Styling** | TailwindCSS v3+ | Same as Rails frontend, mobile-first, no CSS file bloat |
| **HTTP client** | Axios or plain `fetch` + interceptor | Axios has cleaner interceptor API for 401 redirects |
| **Server state** | TanStack Query (React Query) v5 | Caching, refetching, loading/error states without Redux |
| **Routing** | React Router v6 | Standard choice, lazy loading |
| **QR scanner** | `@zxing/library` (same as Rails) or `html5-qrcode` | Both work in browser; `html5-qrcode` is simpler |
| **Form state** | React Hook Form + Zod validation | Lightweight, performant, type-safe |

### 3.2 Repo Structure

```
pedone-frontend/
├── src/
│   ├── api/              ← Shared API client module
│   │   ├── client.ts         Axios instance with auth interceptor
│   │   ├── auth.ts           Login, logout, token refresh
│   │   ├── warehouses.ts     Warehouse + location endpoints
│   │   ├── inventories.ts    Lookup, outbound, transfer
│   │   └── types.ts          TypeScript interfaces for all API responses
│   ├── components/
│   │   ├── Layout.tsx        App shell (header, logout, no nav menu)
│   │   ├── QrScanner.tsx     Inline QR scanner component
│   │   ├── ItemRow.tsx       Single item row (code, qty, delete)
│   │   ├── WarehouseSelect.tsx   Cascading warehouse→location
│   │   └── ProtectedRoute.tsx    Auth guard
│   ├── pages/
│   │   ├── Login.tsx
│   │   ├── Dashboard.tsx     Two big buttons: VAR, OUT
│   │   ├── VAR.tsx           Transfer form
│   │   ├── VARConfirm.tsx    Transfer confirmation
│   │   ├── OUT.tsx           Outbound form
│   │   └── OUTConfirm.tsx    Outbound confirmation
│   ├── hooks/
│   │   ├── useAuth.ts
│   │   ├── useWarehouses.ts
│   │   └── useInventory.ts
│   └── App.tsx               Router setup
├── index.html
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
└── package.json
```

### 3.3 Pages / Routes

```
/login           → Login.tsx         Public (no auth)
/dashboard       → Dashboard.tsx     Two buttons: VAR | OUT
/var             → VAR.tsx           Transfer form
/var/confirm     → VARConfirm.tsx    Confirmation after transfer
/out             → OUT.tsx           Outbound form
/out/confirm     → OUTConfirm.tsx    Confirmation after outbound
/*               → Redirect to /login or /dashboard depending on auth
```

**Auth guard logic:**
```
┌─────────────────────┐
│  App.tsx            │
│                     │
│  <AuthProvider>     │
│    <Routes>         │
│      <Route path="/login" element={<Login />} />
│      <Route element={<ProtectedRoute />}>
│        <Route path="/dashboard" element={<Dashboard />} />
│        <Route path="/var" element={<VAR />} />
│        <Route path="/var/confirm" element={<VARConfirm />} />
│        <Route path="/out" element={<OUT />} />
│        <Route path="/out/confirm" element={<OUTConfirm />} />
│      </Route>
│      <Route path="*" element={<Navigate to="/dashboard" />} />
│    </Routes>        │
│  </AuthProvider>    │
└─────────────────────┘
```

### 3.4 Auth Flow

```
┌──────────┐     ┌──────────────┐     ┌──────────────────┐
│  Login   │────►│  POST /auth/ │────►│ Store token in   │
│  Page    │     │  login       │     │ localStorage     │
│          │     │  {email,pass}│     │ Redirect to /    │
│          │     │  → {token}   │     │ dashboard        │
└──────────┘     └──────────────┘     └──────────────────┘
                                               │
                                               ▼
                                      ┌──────────────────┐
                                      │  API Client      │
                                      │                  │
                                      │  Authorization:  │
                                      │  Bearer <token>  │
                                      │                  │
                                      │  On 401: clear   │
                                      │  token, redirect │
                                      │  to /login       │
                                      └──────────────────┘
```

**Token storage:** `localStorage` with a session-only flag. The user checks "Keep me logged in" → `localStorage`, otherwise `sessionStorage`. On app load, check storage for existing token.

**Logout:** Clear storage, invalidate React Query cache, redirect to `/login`.

**Why not cookies?** Cross-domain CORS + cookie auth is fragile. For an internal warehouse app, Bearer token in `localStorage` is fine. No JWT needed — just a random MD5 hash from the `APIToken` model.

### 3.5 State Management

| Data | Source | Cache strategy |
|------|--------|---------------|
| Warehouses list | `GET /api/v1/warehouses` | `staleTime: 5 min` — rarely changes |
| Locations by warehouse | `GET /api/v1/warehouses/:id/locations` | `staleTime: 5 min` — cache per warehouse |
| Item lookup | `GET /api/v1/inventories/lookup?q=` | `staleTime: 0` — always fresh, but cache for current session |
| Stock list (eventual) | `GET /api/v1/inventories/stock` | `staleTime: 30s` — semi-fresh |
| Auth token | localStorage | Read on mount, no caching needed |

**No Redux. No global store beyond React Query.** The only piece of truly global state is the auth token (which lives in storage) and the current user object (which lives in a React context).

### 3.6 Form Design (VAR Example)

```
┌──────────────────────────────────────┐
│  VAR                          Logout │
├──────────────────────────────────────┤
│  Date: [2026-06-19]                  │
│  Note: [__________________________] │
│                                      │
│  ── FROM ────────────  ── TO ────── │
│  Warehouse: [▼]       Warehouse: [▼]│
│  Location:  [▼]       Location:  [▼]│
│                                      │
│  ── Items ────────────────────────── │
│  [ Scan QR ] or type item code...    │
│                                      │
│  Code          │ Qty │ Stock │   │   │
│  ─────────────────────────────────── │
│  ABC-001       │  5  │  42   │ [×] │
│  DEF-002       │  3  │  18   │ [×] │
│  [ + Add Row ]                       │
│                                      │
│  [       Submit Transfer       ]     │
└──────────────────────────────────────┘
```

**Key design decisions:**

1. **Single-column responsive layout.** No dual DOM trees. This is one flex column that looks good on a phone (stacked) and decent on a desktop (wider form). The FROM/TO sections sit side by side on desktop (`md:grid-cols-2`), stacked on mobile.

2. **No sidebar.** The date and notes are inline at the top. The submit button is at the bottom, always visible (sticky on mobile, static on desktop). No sticky sidebar that fights with mobile viewport.

3. **No nav menu.** The only nav element is the page title (back to dashboard) and a logout button. That's it. The dashboard is the "home screen" with two big buttons.

4. **QR scanner is inline, not a modal.** A button labeled "Scan QR" that opens the camera viewfinder inline (replacing the scan button while active). On mobile, this feels natural. On desktop, it's still usable. The `@zxing/library` decoder runs in a `<video>` element.

5. **Autocomplete uses the `lookup` endpoint.** As the user types an item code, debounced (300ms) calls hit `GET /api/v1/inventories/lookup?q=<partial>`. Wait — the current `lookup` endpoint requires an exact QR or gencode match via `QrParser.parse`. It's not a search endpoint. 

   **Issue:** The autocomplete needs a search/filter endpoint, not just exact lookup. The current Rails `ItemsController#autocomplete` action uses Ransack. The Grape API needs something similar.

   **Fix:** Either (a) add a `GET /api/v1/items/search?q=` endpoint that returns matching items, or (b) make `lookup` do fuzzy matching when the input doesn't parse as a QR code. Option (b) is simpler and the frontend already calls `lookup`.

6. **Stock display per row.** After scanning/typing an item code, the row shows the scanned item description and a summary of available stock (e.g., "42 pz in WH01/A-12"). The user doesn't need to navigate away to check stock.

7. **Validation on submit.** Before sending the POST, the frontend does basic validation (qty > 0, required fields filled). The API does stock validation and returns `422` with error messages. The frontend displays these inline per row.

8. **Dynamic rows.** Add/remove items with React state (`useFieldArray` with React Hook Form). No DOM manipulation, no Stimulus controllers.

### 3.7 OUT Form Design

```
┌──────────────────────────────────────┐
│  OUT                           Logout │
├──────────────────────────────────────┤
│  Date: [2026-06-19]                  │
│  Note: [__________________________] │
│                                      │
│  ── FROM ─────────────────────────── │
│  Warehouse: [▼]                      │
│  Location:  [▼]                      │
│                                      │
│  ── Items ────────────────────────── │
│  [ Scan QR ] or type item code...    │
│                                      │
│  Code          │ Qty │ Stock │   │   │
│  ─────────────────────────────────── │
│  ABC-001       │  5  │  42   │ [×] │
│  [ + Add Row ]                       │
│                                      │
│  [       Submit Outbound       ]     │
└──────────────────────────────────────┘
```

Only one warehouse/location selector (the "from" location). The destination is implicit (out of the system). Simpler than VAR by exactly one selector section.

### 3.8 Confirmation Page Design

```
┌──────────────────────────────────────┐
│  OUT — Conferma                Home │
├──────────────────────────────────────┤
│                                      │
│    ✓ Movimento registrato!           │
│                                      │
│    Scarico #47                       │
│    3 articoli spostati               │
│    Da: WH01 / A-12                   │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ABC-001  Blue Widget      × 5  │  │
│  │ DEF-002  Red Gadget       × 3  │  │
│  │ GHI-003  Green Thing      × 1  │  │
│  └────────────────────────────────┘  │
│                                      │
│  [  Nuovo Scarico  ]                 │
│  [  Torna alla Dashboard  ]          │
└──────────────────────────────────────┘
```

Clean, minimal. Shows the movement ID, item list with quantities, and two buttons: "New [operation]" and "Back to Dashboard."

### 3.9 Dashboard Design

```
┌──────────────────────────────────────┐
│  Pedone Dashboard             Logout │
├──────────────────────────────────────┤
│                                      │
│       ┌──────────────┐              │
│       │              │              │
│       │     VAR      │              │
│       │  Trasferimento│              │
│       │              │              │
│       └──────────────┘              │
│                                      │
│       ┌──────────────┐              │
│       │              │              │
│       │     OUT      │              │
│       │   Scarico    │              │
│       │              │              │
│       └──────────────┘              │
│                                      │
└──────────────────────────────────────┘
```

Two big buttons filling the viewport. No tiles, no links, no nav menu. The user's role only allows VAR and OUT, so that's all they see. Large touch targets (minimum 120px height) for gloved hands on a tablet.

### 3.10 Responsive Breakpoints

| Breakpoint | Layout |
|-----------|--------|
| `< 640px` (mobile) | Single column, stacked. Full-width buttons. QR scanner uses full viewport. |
| `640-1024px` (tablet) | Wider form. FROM/TO sections side by side for VAR. |
| `> 1024px` (desktop) | Centered max-width container (`max-w-2xl` or `max-w-3xl`). Same layout as tablet but centered. |

**No separate mobile/desktop templates.** It's a single responsive React component.

### 3.11 Shared API Client Module (for future RN)

The `src/api/` directory is designed as a standalone module that React Native can import:

```
src/api/
├── client.ts        # Axios instance. No browser-specific code.
├── types.ts         # Pure TypeScript interfaces. No dependencies.
├── auth.ts          # login(), logout(), getToken() — uses client
├── warehouses.ts    # getWarehouses(), getLocations(whId)
└── inventories.ts   # lookup(q), submitOutbound(data), submitTransfer(data)
```

**For React Native:** Replace `client.ts` with a RN-compatible HTTP client (or use the same Axios — it works in RN). The API functions stay the same. The types stay the same. The only change is how the token is stored (AsyncStorage instead of localStorage).

---

## 4. API Auth Design

### 4.1 Current State

The `APIToken` model exists and is well-structured:

```ruby
class APIToken < ApplicationRecord
  belongs_to :user
  validates :token, presence: true, uniqueness: true
  before_validation :generate_token, on: :create
  encrypts :token, deterministic: true

  def generate_token
    self.token = Digest::MD5.hexdigest(SecureRandom.hex)
    # self.active = true  ← commented out
  end
end
```

**What's right:**
- `encrypts :token, deterministic: true` — encrypted at rest, queryable (Rails encrypts the search value)
- `belongs_to :user` — ties to existing users
- Token generation uses `SecureRandom` + MD5 — unpredictable and reasonable entropy

**What's wrong:**
- `self.active = true` is **commented out**. Tokens are created with `active: nil` (or `false` depending on the DB default). The middleware can't filter by `active: true` until this is fixed.
- The model exists but is **never used** anywhere. No middleware validates tokens.
- No `has_many :api_tokens` in `User` — wait, it DOES exist (`has_many :api_tokens` in `user.rb` line 2). Good.

### 4.2 Auth Middleware for Grape

Add this to `API::V1::Defaults` (or a separate concern):

```ruby
module API
  module V1
    module Defaults
      extend ActiveSupport::Concern

      included do
        # ... existing config ...

        before do
          authenticate! unless request.path_info.match?(%r{/auth/login$})
        end

        helpers do
          def authenticate!
            token = headers['Authorization']&.sub(/\ABearer /, '')
            error!('Unauthorized', 401) unless token

            @api_token = APIToken.find_by(token: token, active: true)
            error!('Unauthorized', 401) unless @api_token

            @current_user = @api_token.user
          end

          def current_user
            @current_user
          end
        end
      end
    end
  end
end
```

**Important fix needed:** Uncomment `self.active = true` in the model, or add it to the controller when creating tokens. Otherwise `find_by(token: token, active: true)` will never match.

### 4.3 Login Endpoint

New file: `app/controllers/api/v1/auth.rb`

```ruby
module API
  module V1
    class Auth < Grape::API
      include API::V1::Defaults

      resource :auth do
        desc "Authenticate user and return API token"
        params do
          requires :email, type: String, desc: "User email"
          requires :password, type: String, desc: "User password"
        end
        post :login do
          user = User.find_by(email: params[:email])
          error!('Invalid email or password', 401) unless user&.valid_password?(params[:password])

          api_token = user.api_tokens.create!(active: true)
          api_token.reload  # Ensure we read the decrypted token

          present :token, api_token.token
          present :user, {
            id: user.id,
            name: user.name,
            email: user.email,
            roles: user.roles
          }
        end
      end
    end
  end
end
```

Mount it in `API::V1::Base`:

```ruby
module API
  module V1
    class Base < Grape::API
      mount API::V1::Auth
      mount API::V1::Prows
      mount API::V1::Tempestas
      mount API::V1::Inventories
    end
  end
end
```

### 4.4 Devise Integration

The login endpoint uses `user.valid_password?(password)` which comes from Devise's `database_authenticatable` module. This works because:

1. Devise is included in the `User` model: `devise :database_authenticatable, ...`
2. `valid_password?` is a Devise method that uses bcrypt to verify the password hash
3. No need for Warden or session middleware — it's a direct bcrypt check

This is the simplest approach. No Warden hacking, no session sharing, no cookie gymnastics. The Grape endpoint authenticates the password directly and issues a token.

### 4.5 Warehouse + Location Endpoints

In `API::V1::Base` (or a new file `app/controllers/api/v1/warehouses.rb`):

```ruby
module API
  module V1
    class Warehouses < Grape::API
      include API::V1::Defaults

      resource :warehouses do
        desc "List all warehouses"
        get do
          present Warehouse.order(:code), with: API::V1::Entities::WarehouseSimple
        end

        desc "List locations for a warehouse"
        params do
          requires :id, type: Integer, desc: "Warehouse ID"
        end
        get ':id/locations' do
          warehouse = Warehouse.find(params[:id])
          present warehouse.locations.order(:code), with: API::V1::Entities::LocationSimple
        end
      end
    end
  end
end
```

Mount in `Base`:
```ruby
mount API::V1::Warehouses
```

### 4.6 Fix Transfer Response

In `app/controllers/api/v1/inventories.rb`, change the transfer endpoint response from:
```ruby
present :success, true
```
to:
```ruby
present :success, true
present :movement_ids, @created_ids
present :details_count, params[:details].size
```

Wait, but `@created_ids` isn't defined in the Grape version of the endpoint. Looking at the Grape code — the transfer action accumulates movements in a loop but doesn't collect IDs. Let me trace through:

```ruby
params[:details].group_by { |d| [...] }.each do |..., group|
  itemmovement = Itemmovement.new(...)
  group.each do |d|
    # ... build details ...
  end
  ActiveRecord::Base.transaction do
    itemmovement.save!
    CreateInventoriesFromItemmovement.new.call(itemmovement)
  end
end

present :success, true
```

Need to add `created_ids = []` before the loop and `created_ids << itemmovement.id` inside it, then return them.

### 4.7 Fix Stock Endpoint

Change:
```ruby
present stock, with: API::V1::Entities::InventoryDetail
```
to:
```ruby
present stock, with: API::V1::Entities::InventoryDetail, type: :full
```

### 4.8 CORS

Current config is `origins '*'` which is correct for development. In production, if the React app is served from a different domain or port, CORS needs to be locked down to the specific origin.

If the React app is served from the same Rails domain (as static files), CORS isn't even needed. But for a separate repo, you'll likely run it on a different port (e.g., `:5173` for Vite dev) or a different subdomain.

**Recommendation:** Keep `origins '*'` in development. For production, set a specific origin or use an environment variable:
```ruby
origins ENV.fetch('CORS_ORIGINS', '*')
```

---

## 5. Effort Comparison

### 5.1 What's Being Built vs What Was Planned

| | ERB approach (abandoned) | React approach (current) |
|---|---|---|
| **Rails backend changes** | ~40 LOC (controller gates) | ~120 LOC (3 new endpoints + fixes + auth middleware) |
| **Frontend** | ~220 LOC (new ERB views) | ~800-1000 LOC (React app in separate repo) |
| **Auth work** | None (reuses Devise session) | New login endpoint + token middleware |
| **Total new code** | ~260 LOC | ~920-1120 LOC |
| **Total REPO impact** | Tightly coupled to Rails | Separate repo, zero impact on existing code |
| **Learning curve** | Already know ERB/Stimulus | Need to learn React/TypeScript/Vite |
| **Paves way for** | Nothing — same ERB tech debt | React Native app, full frontend migration |
| **Risk** | Confirmation page trap, fragile gates | More up-front code, auth complexity |
| **Future speed** | Same as before (slower) | Much faster (component reuse, API-driven) |
| **Mobile experience** | Responsive but fragile | Mobile-first by design |
| **Testing** | System tests (Capybara) | Component tests (Vitest + Testing Library) |
| **Deployment** | Capistrano deploy (existing) | Separate deploy (Vercel? Nginx? Rails static?) |

### 5.2 Why This Is Worth It

On paper, the React approach is ~4x more code. Here's why it's still the right call:

1. **The ERB views are a dead end.** Every feature added to the Rails views is another layer of complexity on top of a shaky foundation (dual-render, Stimulus, importmaps). You're fighting the framework's weaknesses.

2. **The API is already built.** The Grape API handles the business logic. We're adding 3 small endpoints and an auth layer. The heavy lifting (MovementBuilder, StockLevel, QrParser, CreateInventories*) stays untouched.

3. **React components are composable.** Once you build `ItemRow`, `WarehouseSelect`, and `QrScanner`, you reuse them in VAR, OUT, IN, and any future operation. In ERB, you duplicate HTML every time.

4. **Mobile is not an afterthought.** The React app is mobile-first from day one. No `lg:hidden` / `hidden lg:block` pattern. No "mobile version" that's different from the "desktop version." It's one layout that works everywhere.

5. **React Native is the same codebase.** The `src/api/` module works unchanged in React Native. The types are shared. The business logic is shared. When someone says "we need this on a tablet," you hand them an APK/IPA instead of explaining why the web page doesn't feel right on a 10-inch screen.

### 5.3 The Real Cost

Let's be honest about what this costs:

- **TypeScript setup time:** Type definitions for every API response, form state, component props. This is 20% of the work but pays for itself on the first refactor.
- **Auth complexity:** The Rails app already has Devise. Adding token auth on top is extra work, and token refresh/revocation adds more surface area.
- **Two deployments:** Instead of one Capistrano deploy, you now deploy the Rails API AND the React app. This is more moving parts, more CI/CD, more monitoring.
- **Developer context switching:** If one person is doing both frontend and backend, they're context-switching between Ruby and TypeScript constantly.

---

## 6. Recommendations

### 6.1 Do This.

The React approach is the right call. The ERB approach was a band-aid on a broken window. The React approach is replacing the window.

### 6.2 Implementation Order

**Phase 1 — API auth (2-3 hours)**

1. Uncomment `self.active = true` in `APIToken` model
2. Create `app/controllers/api/v1/auth.rb` with `POST /api/v1/auth/login`
3. Add auth middleware to `API::V1::Defaults` (skip for `/auth/login`)
4. Mount `API::V1::Auth` in `API::V1::Base`
5. Test with `curl` that login returns a token and subsequent requests pass auth

**Phase 2 — Missing endpoints (2-3 hours)**

1. Create `app/controllers/api/v1/warehouses.rb` with `GET /api/v1/warehouses` and `GET /api/v1/warehouses/:id/locations`
2. Fix `POST /api/v1/inventories/transfer` to return movement IDs
3. Fix `GET /api/v1/inventories/stock` to include warehouse/location names
4. Create a `GET /api/v1/items/search?q=` endpoint for autocomplete (or enhance `lookup` to do fuzzy matching)
5. Mount `Warehouses` in `Base`

**Phase 3 — React scaffold (4-6 hours)**

1. `npm create vite@latest pedone-frontend -- --template react-ts`
2. Install dependencies: `react-router-dom`, `@tanstack/react-query`, `axios`, `react-hook-form`, `@hookform/resolvers`, `zod`, `tailwindcss`, `@zxing/library`
3. Set up TailwindCSS, folder structure
4. Build `src/api/client.ts` (Axios instance with auth interceptor)
5. Build `src/api/types.ts` (TypeScript interfaces)
6. Build `src/components/ProtectedRoute.tsx` and auth context
7. Build `src/pages/Login.tsx`

**Phase 4 — Dashboard + forms (6-8 hours)**

1. Build `src/pages/Dashboard.tsx` — two big buttons
2. Build `src/components/WarehouseSelect.tsx` — cascading selects with React Query
3. Build `src/components/QrScanner.tsx` — `@zxing/library` inline scanner
4. Build `src/components/ItemRow.tsx` — code input, qty, stock display, delete button
5. Build `src/pages/VAR.tsx` — transfer form using all the components above
6. Build `src/pages/OUT.tsx` — outbound form (simpler, reuses components)
7. Build confirmation pages

**Phase 5 — Polish + deploy (2-3 hours)**

1. Error handling: 422 responses, network errors, auth expiry
2. Loading states: skeleton screens, spinners
3. Offline detection: "No connection" banner
4. Deploy: build to static files, serve from Rails `public/` or separate Nginx

**Total estimated effort: ~16-22 hours**

### 6.3 What We're NOT Doing (Yet)

| Feature | When |
|---------|------|
| React Native app | After the web app is stable and the API client is proven |
| IN (goods receipt) | Not requested for pedone. The API endpoint exists when needed. |
| Inventory list screens | The stock endpoint exists, but no UI yet. Add when needed. |
| QR label printing | Separate feature. Not needed for this sprint. |
| Token revocation | The `APIToken` model supports it (set `active: false`). Add UI when needed. |

---

## 7. Open Questions

### 7.1 APIToken Encryption Setup

**Question:** Does `encrypts :token, deterministic: true` actually work in this app?

The model uses Rails 7's Active Record encryption, which requires:
```bash
bin/rails db:encryption:init
```
This generates a key and sets it in `credentials.yml.enc`. If this hasn't been done, `APIToken.create!` will raise `ActiveRecord::Encryption::Errors::Configuration`.

**Check:** Run `bin/rails runner "p ActiveRecord::Encryption.config.primary_key"` to see if it's configured.

**Fallback:** If encryption isn't set up, either (a) configure it (recommended — it's already in the model), or (b) replace `encrypts :token` with a simple `has_secure_token` approach. But (a) is better because the model already has the encryption declaration.

### 7.2 Autocomplete — Search vs Exact Lookup

**Question:** The current `lookup` endpoint parses input as a QR code. How does autocomplete work?

The existing `ItemsController#autocomplete` uses Ransack. The Grape API doesn't have this.

**Options:**
1. **Enhance `lookup` endpoint** to accept partial text and return matching items (fuzzy search via SQL `LIKE` on `gencode`, `itemcode`, `description`)
2. **New endpoint** `GET /api/v1/items/search?q=` that returns matching items (with stock summary)
3. **Frontend-only filtering** — load all items (not feasible for large catalogs)

**Recommendation:** Option 1 — enhance `lookup`. It's the same endpoint the frontend already calls, and the change is backward-compatible. If the input doesn't parse as a QR code, fall back to a LIKE search on itemcode/gencode/description.

### 7.3 Deployment — Where Does the React App Live?

**Question:** How is the React app deployed?

| Option | How | Pros | Cons |
|--------|-----|------|------|
| **Serve from Rails** | Build to `public/pedone/` | Single deploy, same domain, no CORS issues | Adds to Rails deploy time, couples frontend to Rails |
| **Separate server** | Nginx/Caddy on same VPS, different port | Independent deploy, can scale separately | Need to manage another process, CORS config |
| **Vercel/Netlify** | Connect git repo | Zero-ops deploy, preview URLs, CDN | Third-party hosting for internal app? |
| **Capistrano job** | Add a Capistrano task to build + rsync | Stays in existing deploy workflow | Need to add Node to the server |

**Recommendation:** **Serve from Rails in production.** Build the React app into `public/pedone/` during Capistrano deploy. The same domain means no CORS issues, no additional servers, and the existing auth (token-based) works without cookie sharing. Add a Capistrano task:

```ruby
# config/deploy.rb
namespace :pedone do
  task :build do
    on roles(:web) do
      within release_path do
        execute :npm, 'run', 'build', '--prefix', 'pedone-frontend'
        execute :cp, '-r', 'pedone-frontend/dist/', release_path.join('public/pedone/')
      end
    end
  end
end

after 'deploy:updated', 'pedone:build'
```

For development, run Vite on `:5173` with `vite.config.ts` proxying `/api/` to Rails on `:3000`.

### 7.4 Grape + Devise: Any Conflicts?

**Question:** Will the Grape auth middleware conflict with existing Devise session auth?

The existing web UI uses Devise sessions (cookie-based). The new API uses Bearer tokens (header-based). These are independent auth mechanisms on the same Rails app. The Grape middleware should NOT touch Devise sessions and vice versa.

**Risk:** If a user is logged in via Devise AND makes API requests, both auth methods could be valid. This isn't a security problem — it's just redundant. But be careful not to accidentally read session cookies in the API middleware (don't).

**Recommendation:** Keep them separate. The Grape middleware ONLY checks `Authorization: Bearer <token>`. The web controllers ONLY check Devise sessions. No cross-contamination.

### 7.5 Number of Users — Is This Worth It?

**Question:** If there are only 1-2 pedone users, is a whole React app worth building?

This was asked in the ERB strategy too. The answer is the same: **yes, but for different reasons now.**

The ERB approach was worth it because it was low-effort (~$600 value in simplified views). The React approach is worth it because it's a **foundation for the future**:
- The API becomes documented and consumable by other tools
- The frontend becomes composable and testable
- Mobile apps become a weekend project instead of a rewrite
- The next developer who touches this codebase won't cry when they see the ERB views

If the app dies in a year, the React approach was overkill. If it's still running in 3 years, the React approach was the cheapest option.

### 7.6 What About the Existing `namespace :api` in routes.rb?

**Question:** There's already a Rails-native API namespace at `routes.rb:170`:
```ruby
namespace :api do
  namespace :v1 do
    defaults format: :json do
      get "home/index", to: "home#index"
      get "home/list_qrs"
    end
  end
end
```

This coexists with the Grape API. The Grape mount at `mount API::Base, at: "/"` handles `/api/v1/inventories/*`, `/api/v1/prows/*`, etc. The Rails routes handle `/api/v1/home/*`.

**Recommendation:** Keep both. The Grape API handles the inventory operations. The Rails-native API handles home/index and list_qrs. Don't merge them — they serve different purposes and the Rails-native routes are minimal.

---

*End of strategy document. This is a living document — update it as decisions change.*
