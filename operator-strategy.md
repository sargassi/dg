# Operator Authorization Strategy

> Written: 2026-05-21
> Based on: codebase exploration of all models, migrations, controllers, views, fixtures, routes, and services

---

> **⚠️ UPDATE (2026-05-21): The `Operator` model and `operators` table are dead code.**
>
> After a full codebase audit (models, controllers, views, forms, API, tests, fixtures, rake tasks), the `operators` table and its scaffold CRUD are **not meaningfully used anywhere**. The `operator_id` columns on `itemins` and `itemouts` exist but are handled as raw integer text fields — no dropdown, no integration, no business logic. No API endpoints expose operators. No rake tasks reference them. The operators scaffold has no authentication gating.
>
> **Decision: The `operators` table can be dropped entirely. No data migration is needed.** The operator records are scaffold stubs (`MyString` names in both dev data and test fixtures). There is nothing worth migrating into the `users` table.
>
> This simplifies the strategy significantly:
> - **Section 4.5** becomes "Drop the operators table" instead of "merge operators into users"
> - **Section 7** removes operator data migration phases (Phase 5 eliminated)
> - **Section 8** adds a confirmation flag before the drop

---

## 1. Feasibility Assessment

**Verdict: Fully doable. No blockers.** The request described in `operator.md` is achievable within the existing app. However, there is significant architectural cleanup needed first — the app currently has **two separate, disconnected identity systems** that must be unified before any new authorization logic can be layered on top.

### No External Blockers

- SQLite supports the needed schema changes (new tables, columns, indexes, foreign keys)
- Devise already handles authentication; we are only adding authorization on top
- No authorization gem is installed, so there's nothing to rip out or conflict with
- The existing 2–3 users have no complex permissions to migrate

### Internal Challenges

The main challenge is **structural**: the app has been built with two parallel but disconnected concepts of "who someone is":

- **`User`** — the Devise-authenticated login (email/password), with a crude `role` string column, used only in 2 view files for dashboard rendering
- **`Operator`** — a plain model (name, lastname, integer role enum), used as a foreign key target for `itemins` and `itemouts`, but has no authentication at all

These two tables have zero relationship to each other. Unifying them is the prerequisite for any authorization work.

---

## 2. Current State of the Codebase

### 2.1 The Two Identity Systems

#### Users table (`db/schema.rb` line 428–447)

```
Column                  Type      Notes
─────────────────────────────────────────────────────────
email                   string    Devise login (unique index)
encrypted_password      string    Devise
reset_password_token    string    Devise :recoverable
sign_in_count           integer   Devise :trackable
failed_attempts         integer   Devise :lockable
unlock_token            string    Devise :lockable
role                    string    default "ufficio" — just a raw string!
```

- Migration: `db/migrate/20250902145143_add_role_to_user.rb` — single column, no enum, no validation
- Model: `app/models/user.rb` (7 lines) — only Devise modules + `has_many :api_tokens`
- **No** `has_many :tempestas` despite `tempesta.user_id` FK existing
- **No** name/lastname fields
- **No** enum or validation on `role`
- `role` is used exactly 3 places in views:
  - `app/views/dashboard/index.html.erb:3` — `if current_user.role == 'ufficio'`
  - `app/views/dashboard/home.html.erb:4` — `if current_user.role == 'ufficio'`
  - `app/views/dashboard/home.html.erb:68` — `elsif current_user.role == 'lab'`
- `current_user` is **not used in any controller** for authorization — only in those 3 view conditionals
- Test fixtures (`test/fixtures/users.yml`) are empty stubs: `one: {}`, `two: {}`

#### Operators table (`db/schema.rb` lines 250–256)

```
Column      Type      Notes
─────────────────────────────────────────────────────────
name        string    
lastname    string    
role        integer   enum: pedone(0), ufficio(1), laboratorio(2), spedizioni(3)
                      default 0, NOT NULL
```

