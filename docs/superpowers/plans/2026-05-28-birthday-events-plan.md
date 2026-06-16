# Birthday Events & Event Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-create yearly-recurring Compleanno events from user `date_of_birth`, add `enabled` toggle to events, and add toggle UI to calendar.

**Architecture:** Two migrations add `user_id` and `enabled` to events. Controller-level sync logic creates/updates/destroys birthday events on user create/update. Calendar queries filter by `.enabled`. A `toggle_enabled` member action and sidebar toggle UI allow disabling events.

**Tech Stack:** Rails 7.0, SQLite, Turbo, Tailwind

---

### Task 0: Add `user_id` and `enabled` migrations

**Files:**
- Create: `db/migrate/20260528183000_add_user_id_to_events.rb`
- Create: `db/migrate/20260528183100_add_enabled_to_events.rb`

- [ ] **Step 1: Create user_id migration**

```ruby
class AddUserIdToEvents < ActiveRecord::Migration[7.0]
  def change
    add_reference :events, :user, foreign_key: true, null: true
  end
end
```

- [ ] **Step 2: Create enabled migration**

```ruby
class AddEnabledToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :enabled, :boolean, default: true, null: false
  end
end
```

- [ ] **Step 3: Run migrations**

Run: `bin/rails db:migrate`
Expected: both migrations succeed

- [ ] **Step 4: Commit**

```bash
git add db/migrate/20260528183000_add_user_id_to_events.rb db/migrate/20260528183100_add_enabled_to_events.rb
git commit -m "feat: add user_id and enabled columns to events"
```

---

### Task 1: Add associations and scope to models

**Files:**
- Modify: `app/models/event.rb`
- Modify: `app/models/user.rb`

- [ ] **Step 1: Update Event model**

```ruby
class Event < ApplicationRecord
  belongs_to :eventype
  belongs_to :user, optional: true

  validates :name, :start_time, presence: true
  validate :end_time_after_start_time

  enum :recurrent, { none: "none", daily: "daily", weekly: "weekly", monthly: "monthly", yearly: "yearly" }, default: "none", prefix: true

  scope :enabled, -> { where(enabled: true) }

  private

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, "must be after or equal to start time") if end_time < start_time
  end

  public

  def display_color
    eventype&.color || "#3B82F6"
  end
end
```

- [ ] **Step 2: Update User model**

```ruby
class User < ApplicationRecord
  has_many :api_tokens
  has_many :user_roles,    dependent: :destroy
  has_many :user_abilities, dependent: :destroy
  has_many :abilities,     through: :user_abilities
  has_many :itemins
  has_many :itemouts
  has_many :tempestas
  has_many :events, dependent: :nullify
  ...
end
```

- [ ] **Step 3: Commit**

```bash
git add app/models/event.rb app/models/user.rb
git commit -m "feat: add user association to Event and has_many to User"
```

---

### Task 2: Add Compleanno eventype to seeds

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 1: Add eventype seeding at end of seeds.rb**

Add at the bottom of `db/seeds.rb`:

```ruby
# ── Eventypes ─────────────────────────────────────────────────────────
%w[Compleanno].each do |name|
  Eventype.find_or_create_by!(name: name) do |e|
    e.enabled = true
    e.color = "#EC4899"
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: add Compleanno eventype to seeds"
```

---

### Task 3: Add `toggle_enabled` route and `enabled` scope to calendar queries

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/directory/events_controller.rb`

- [ ] **Step 1: Update routes to add toggle_enabled member**

Change line 69 from:
```ruby
    resources :events
```
to:
```ruby
    resources :events do
      member do
        patch :toggle_enabled
      end
    end
