# Pedone React Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a mobile-first React web app for pedone users to perform VAR (warehouse transfer) and OUT (goods issue) operations through the existing Grape API.

**Architecture:** Add auth + 3 new endpoints to the Rails Grape API, then build a separate React SPA (Vite + TypeScript) in its own repo. The React app consumes the API and serves as the foundation for a future React Native app.

**Tech Stack:** Rails 7.2 / Grape 3.2 / APIToken auth + Vite / React 18 / TypeScript / TanStack Query / React Hook Form / TailwindCSS / @zxing/library

---

### Task 1: Fix APIToken Model + Configure Encryption

**Files:**
- Modify: `app/models/api_token.rb`
- Run: Rails encryption key setup

- [ ] **Step 1: Configure ActiveRecord encryption**

Run: `bin/rails db:encryption:init`
Expected: Outputs a `primary_key`, `deterministic_key`, and `key_derivation_salt`.
Add them to credentials: `EDITOR="nano" bin/rails credentials:edit`

- [ ] **Step 2: Verify encryption works**

Run: `bin/rails runner "t = APIToken.create!(user: User.first, active: true); puts t.token; puts APIToken.find_by(token: t.token).inspect"`
Expected: Token is generated, lookup by token works (deterministic encryption).

- [ ] **Step 3: Fix active default**

In `app/models/api_token.rb`, change:
```ruby
# before_validation :set_active, on: :create
```
to:
```ruby
before_validation :set_active, on: :create

private

def set_active
  self.active = true
end
```

- [ ] **Step 4: Create a seed token for dev**

In `db/seeds.rb` (or a new rake task), add:
```ruby
if Rails.env.development? && User.exists? && APIToken.count == 0
  User.where(godlike: true).each do |u|
    u.api_tokens.create!
  end
end
```

---

### Task 2: Auth Endpoint + Grape Middleware

**Files:**
- Create: `app/controllers/api/v1/auth.rb`
- Modify: `app/controllers/api/v1/defaults.rb`
- Modify: `app/controllers/api/v1/base.rb`

- [ ] **Step 1: Create auth endpoint**

`app/controllers/api/v1/auth.rb`:
```ruby
module API
  module V1
    class Auth < Grape::API
      include API::V1::Defaults

      resource :auth do
        desc "Authenticate user and return token"
        params do
          requires :email, type: String
          requires :password, type: String
        end
        post :login do
          route_setting :auth, false
          user = User.find_by(email: params[:email])
          error!('Invalid email or password', 401) unless user&.valid_password?(params[:password])
          error!('Account disabled', 403) unless user.enabled?

          token = user.api_tokens.create!
          {
            token: token.token,
            user: {
              id: user.id,
              name: [user.name, user.lastname].compact.join(' '),
              email: user.email,
              roles: user.roles
            }
          }
        end
      end
    end
  end
end
```

- [ ] **Step 2: Add auth middleware to Defaults**

In `app/controllers/api/v1/defaults.rb`:
```ruby
helpers do
  # ... existing helpers ...

  def authenticate!
    header = headers['Authorization']
    error!('Missing Authorization header', 401) unless header
    token_str = header.sub(/\ABearer /, '')
    api_token = APIToken.find_by(token: token_str, active: true)
    error!('Invalid or expired token', 401) unless api_token
    @current_user = api_token.user
  end

  def current_user
    @current_user
  end
end
```

Add a `before` hook inside the `included do` block:
```ruby
included do
  # ... existing setup ...

  before do
    authenticate! unless route.settings[:auth] == false
  end
end
```

- [ ] **Step 3: Mount Auth in Base**

In `app/controllers/api/v1/base.rb`:
```ruby
mount API::V1::Auth
```

- [ ] **Step 4: Test auth flow**

Run: `curl -s -X POST http://localhost:3000/api/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"admin@example.com","password":"password"}'`
Expected: Returns `{ token: "...", user: {...} }`

Run: `curl -s http://localhost:3000/api/v1/inventories/stock -H 'Authorization: Bearer <token>'`
Expected: Returns stock data (200)

Run: `curl -s http://localhost:3000/api/v1/inventories/stock`
Expected: Returns 401

---

### Task 3: Warehouses + Locations Endpoints

**Files:**
- Create: `app/controllers/api/v1/warehouses.rb`
- Modify: `app/controllers/api/v1/base.rb`

- [ ] **Step 1: Create warehouses endpoint**

`app/controllers/api/v1/warehouses.rb`:
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
          requires :id, type: Integer
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

- [ ] **Step 2: Mount Warehouses in Base**

In `app/controllers/api/v1/base.rb`, add:
```ruby
mount API::V1::Warehouses
```