- Migration: `db/migrate/20260319140620_create_operators.rb`
- Model: `app/models/operator.rb` — just an `enum role` definition, nothing else
- Used by: `app/models/itemin.rb` (`belongs_to :operator`) and `app/models/itemout.rb` (`belongs_to :operator`)
- Foreign keys: `itemins.operator_id → operators.id`, `itemouts.operator_id → operators.id`
- Has full scaffold CRUD at `app/controllers/operators_controller.rb` — no auth gating at all
- Views at `app/views/operators/` — form has a `<select>` for the role enum

### 2.2 Authorization: There Is None

This is the most critical finding:

- `ApplicationController` (`app/controllers/application_controller.rb:2`) has only `before_action :authenticate_user!` — that's it
- **Zero** controller-level role checks anywhere in the codebase
- **Zero** `before_action` that checks a user's role before allowing an action
- **No** authorization gem: CanCanCan, Pundit, and similar are not in the `Gemfile`
- Every authenticated user can access every controller action — create, edit, delete, everything
- The only "authorization" is visual: dashboard views show/hide links based on `current_user.role`

### 2.3 How `user_id` vs `operator_id` Are Used

```
tempesta.user_id    → FK to users    (set via form param, NOT auto-assigned to current_user)
itemins.operator_id → FK to operators
itemouts.operator_id → FK to operators
```

The `tempesta` model references `users` but there's **no `belongs_to :user`** in the model, no `has_many :tempestas` in User. The `user_id` on tempesta defaults to 2 in the database, which suggests it was always the same developer user.

### 2.4 Role String Values in Current Use

| Context | Role values used |
|---|---|
| `users.role` (string) | `"ufficio"`, `"lab"` (hardcoded in view conditionals) |
| `operators.role` (integer enum) | `pedone:0`, `ufficio:1`, `laboratorio:2`, `spedizioni:3` |

Note the mismatch: `users` has no `pedone`/`spedizioni`/`magazzino`; `operators` has no `lab` or `magazzino` string mapping.

### 2.5 Relevant Files Reference

| File | Line(s) | What it reveals |
|---|---|---|
| `app/models/user.rb` | 1–7 | No authorization logic, no role enum |
| `app/models/operator.rb` | 1–9 | Separate model with enum, no Devise |
| `app/controllers/application_controller.rb` | 2 | Only `authenticate_user!`, no role gate |
| `app/views/dashboard/index.html.erb` | 3,7 | Role-based view partials (ufficio vs lab) |
| `app/views/dashboard/home.html.erb` | 4,68 | Role-based view sections |
| `app/views/dashboard/atoms/_ufficio.html.erb` | 1–29 | Ufficio dashboard content |
| `app/views/dashboard/atoms/_lab.html.erb` | 1–29 | Lab dashboard content |
| `db/schema.rb` | 428–447 | Users table: `role` string, no name fields |
| `db/schema.rb` | 250–256 | Operators table: `role` integer enum |
| `db/schema.rb` | 199–213 | itemins/itemouts reference `operator_id` |
| `db/schema.rb` | 397–420 | tempesta references `user_id` |
| `db/migrate/20250902145143_add_role_to_user.rb` | 1–5 | Role added as string, default 'ufficio' |
| `db/migrate/20260319140620_create_operators.rb` | 1–10 | Operators table created separately |
| `config/routes.rb` | 63 | `devise_for :users` — single Devise scope |
| `config/initializers/devise.rb` | 1–313 | Standard Devise config, no custom scopes |
| `Gemfile` | 58 | `gem "devise"` — no authorization gem |

---

## 3. Recommended Strategy

### 3.1 The Core Decision: Single User Model

**Recommendation: Use a single `User` model with a `type` discriminator column — NOT STI, NOT separate models.**

#### Why not STI (Single Table Inheritance)?

STI (`type` column with Rails magic meaning) would create subclasses like `CompanyOperator < User`, `Customer < User`, `Supplier < User`. This is fragile:

- Devise routing is scope-based; having `devise_for :company_operators` and `devise_for :customers` creates separate login URLs and session scopes, which the user likely doesn't want
- The "godlike" role would need to span types, which STI makes awkward
- Multi-role support (ufficio + lab + magazzino) would require a join table regardless, making STI's type column duplicative
- The existing `type` column on ActionText already uses it for polymorphic rich text — adding another `type` column to users could cause conflicts

