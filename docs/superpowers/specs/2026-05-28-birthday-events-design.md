# Birthday Events & Event Toggle

## Schema Changes

### Migration 1: Add `user_id` to events
- Column: `user_id` (bigint, nullable, FK → users)
- No null constraint (events can exist without a user)

### Migration 2: Add `enabled` to events
- Column: `enabled` (boolean, default: true, not null)

## Models

### Event
```ruby
belongs_to :user, optional: true
scope :enabled, -> { where(enabled: true) }
```

### User
```ruby
has_many :events, dependent: :nullify
```
(`dependent: :nullify` — deleting a user does not delete events, just disassociates them)

## Seeds
- Add a `Compleanno` eventype: `name: "Compleanno"`, `color: "#EC4899"`, `enabled: true`

## Calendar Queries

In `Directory::EventsController#index`:
- All `Event.where(...)` queries must be chained with `.enabled` to exclude disabled events
- This applies to both the non-yearly and yearly queries

## Birthday Sync Logic

### When to run
In both `Admin::UsersController` and `DirectoryController`, after successful create/update.

### On create (date_of_birth present)
- Create event: `name = "Compleanno #{user.name} #{user.lastname}"`, `eventype = Compleanno`, `start_time = date_of_birth`, `end_time = date_of_birth`, `recurrent = yearly`, `user_id = user.id`, `enabled = true`

### On update (date_of_birth changed)
- If `date_of_birth` present:
  - Find event by `user_id` (where eventype = Compleanno)
  - If found: update `start_time` and `end_time`
  - If not found: create as above
- If `date_of_birth` cleared (nil):
  - Find and destroy the linked birthday event

### No callbacks on User model
- This logic stays in controllers to avoid side effects in non-user-facing contexts
- Extract to a private method or service object to avoid duplication between the two controllers

## Toggle UI

### Route
```ruby
resources :events do
  member { patch :toggle_enabled }
end
```

### Controller action
```ruby
def toggle_enabled
  @event = Event.find(params[:id])
  @event.update(enabled: !@event.enabled)
  redirect_to directory_events_path(...)
end
```

### View changes (index.html.erb)
- Each event in the sidebar day detail list gets a toggle button
- Click sends `PATCH /directory/events/:id/toggle_enabled` via Turbo
- Use a Stimulus controller or a simple `button_to` with `data: { turbo_frame: "calendar" }`
- The toggle button shows a visual state: `enabled` (filled icon/badge) vs `disabled` (muted/strikethrough)
- Events in the calendar grid (day cells) are already excluded by the `.enabled` scope, no change needed there

## Files Modified

- `db/migrate/20260528183000_add_user_id_to_events.rb` (new)
- `db/migrate/20260528183100_add_enabled_to_events.rb` (new)
- `db/seeds.rb` (add Compleanno eventype)
- `app/models/event.rb` (add belongs_to :user, scope :enabled)
- `app/models/user.rb` (add has_many :events)
- `app/controllers/directory/events_controller.rb` (add .enabled scope, toggle_enabled action)
- `app/controllers/admin/users_controller.rb` (birthday sync)
- `app/controllers/directory_controller.rb` (birthday sync)
- `config/routes.rb` (add toggle_enabled route)
- `app/views/directory/events/index.html.erb` (toggle UI)
- `app/views/directory/events/_event_detail.html.erb` (toggle in sidebar items)