```

- [ ] **Step 2: Add `.enabled` to calendar queries and add `toggle_enabled` action**

Replace the index action and add the new action:

```ruby
class Directory::EventsController < ApplicationController
  before_action -> { require_ability!('manage_events_calendar') }
  before_action :set_event, only: %i[ show edit update destroy toggle_enabled ]

  def index
    @date = safe_date(:start_date)
    @todate = safe_date(:selected_date, @date)
    month_start = @date.beginning_of_month
    month_end = @date.end_of_month
    year = @date.year

    non_yearly = Event.recurrents.except(:yearly).values + [nil]
    base = Event.enabled.where(recurrent: non_yearly)
    @events = base.where(start_time: month_start..month_end)
                  .or(base.where(end_time: month_start..month_end))
                  .or(base.where("start_time < ? AND end_time > ?", month_start, month_end))
                  .includes(:eventype)
                  .to_a

    Event.enabled.where(recurrent: :yearly).includes(:eventype).find_each do |event|
      projected_start = Date.new(year, event.start_time.month, event.start_time.day)
      projected_end = event.end_time ? Date.new(year, event.end_time.month, event.end_time.day) : projected_start
      projected_end = projected_end.next_year if projected_end < projected_start

      if projected_start <= month_end && projected_end >= month_start
        event.start_time = projected_start
        event.end_time = projected_end
        @events << event
      end
    end

    @day_events = @events.select { |e| (e.start_time..e.end_time).cover?(@todate) }
    @end_of_week = @todate.end_of_week(:sunday)
    @week_events = @events.select { |e| e.start_time <= @end_of_week && e.end_time >= @todate + 1 }
  end

  # ... (show, new, create, edit, update, destroy unchanged) ...

  def toggle_enabled
    @event.update(enabled: !@event.enabled)
    redirect_to directory_events_path(start_date: params[:start_date] || @event.start_time, selected_date: params[:selected_date] || Date.today)
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  # ... rest unchanged ...
end
```

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb app/controllers/directory/events_controller.rb
git commit -m "feat: add toggle_enabled route and filter calendar by enabled events"
```

---

### Task 4: Add toggle UI to calendar sidebar

**Files:**
- Modify: `app/views/directory/events/index.html.erb`

- [ ] **Step 1: Add toggle button to each event in the sidebar day detail**

Replace lines 82-94 (the sidebar day events loop) to add a toggle button:

```erb
            <% @day_events.each do |event| %>
              <div class="flex items-center gap-2 px-3 py-2 border-b border-slate-100 hover:bg-slate-50 transition rounded-sm group">
                <%= link_to edit_directory_event_path(event, start_date: @date, selected_date: @todate),
                      class: "flex flex-col grow min-w-0",
                      data: { turbo_frame: "event_modal" } do %>
                  <div class="flex items-center gap-3">
                    <div class="w-3 h-3 rounded-full flex-shrink-0" style="background: <%= event.display_color %>"></div>
                    <span class="text-sm text-slate-900"><%= event.name %></span>
                    <span class="text-xxs text-slate-500 ml-auto uppercase"><%= event.eventype&.name %></span>
                  </div>
                  <% if event.description.present? %>
                    <span class="text-xs text-slate-500 mt-0.5 ml-6 line-clamp-1"><%= event.description %></span>
                  <% end %>
                <% end %>
                <%= button_to toggle_enabled_directory_event_path(event, start_date: @date, selected_date: @todate),
                      method: :patch,
                      class: "flex-shrink-0 p-1 rounded hover:bg-slate-200 transition opacity-0 group-hover:opacity-100",
                      data: { turbo_frame: "calendar" },
                      title: event.enabled? ? "Disabilita" : "Abilita" do %>
                  <% if event.enabled? %>
                    <span class="material-symbols-outlined text-base text-slate-400">visibility</span>
                  <% else %>
                    <span class="material-symbols-outlined text-base text-slate-300">visibility_off</span>
                  <% end %>
                <% end %>
              </div>
            <% end %>
```

- [ ] **Step 2: Also add toggle to upcoming days section (lines 114-121)**

Replace the upcoming events loop similarly:

```erb
                    <% events_for_day.each do |event| %>
                      <div class="flex items-center gap-1.5 px-1.5 py-0.5 hover:bg-slate-50 transition rounded-sm group">
                        <%= link_to edit_directory_event_path(event, start_date: @date, selected_date: @todate),
                              class: "flex items-center gap-1.5 grow min-w-0",
                              data: { turbo_frame: "event_modal" } do %>
                          <div class="w-1.5 h-1.5 rounded-full flex-shrink-0" style="background: <%= event.display_color %>"></div>
                          <span class="text-[11px] text-slate-500 truncate"><%= event.name %></span>
                        <% end %>
                        <%= button_to toggle_enabled_directory_event_path(event, start_date: @date, selected_date: @todate),
                              method: :patch,
                              class: "flex-shrink-0 opacity-0 group-hover:opacity-100 transition",
                              data: { turbo_frame: "calendar" },
                              title: event.enabled? ? "Disabilita" : "Abilita" do %>
                          <% if event.enabled? %>
                            <span class="material-symbols-outlined text-sm text-slate-400">visibility</span>
                          <% else %>
                            <span class="material-symbols-outlined text-sm text-slate-300">visibility_off</span>
                          <% end %>
                        <% end %>
                      </div>
                    <% end %>
```

- [ ] **Step 3: Commit**