#### Why not separate models with polymorphic identity?

Separate models (`CompanyOperator`, `Customer`, `Supplier`) each `belongs_to :user` would mean:

- Every query needs a join to get the user
- Duplication of name/contact fields across tables
- More complex ability lookup (which table does the ability attach to?)

#### Why a single User model with a `user_type` column?

- **Simplicity**: one table for all identities, one Devise scope, one login URL
- **Flexibility**: any user can have any combination of roles and abilities
- **Query simplicity**: `User.where(user_type: :customer)` is clean
- **Matches user's intent**: "the idea if scaling is to use the User model for Customers, Suppliers, Operators"
- **Backward compatibility**: the existing 2–3 users just get `user_type: :company_operator` and keep working
- **Godlike is just a flag**: no separate class needed

### 3.2 The Design: Roles vs Abilities (Two Distinct Concepts)

The `operator.md` describes two different authorization layers that serve different purposes:

| Concept | What it means | Examples |
|---|---|---|
| **Departmental Roles** | What area of the business you belong to | `ufficio` (office), `lab` (laboratory), `magazzino` (warehouse) |
| **Abilities/Permissions** | What specific actions you can perform | `can_create_proformas`, `can_print_labels`, `can_manage_users` |

Roles determine **what you see** (dashboard content, navigation menus).  
Abilities determine **what you can do** (controller-level authorization gates).

A user can have **multiple roles** (e.g., works in both office and warehouse).  
A user has **specific abilities** granted by the godlike.

### 3.3 Data Flow (After Migration)

```
                                  ┌──────────────────────┐
                                  │   Ability Lookup     │
                                  │  (during request)    │
                                  └──────────┬───────────┘
                                             │
                   POST /login               │  checks: can?(:create_proforma)
User ──────────► Devise Auth ──────────► Current User
                                             │
                                  ┌──────────┴───────────┐
                                  │                      │
                           Controller Gate         View Rendering
                           (before_action)         (dashboard partials)
                           checks abilities        checks roles
```

Request flow:
1. User logs in via Devise → `current_user` is set
2. Controller `before_action` checks `current_user.can?(:some_ability)` — if denied, redirect/bounce
3. View renders appropriate dashboard partial based on `current_user.roles` (departments)
4. UI elements (buttons, links) may also be gated by abilities

---

## 4. Proposed Data Model

### 4.1 Changes to the `users` Table

Add these columns (all new — nothing removed or renamed initially):

```ruby
# Migration: AddIdentityFieldsToUsers
add_column :users, :name,      :string
add_column :users, :lastname,  :string
add_column :users, :user_type, :string, default: 'company_operator', null: false
add_column :users, :godlike,   :boolean, default: false, null: false
```

Remove the old single `role` column (or keep it temporarily and migrate data):

```ruby
# Migration: RemoveOldRoleFromUsers  (run AFTER data migration)
remove_column :users, :role, :string
```

**`user_type` values:** `company_operator`, `customer`, `supplier`

The `users` table after migration:

```
Column              Type      Notes
─────────────────────────────────────────────────────────────────
email               string    Devise login (unchanged)
encrypted_password  string    Devise (unchanged)
... (all Devise trackable/lockable columns unchanged)
name                string    NEW
lastname            string    NEW
user_type           string    NEW — enum-like, validated
godlike             boolean   NEW — only true for the godlike user(s)
created_at          datetime  (existing)
updated_at          datetime  (existing)
```

### 4.2 New Table: `abilities`

Stores the canonical list of what permissions exist in the system:

```ruby
# Migration: CreateAbilities
create_table :abilities do |t|
  t.string  :name,        null: false   # e.g., "create_proformas"
  t.string  :description                # e.g., "Can create new production orders"
  t.string  :category                   # e.g., "production", "labels", "admin"
  t.timestamps
end
add_index :abilities, :name, unique: true
```

**Seed data** (initial set of abilities based on existing controllers):