- [ ] **Step 3: Test**

Run: `curl -s http://localhost:3000/api/v1/warehouses -H 'Authorization: Bearer <token>'`
Expected: Returns JSON array of warehouses with id + code

Run: `curl -s http://localhost:3000/api/v1/warehouses/1/locations -H 'Authorization: Bearer <token>'`
Expected: Returns JSON array of locations with id + code

---

### Task 4: Fix Existing Endpoints

**Files:**
- Modify: `app/controllers/api/v1/inventories.rb`
- Modify: `app/controllers/api/v1/entities/inventory_detail.rb`

- [ ] **Step 1: Fix transfer response**

In `POST /api/v1/inventories/transfer`, collect movement_ids and return them:
```ruby
movement_ids = []
params[:details].group_by { |d|
  [d[:source_warehouse_id], d[:source_location_id],
   d[:dest_warehouse_id], d[:dest_location_id]]
}.each do |(src_wh, src_loc, dst_wh, dst_loc), group|
  # ... existing code ...
  movement_ids << itemmovement.id
end

present :success, true
present :movement_ids, movement_ids
```

- [ ] **Step 2: Fix stock endpoint to include warehouse/location names**

In `GET /api/v1/inventories/stock`, change:
```ruby
present stock, with: API::V1::Entities::InventoryDetail
```
to:
```ruby
present stock, with: API::V1::Entities::InventoryDetail, type: :full
```

- [ ] **Step 3: Test stock endpoint**

Run: `curl -s 'http://localhost:3000/api/v1/inventories/stock' -H 'Authorization: Bearer <token>'`
Expected: Each record includes `warehouse: { id, code }` and `location: { id, code }`

---

### Task 5: Enhance Lookup for Autocomplete

**Files:**
- Modify: `app/controllers/api/v1/inventories.rb`

- [ ] **Step 1: Add fallback search to lookup endpoint**

When QrParser returns only a plain text (no detail_id), fall back to a LIKE search instead of requiring exact match:

```ruby
get :lookup do
  text = params[:q].to_s.strip
  parsed = QrParser.parse(text)

  items = if parsed[:detail_id]
    item = Item.find_by(gencode: parsed[:gencode])
    item ? [item] : []
  else
    Item.where('gencode LIKE :q OR itemcode LIKE :q OR fabricode LIKE :q OR varcode LIKE :q',
               q: "%#{text}%").limit(10).to_a
  end

  error!('No items found', 404) if items.empty?

  results = items.map do |item|
    stock = StockLevel.where(gencode: item.gencode).positive.includes(:warehouse, :location)
    {
      item: {
        id: item.id, gencode: item.gencode, itemcode: item.itemcode,
        fabricode: item.fabricode, varcode: item.varcode,
        description: item.description, collection: item.collection&.description
      },
      stock: stock.map { |sl|
        { warehouse_id: sl.warehouse_id, location_id: sl.location_id,
          warehouse: sl.warehouse&.code, location: sl.location&.code,
          current_qty: sl.current_qty }
      }
    }
  end

  present :results, results
end
```

- [ ] **Step 2: Test autocomplete**

Run: `curl -s 'http://localhost:3000/api/v1/inventories/lookup?q=ABC' -H 'Authorization: Bearer <token>'`
Expected: Returns `{ results: [...] }` with items matching "ABC"

---

### Task 6: Scaffold React App (Separate Repo)

**Note:** This happens OUTSIDE the Rails repo. Create a new directory next to the Rails project.

- [ ] **Step 1: Create Vite project**

```bash
cd /Users/sargassi/yaminokodo
npm create vite@latest pedone-frontend -- --template react-ts
cd pedone-frontend
npm install
```

- [ ] **Step 2: Install dependencies**

```bash
npm install react-router-dom @tanstack/react-query axios react-hook-form @hookform/resolvers zod
npm install -D tailwindcss @tailwindcss/vite
npm install @zxing/browser @zxing/library
```

- [ ] **Step 3: Configure TailwindCSS + proxy**

Update `vite.config.ts`:
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    proxy: {
      '/api': 'http://localhost:3000'
    }
  }
})
```

Replace `src/index.css` with:
```css
@import "tailwindcss";
```

- [ ] **Step 4: Create folder structure**

```
src/
  api/
    client.ts
    types.ts
    auth.ts
    warehouses.ts
    inventories.ts
  components/
    ProtectedRoute.tsx
    WarehouseSelect.tsx
    LocationSelect.tsx
    ItemRow.tsx
    QrScanner.tsx
  pages/
    Login.tsx
    Dashboard.tsx
    VAR.tsx
    VARConfirm.tsx
    OUT.tsx
    OUTConfirm.tsx
  hooks/
    useAuth.ts
    useStockLookup.ts
  App.tsx
  main.tsx
