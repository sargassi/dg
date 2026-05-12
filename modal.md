# Modal Close Flow - Implementation Plan

## Overview

This document describes the implementation of a modal close flow that:
1. Reloads only the search results (not full page)
2. Scrolls to the original row position
3. Shows a visual blue border on the row when closing modal

---

## Current Implementation Status

### Working Components

1. **Row IDs in search table** - Added `id="prow-<%= row.id %>"` to each `<tr>` in `_search_rows.html.erb`

2. **Anchor parameter in link** - Added `:row_anchor => "prow-#{row.id}"` to prow links in `_search_rows.html.erb`

3. **Close button with anchor** - Changed close link in `_actions.html.erb` to use `/production/research#prow-{id}` with `data-turbo-frame="rez"`

4. **JavaScript in application layout** - Added global script in `application.html.erb` to highlight row on modal close using regex on `location.href`

5. **CSS for highlight** - Added `.row-highlight` animation in `application.tailwind.css`

### Files Modified

| File | Changes |
|------|---------|
| `app/assets/stylesheets/application.tailwind.css` | Added `@keyframes row-highlight` and `.row-highlight` class |
| `app/views/atoms/_search_rows.html.erb` | Added `id="prow-<%= row.id %>"` to `<tr>`, added `:row_anchor` to link |
| `app/views/atoms/_actions.html.erb` | Changed close to use anchor + `data-turbo-frame="rez"` |
| `app/views/layouts/application.html.erb` | Added global JavaScript for row highlighting |

---

## How It Works (Flow)

| Step | What Happens |
|------|--------------|
| 1 | User clicks row #123 in search results |
| 2 | Link opens modal: `/prows/1?proforma=1&src=searchplain&row_anchor=prow-123` |
| 3 | Modal shows prow details with tempesta checkboxes |
| 4 | User works in modal (checks tempestas, etc.) |
| 5 | User clicks X to close modal |
| 6 | Goes to `/production/research#prow-123` |
| 7 | Turbo only reloads `rez` frame (not full page) |
| 8 | Browser auto-scrolls to `#prow-123` element |
| 9 | JavaScript runs and highlights row with blue border for 2 seconds |

---

## Current Issue

The JavaScript highlighting is not working - the regex `location.href.match(/#prow-\d+/)` returns `null` because Turbo's navigation may not preserve the hash in the URL properly, or the timing of when the script runs vs when the frame loads is off.

### Next Steps to Fix

1. Use `sessionStorage` to store the anchor when modal opens (in `show.html.erb`)
2. On modal close, read from `sessionStorage` instead of relying on URL hash
3. Ensure the highlight script runs after the frame content is fully loaded

### Alternative Approaches

- Use `turbo:frame-load` event instead of `turbo:load` for more specific targeting
- Move the highlight logic into a Stimulus controller attached to the `rez` frame
- Use MutationObserver to detect when new content is added to the DOM