| name | description | category |
|---|---|---|
| `manage_proformas` | Create/edit/delete production orders | production |
| `view_production` | View production dashboard and research | production |
| `checkpoint_scan` | Scan QR codes at production checkpoints | production |
| `print_labels_proforma` | Print proforma labels (etichette) | labels |
| `print_labels_lab` | Print laboratory labels (etichette_lab) | labels |
| `print_labels_camp` | Print campaign labels (etichette_camp) | labels |
| `print_labels_gen` | Print generic labels (etichette_gen) | labels |
| `manage_items` | Create/edit/delete items | warehouse |
| `manage_warehouse` | Manage warehouse/locations | warehouse |
| `manage_inventory` | Inventory movements (itemins/itemouts) | warehouse |
| `import_data` | Import CSV/XLS data | data |
| `manage_users` | Manage users and assign abilities | admin |
| `manage_events` | Create/edit events | admin |
| `view_reports` | View production/warehouse reports | reports |

### 4.3 New Table: `user_abilities` (Join Table)

Stores which user has which ability, and tracks who granted it:

```ruby
# Migration: CreateUserAbilities
create_table :user_abilities do |t|
  t.references :user,          null: false, foreign_key: true
  t.references :ability,       null: false, foreign_key: true
  t.references :granted_by,    null: false, foreign_key: { to_table: :users }
  t.timestamps
end
add_index :user_abilities, [:user_id, :ability_id], unique: true
```

### 4.4 New Table: `user_roles` (Join Table for Multi-Role Support)

Since an operator can have multiple departmental roles (ufficio, lab, magazzino):

```ruby
# Migration: CreateUserRoles
create_table :user_roles do |t|
  t.references :user,    null: false, foreign_key: true
  t.string     :role,    null: false   # "ufficio", "lab", "magazzino"
  t.timestamps
end
add_index :user_roles, [:user_id, :role], unique: true
```

Role values (consistent with the requested Italian department names):

| Value | Department |
|---|---|
| `ufficio` | Office / Administration |
| `lab` | Laboratory |
| `magazzino` | Warehouse |

### 4.5 Dropping the `operators` Table

After a full codebase audit, the `operators` table is confirmed dead code. It can be dropped **directly** — no data migration needed.

**Evidence from the audit:**

| Check | Finding |
|---|---|
| Operator model | 9-line stub: enum only, no business logic |
| Operators controller | Scaffold CRUD, no auth gating, no callbacks |
| Itemins/itemouts `operator_id` | Raw text field in forms (not even a dropdown), displayed as integer |
| API (Grape) | Zero references to operators |
| Rake tasks | Zero references to operators |
| Test fixtures | Stubs: `name: MyString, lastname: MyString, role: 1` |
| `_list.html.erb` partial | Hardcoded `operator_path` — but this partial is only used on the operators index page itself |
| Inventories | Does NOT reference `operator_id` — no cascade concerns |

**Plan:**

#### Step 1: Remove the scaffold artifacts

Delete these files:
```
app/models/operator.rb
app/controllers/operators_controller.rb
app/views/operators/          (entire directory: 6 files)
app/helpers/operators_helper.rb
app/serializers/operator_serializer.rb
test/models/operator_test.rb
test/controllers/operators_controller_test.rb
test/system/operators_test.rb
test/fixtures/operators.yml
db/migrate/20260319140620_create_operators.rb
```

Remove from `config/routes.rb`:
```ruby
resources :operators   # line 20
```

#### Step 2: Drop `operator_id` from `itemins` and `itemouts`

```ruby
# Migration: RemoveOperatorIdFromIteminsAndItemouts
remove_reference :itemins,  :operator, foreign_key: true
remove_reference :itemouts, :operator, foreign_key: true
```

#### Step 3: Clean up itemins/itemouts models and controllers

Remove from models:
```ruby
# app/models/itemin.rb  — remove: belongs_to :operator
# app/models/itemout.rb — remove: belongs_to :operator
```

Remove from controllers (strong params):
```ruby
# app/controllers/itemins_controller.rb  — remove :operator_id from permit
# app/controllers/itemouts_controller.rb — remove :operator_id from permit
```

Remove from serializers:
```ruby
# app/serializers/itemin_serializer.rb  — remove: has_one :operator
# app/serializers/itemout_serializer.rb — remove: has_one :operator
```