```

---

### Task 7: React API Client + Auth

**Files** (all in `pedone-frontend/src/api/`):
- Create: `client.ts`
- Create: `types.ts`
- Create: `auth.ts`

- [ ] **Step 1: Define TypeScript types**

`src/api/types.ts`:
```typescript
export interface User {
  id: number;
  name: string;
  email: string;
  roles: string[];
}

export interface AuthResponse {
  token: string;
  user: User;
}

export interface Warehouse {
  id: number;
  code: string;
}

export interface Location {
  id: number;
  code: string;
}

export interface StockPosition {
  warehouse_id: number;
  location_id: number;
  warehouse: string;
  location: string;
  current_qty: number;
}

export interface ItemSummary {
  id: number;
  gencode: string;
  itemcode: string;
  fabricode: string;
  varcode: string;
  description: string;
  collection: string | null;
}

export interface ItemLookup {
  item: ItemSummary;
  stock: StockPosition[];
}

export interface LookupResponse {
  results: ItemLookup[];
}

export interface TransferDetail {
  gencode: string;
  qty: number;
  source_warehouse_id: number;
  source_location_id: number;
  dest_warehouse_id: number;
  dest_location_id: number;
}

export interface OutboundDetail {
  gencode: string;
  qty: number;
  warehouse_id: number;
  location_id: number;
}

export interface TransferResponse {
  success: boolean;
  movement_ids: number[];
}

export interface OutboundResponse {
  id: number;
  details_count: number;
}
```

- [ ] **Step 2: Build Axios client**

`src/api/client.ts`:
```typescript
import axios from 'axios';

const client = axios.create({
  baseURL: '/api/v1',
  headers: { 'Content-Type': 'application/json' },
});