```bash
git add app/views/directory/events/index.html.erb
git commit -m "feat: add toggle visibility button to calendar event items"
```

---

### Task 5: Add birthday sync to Admin::UsersController

**Files:**
- Modify: `app/controllers/admin/users_controller.rb`

- [ ] **Step 1: Add birthday sync call after successful create**

After `@user.save` in the `create` action (line 18), add:

```ruby
    if @user.save
      sync_birthday_event(@user)
      redirect_to admin_users_path, notice: "Utente creato."
    else
```

- [ ] **Step 2: Add birthday sync call after successful update**

After `if @user.update(attrs)` (before the roles/abilities logic), add:

```ruby
      if @user.update(attrs)
        sync_birthday_event(@user)
        if params[:roles].present?
```

- [ ] **Step 3: Add the private method**

In the private section, add:

```ruby
    def sync_birthday_event(user)
      compleanno = Eventype.find_by(name: "Compleanno")
      return unless compleanno && user.date_of_birth.present?

      existing = user.events.find_by(eventype: compleanno)
      if existing
        existing.update!(
          name: "Compleanno #{user.name} #{user.lastname}",
          start_time: user.date_of_birth,
          end_time: user.date_of_birth,
          enabled: true
        )
      else
        user.events.create!(
          name: "Compleanno #{user.name} #{user.lastname}",
          eventype: compleanno,
          start_time: user.date_of_birth,
          end_time: user.date_of_birth,
          recurrent: :yearly,
          enabled: true
        )
      end
    rescue => e
      Rails.logger.warn "Failed to sync birthday event for user #{user.id}: #{e.message}"
    end
```

- [ ] **Step 4: Handle date_of_birth cleared (destroy event)**

In the update action, before the `if @user.update(attrs)`, add logic to handle dob clearing:

Actually, integrate into sync_birthday_event:

```ruby
    def sync_birthday_event(user)
      compleanno = Eventype.find_by(name: "Compleanno")
      return unless compleanno

      if user.date_of_birth.present?
        existing = user.events.find_by(eventype: compleanno)
        if existing
          existing.update!(
            name: "Compleanno #{user.name} #{user.lastname}",
            start_time: user.date_of_birth,
            end_time: user.date_of_birth,
            enabled: true
          )
        else
          user.events.create!(
            name: "Compleanno #{user.name} #{user.lastname}",
            eventype: compleanno,
            start_time: user.date_of_birth,
            end_time: user.date_of_birth,
            recurrent: :yearly,
            enabled: true
          )
        end
      else
        user.events.where(eventype: compleanno).destroy_all
      end
    rescue => e
      Rails.logger.warn "Failed to sync birthday event for user #{user.id}: #{e.message}"
    end
```

- [ ] **Step 5: Run the events controller tests to verify nothing is broken**

Run: `bin/rails test test/controllers/events_controller_test.rb`
Expected: same results as before (pre-existing test DB errors are fine)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/users_controller.rb
git commit -m "feat: sync birthday event on user create/update in admin"
```

---

### Task 6: Add birthday sync to DirectoryController

**Files:**
- Modify: `app/controllers/directory_controller.rb`

- [ ] **Step 1: Add birthday sync call after successful update**

After `if @user.update(attrs)` (line 40), add:

```ruby
      if @user.update(attrs)
        sync_birthday_event(@user)
        if params[:roles].present?
```

- [ ] **Step 2: Add the same private method**

In the private section, add the same `sync_birthday_event` method:

```ruby
    def sync_birthday_event(user)
      compleanno = Eventype.find_by(name: "Compleanno")
      return unless compleanno

      if user.date_of_birth.present?
        existing = user.events.find_by(eventype: compleanno)
        if existing
          existing.update!(
            name: "Compleanno #{user.name} #{user.lastname}",
            start_time: user.date_of_birth,
            end_time: user.date_of_birth,
            enabled: true
          )
        else
          user.events.create!(
            name: "Compleanno #{user.name} #{user.lastname}",
            eventype: compleanno,
            start_time: user.date_of_birth,
            end_time: user.date_of_birth,
            recurrent: :yearly,
            enabled: true
          )
        end
      else
        user.events.where(eventype: compleanno).destroy_all
      end
    rescue => e
      Rails.logger.warn "Failed to sync birthday event for user #{user.id}: #{e.message}"
    end
```

- [ ] **Step 3: Run the directory controller tests**

Run: `bin/rails test test/controllers/`
Expected: same results as before

- [ ] **Step 4: Commit**

```bash
git add app/controllers/directory_controller.rb
git commit -m "feat: sync birthday event on user update in directory"
```