Remove from views:
```ruby
# Remove operator_id fields from:
#   app/views/itemins/_form.html.erb
#   app/views/itemins/_itemin.html.erb
#   app/views/itemouts/_form.html.erb
#   app/views/itemouts/_itemout.html.erb
```

Remove from test fixtures:
```yaml
# test/fixtures/itemins.yml  — remove: operator: one / operator: two
# test/fixtures/itemouts.yml — remove: operator: one / operator: two
```

Update test controllers (remove `operator_id` from params).

#### Step 4: Optionally add `user_id` to `itemins` and `itemouts` (future)

If a user context is needed for inventory movements later, add:
```ruby
add_reference :itemins,  :user, foreign_key: true   # optional: true
add_reference :itemouts, :user, foreign_key: true   # optional: true
```

This is **not required** for the initial cleanup — only if a business rule later needs to track who performed an inventory movement.

#### Step 5: Drop the `operators` table

```ruby
# Migration: DropOperators
drop_table :operators
```

### 4.6 Updated Model Associations

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :lockable, :trackable

  # Existing
  has_many :api_tokens

  # NEW
  has_many :user_roles,    dependent: :destroy
  has_many :user_abilities, dependent: :destroy
  has_many :abilities,     through: :user_abilities
  has_many :itemins
  has_many :itemouts
  has_many :tempestas

  validates :user_type, inclusion: { in: %w[company_operator customer supplier] }
  validates :name, :lastname, presence: true, if: :company_operator?

  def company_operator?
    user_type == 'company_operator'
  end

  def godlike?
    godlike
  end

  def roles
    user_roles.pluck(:role)
  end

  def has_role?(role_name)
    roles.include?(role_name.to_s)
  end

  def can?(ability_name)
    godlike? || abilities.exists?(name: ability_name)
  end

  def grant_ability(ability, granted_by:)
    user_abilities.find_or_create_by!(ability: ability, granted_by: granted_by)
  end

  def revoke_ability(ability)
    user_abilities.find_by(ability: ability)&.destroy
  end
end
```

---

## 5. Authorization Approach

### 5.1 How Abilities Are Checked

**Strategy: Lightweight service object + controller `before_action` gates. No gem required initially.**

The `User#can?` method (above) is the single entry point. Controllers use it directly:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  private

  def require_ability!(ability_name)
    unless current_user.can?(ability_name)
      redirect_to root_path, alert: "Non hai i permessi per questa azione."
    end
  end

  def require_godlike!
    unless current_user.godlike?
      redirect_to root_path, alert: "Solo l'amministratore può accedere."
    end
  end
end
```

Then in each controller:

```ruby
class Production::ProformasController < ApplicationController
  before_action -> { require_ability!(:manage_proformas) }, except: [:index, :show]
  before_action -> { require_ability!(:view_production) },  only:   [:index, :show]
  # ...
end
```

### 5.2 Why Not Use a Gem?

The requirements are simple enough that a gem adds more complexity than it removes:

- **CanCanCan** — requires an `Ability` class that maps roles to permissions, but our permissions are database-driven (ad-hoc), which CanCanCan handles poorly
- **Pundit** — policy-per-model is overkill when we just need "can user X do action Y?" lookups against a join table
- **A 30-line service + a method on User** is sufficient for now

If the system grows to need resource-level authorization (e.g., "user can only edit proformas they created"), then Pundit becomes a good choice. At that point, Pundit policies can call `current_user.can?(:some_ability)` internally.

### 5.3 Ability Precedence

```
godlike? → true (bypasses all ability checks)
   ↓
can?(:ability_name) → checks user_abilities join table
```

The godlike flag is a master override. This is intentional and explicit — it means the godlike can do anything without needing ability records.

### 5.4 View-Level Authorization

Dashboard rendering should check **roles** (departments), not abilities:

```erb
<%# app/views/dashboard/index.html.erb %>
<% if current_user.has_role?(:ufficio) %>
  <%= render 'dashboard/atoms/ufficio' %>
<% end %>
<% if current_user.has_role?(:lab) %>
  <%= render 'dashboard/atoms/lab' %>
<% end %>
<% if current_user.has_role?(:magazzino) %>
  <%= render 'dashboard/atoms/magazzino' %>