client.interceptors.request.use((config) => {
  const token = localStorage.getItem('pedone_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

client.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('pedone_token');
      localStorage.removeItem('pedone_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default client;
```

- [ ] **Step 3: Build auth API module**

`src/api/auth.ts`:
```typescript
import client from './client';
import type { AuthResponse, User } from './types';

export async function login(email: string, password: string): Promise<AuthResponse> {
  const { data } = await client.post<AuthResponse>('/auth/login', { email, password });
  localStorage.setItem('pedone_token', data.token);
  localStorage.setItem('pedone_user', JSON.stringify(data.user));
  return data;
}

export function logout(): void {
  localStorage.removeItem('pedone_token');
  localStorage.removeItem('pedone_user');
}

export function getStoredUser(): User | null {
  const raw = localStorage.getItem('pedone_user');
  return raw ? JSON.parse(raw) : null;
}

export function getToken(): string | null {
  return localStorage.getItem('pedone_token');
}
```

- [ ] **Step 4: Build warehouse + inventory API modules**

`src/api/warehouses.ts`:
```typescript
import client from './client';
import type { Warehouse, Location } from './types';

export async function fetchWarehouses(): Promise<Warehouse[]> {
  const { data } = await client.get<Warehouse[]>('/warehouses');
  return data;
}

export async function fetchLocations(warehouseId: number): Promise<Location[]> {
  const { data } = await client.get<Location[]>(`/warehouses/${warehouseId}/locations`);
  return data;
}
```

`src/api/inventories.ts`:
```typescript
import client from './client';
import type {
  LookupResponse, TransferDetail, OutboundDetail,
  TransferResponse, OutboundResponse
} from './types';

export async function lookupItem(q: string): Promise<LookupResponse> {
  const { data } = await client.get<LookupResponse>('/inventories/lookup', {
    params: { q }
  });
  return data;
}

export async function submitOutbound(
  indate: string,
  operator_id: number,
  details: OutboundDetail[]
): Promise<OutboundResponse> {
  const { data } = await client.post<OutboundResponse>('/inventories/outbound', {
    indate, operator_id, details
  });
  return data;
}

export async function submitTransfer(
  indate: string,
  operator_id: number,
  details: TransferDetail[]
): Promise<TransferResponse> {
  const { data } = await client.post<TransferResponse>('/inventories/transfer', {
    indate, operator_id, details
  });
  return data;
}
```

---

### Task 8: React Auth Flow + Routing

**Files:**
- Create: `src/components/ProtectedRoute.tsx`
- Create: `src/pages/Login.tsx`
- Create: `src/pages/Dashboard.tsx`
- Modify: `src/App.tsx`
- Create: `src/main.tsx` (adjust if needed)

- [ ] **Step 1: Build ProtectedRoute**

`src/components/ProtectedRoute.tsx`:
```tsx
import { Navigate } from 'react-router-dom';
import { getToken } from '../api/auth';

export default function ProtectedRoute({ children }: { children: React.ReactNode }) {
  if (!getToken()) return <Navigate to="/login" replace />;
  return <>{children}</>;
}
```

- [ ] **Step 2: Build Login page**

`src/pages/Login.tsx`: Email + password form, calls `login()` on submit, redirects to `/dashboard` on success. Shows error message on 401.

- [ ] **Step 3: Build Dashboard page**

`src/pages/Dashboard.tsx`: Two large buttons "VAR" (links to `/var`) and "OUT" (links to `/out`). User name + logout button in header. Mobile-first layout.

- [ ] **Step 4: Wire up routing in App.tsx**

```tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import VAR from './pages/VAR';
import VARConfirm from './pages/VARConfirm';
import OUT from './pages/OUT';
import OUTConfirm from './pages/OUTConfirm';
import ProtectedRoute from './components/ProtectedRoute';

const queryClient = new QueryClient();

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
          <Route path="/var" element={<ProtectedRoute><VAR /></ProtectedRoute>} />
          <Route path="/var/confirm" element={<ProtectedRoute><VARConfirm /></ProtectedRoute>} />
          <Route path="/out" element={<ProtectedRoute><OUT /></ProtectedRoute>} />
          <Route path="/out/confirm" element={<ProtectedRoute><OUTConfirm /></ProtectedRoute>} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
```

---

### Task 9: Shared Form Components

**Files:**
- Create: `src/components/WarehouseSelect.tsx`
- Create: `src/components/LocationSelect.tsx`
- Create: `src/components/ItemRow.tsx`
- Create: `src/components/QrScanner.tsx`

- [ ] **Step 1: WarehouseSelect**

Fetches warehouse list on mount via `useQuery`, renders a `<select>`. Emits `onChange(warehouseId)`.

- [ ] **Step 2: LocationSelect**

Accepts `warehouseId` prop. Fetches locations when `warehouseId` changes via `useQuery`. Disabled when no warehouse selected. Cascading behavior using `enabled: !!warehouseId`.

- [ ] **Step 3: QrScanner**

Button that opens camera viewfinder using `@zxing/browser`. On successful scan, calls `lookupItem(text)` and emits `onScan(result)`. Falls back to manual input if camera unavailable.

- [ ] **Step 4: ItemRow**

Single table row: text input + QR scan button, qty input, delete button. On scan/text entry: calls `lookupItem` debounced, shows stock position selector. Emits `onChange` and `onDelete`.

---

### Task 10: VAR Form Page

**Files:**
- Create: `src/pages/VAR.tsx`
- Create: `src/pages/VARConfirm.tsx`

- [ ] **Step 1: Build VAR form page**

Layout (mobile-first, single column):
- Header: "VAR" + logout
- Date input (default today) + Notes textarea
- Source: WarehouseSelect + LocationSelect
- Destination: WarehouseSelect + LocationSelect
- Dynamic list of ItemRow components
- Submit button

Uses `react-hook-form` + `zod`. On submit: `POST /api/v1/inventories/transfer`, on success → `/var/confirm`.

- [ ] **Step 2: Build VAR confirmation page**

Shows success icon, movement IDs, "New VAR" button, "Dashboard" button.

---

### Task 11: OUT Form Page

**Files:**
- Create: `src/pages/OUT.tsx`
- Create: `src/pages/OUTConfirm.tsx`

- [ ] **Step 1: Build OUT form page**

Same pattern as VAR but simpler — single warehouse/location selector:
- Header: "OUT" + logout
- Date + Notes
- WarehouseSelect + LocationSelect
- Dynamic ItemRow list
- Submit button

On submit: `POST /api/v1/inventories/outbound`, navigate to `/out/confirm`.

- [ ] **Step 2: Build OUT confirmation page**

Same confirmation pattern as VAR.

---

### Task 12: Deploy Config

**Files:**
- Modify: `vite.config.ts` (set base path)
- Modify: Rails `config/deploy.rb` (add pedone build task)

- [ ] **Step 1: Configure Vite base path**

In `vite.config.ts`:
```typescript
export default defineConfig({
  base: '/pedone/',
  build: { outDir: 'dist' },
  // ... plugins, proxy ...
})
```

- [ ] **Step 2: Add Capistrano task**

In Rails `config/deploy.rb`:
```ruby
namespace :pedone do
  task :build do
    on roles(:web) do
      within release_path do
        execute :npm, 'run', 'build', '--prefix', release_path.join('pedone-frontend')
        execute :cp, '-r', release_path.join('pedone-frontend/dist'), release_path.join('public/pedone')
      end
    end
  end
end

after 'deploy:updated', 'pedone:build'
```