<% end %>
```

Individual UI actions (buttons, links) should be gated by abilities:

```erb
<% if current_user.can?(:create_proformas) %>
  <%= link_to "Nuova Proforma", new_production_proforma_path %>
<% end %>
```

---

## 6. Dashboard Design (Godlike Panel)

### 6.1 What the Godlike Dashboard Contains

The godlike needs a dedicated section to manage users and their abilities. This would be a new page at `/admin/users` or integrated into the existing dashboard.

**Page layout:**

```
┌─────────────────────────────────────────────────────────┐
│  Admin Panel                                    [godlike]│
├──────────────┬──────────────────────────────────────────┤
│ Users        │                                          │
│ ──────────── │  Selected User: Maria Rossi              │
│ ○ Maria R.   │  Type: Company Operator                  │
│ ○ Luca B.    │                                          │
│ ○ Anna S.    │  Departmental Roles:                     │
│ ○ Marco T.   │  ☑ Ufficio   ☑ Lab   ☐ Magazzino       │
│              │                                          │
│ + New User   │  Abilities:                              │
│              │  ☑ manage_proformas                      │
│              │  ☑ view_production                       │
│              │  ☑ checkpoint_scan                       │
│              │  ☑ print_labels_proforma                 │
│              │  ☑ print_labels_lab                      │
│              │  ☐ print_labels_camp                     │
│              │  ☐ print_labels_gen                      │
│              │  ☐ manage_items                          │
│              │  ☐ manage_warehouse                      │
│              │  ☐ manage_inventory                      │
│              │  ☐ import_data                           │
│              │  ☐ manage_users                          │
│              │  ☐ manage_events                         │
│              │  ☐ view_reports                          │
│              │                                          │
│              │  [Save Changes]  [Delete User]           │
└──────────────┴──────────────────────────────────────────┘
```

### 6.2 Routes

```ruby
# config/routes.rb
namespace :admin do
  resources :users, only: [:index, :edit, :update, :destroy] do
    member do
      patch :toggle_ability   # assign/remove a single ability
      patch :toggle_role      # assign/remove a single role
    end
  end
end
```

### 6.3 Controller

```ruby
# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  before_action :require_godlike!

  def index
    @users = User.where(user_type: :company_operator).includes(:user_roles, :abilities)
  end

  def edit
    @user = User.find(params[:id])
    @all_abilities = Ability.order(:category, :name)
  end

  def update
    @user = User.find(params[:id])
    # Mass-update roles and abilities from form params
    # ...
  end

  def toggle_ability
    @user = User.find(params[:id])
    ability = Ability.find_by!(name: params[:ability_name])
    if @user.can?(params[:ability_name])
      @user.revoke_ability(ability)
    else
      @user.grant_ability(ability, granted_by: current_user)
    end
    redirect_to edit_admin_user_path(@user)
  end
end
```

### 6.4 Who Is Godlike?

The first godlike user should be set manually (via Rails console or a seed). The godlike can then designate additional godlike users through the admin panel. This avoids the "who watches the watchers" bootstrap problem.

```ruby
# db/seeds.rb
godlike = User.find_or_initialize_by(email: 'admin@example.com')
godlike.assign_attributes(
  name: 'Admin',
  lastname: 'System',
  user_type: 'company_operator',
  godlike: true,
  password: 'changeme123',
  password_confirmation: 'changeme123'
)
godlike.save!
```

---

## 7. Migration Plan (Step by Step)

The migration must be done in order, with data migrations between schema migrations:

```
Phase 1: Add columns to users
  Migration 1: AddIdentityFieldsToUsers
    → add name, lastname, user_type, godlike to users

Phase 2: Create new tables
  Migration 2: CreateAbilities
  Migration 3: CreateUserRoles
  Migration 4: CreateUserAbilities

Phase 3: Seed abilities and migrate existing data
  Rake task: migrate_existing_users
    → Set user_type for existing users
    → Create user_roles from old users.role string
    → Grant all abilities to existing users (or a safe subset)
    → Set one user as godlike (manually chosen)

Phase 4: Add user_id to itemins/itemouts (optional — only if tracking is needed)
  Migration 5: AddUserIdToIteminsAndItemouts

Phase 5: Drop the dead operators table and clean up
  → Delete scaffold files (model, controller, views, serializer, helper, tests, fixtures)
  → Remove `resources :operators` from routes.rb
  → Migration 6: RemoveOperatorIdFromIteminsAndItemouts
  → Remove `belongs_to :operator` from Itemin and Itemout models
  → Remove `:operator_id` from itemins/itemouts strong params
  → Remove `has_one :operator` from itemin/itemout serializers
  → Clean up operator_id references in itemins/itemouts views and test fixtures
  → Migration 7: DropOperators

Phase 6: Update models and controllers
  → Add associations to User, Itemin, Itemout
  → Add ability checks to all controllers

Phase 7: Final cleanup
  Migration 8: RemoveRoleFromUsers (the old string column)
```

---

## 8. Open Questions for the User

Before implementing, these need clarification:

### 8.1 User Type Scope

1. **Can Customers and Suppliers log in?** The `operator.md` says "use the User model for Customers, Suppliers, Operators." Does this mean:
   - Customers/Suppliers have their own login access (view-only to their orders)?
   - Or are they just data records (no login), and only company operators log in?
   
2. **Should `:registerable` stay enabled?** Currently Devise allows self-registration. Should this be:
   - Disabled entirely (only godlike creates users)?
   - Enabled but moderated (requires approval)?
   - Enabled for customers/suppliers but not for company operators?

### 8.2 Existing Users Migration

3. **Who are the existing 2–3 users?** Are they all "company operators"? Should one be designated as the initial godlike? What emails do they use?
4. **Are there real records in the `operators` table worth keeping?** The codebase audit found only scaffold stubs (`MyString` names). If by some chance production data exists, confirm before the drop migration runs.

### 8.3 Role Semantics

5. **"magazzino" role** — mentioned in `operator.md` but not in any current code. Is this a new department that needs a new dashboard partial? What should it contain?
6. **Role visibility** — when a user has multiple roles (e.g., ufficio + lab), should they see a combined dashboard or a toggle between views?
7. **"pedone" and "spedizioni"** — these exist in the Operator enum but not in the user's `operator.md` vision. Are they being kept or dropped?

### 8.4 Ability Granularity

8. **Is the proposed ability list (Section 4.2) correct?** Are there abilities I missed? Are any too granular or not granular enough?
9. **Should abilities be grouped by category for the admin UI** (as proposed), or displayed as a flat checklist?
10. **Can the godlike create NEW abilities** through the UI, or is the ability list fixed and only assignable?

### 8.5 Implementation Priorities

11. **What is the highest priority?** Options:
    - First: unify User/Operator models and clean up the schema
    - First: add ability checks to all existing controllers (close the open door)
    - First: build the godlike dashboard

### 8.6 Operators Table — Confirmation Required

12. **Can the `operators` table and all related code be dropped?** The codebase audit confirms operators are dead code (see Section 4.5 for full evidence):
    - The operator records in the database are scaffold stubs — confirm there's nothing worth keeping
    - The itemins/itemouts `operator_id` columns have no dropdown or meaningful integration — confirm these can be dropped (or repurposed to `user_id` if movement tracking is needed later)
    - The `_list.html.erb` partial hardcodes `operator_path` — this partial is only used on the operators index page itself, so it can be deleted or generalized
    - **One-time confirmation needed before proceeding**

---

## 9. Summary

| Aspect | Recommendation |
|---|---|
| **Identity model** | Single `User` model with `user_type` column (not STI) |
| **Department roles** | `user_roles` join table (ufficio, lab, magazzino) |
| **Abilities** | `abilities` + `user_abilities` join table, database-driven |
| **Godlike** | Boolean flag on User, master override for all abilities |
| **Authorization** | Service-object-free approach: `User#can?` + controller `before_action` |
| **Operators table** | Dead code — drop directly, no data migration needed |
| **Authorization gem** | Not needed yet; Pundit can be added later if resource-level auth is needed |
| **Dashboard** | New `Admin::UsersController` under `/admin/users`, gated by `require_godlike!` |
