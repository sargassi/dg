# Archive Hierarchy Design

## Overview
Add 2-level parent/child hierarchy to `archive_categories` and `archive_locations`.

## Schema Changes
- `archive_categories` add `parent_id` (integer, nullable, FK self)
- `archive_locations` add `parent_id` (integer, nullable, FK self)

Parents = Settori, Children = Ubicazioni (locations).
Parents = macro-categories, Children = subcategories (categories).

## Models
- `Archive::Category`: `belongs_to :parent` (optional), `has_many :children`
- `Archive::Location`: `belongs_to :parent` (optional), `has_many :children`
- Scopes: `roots` (parent_id IS NULL) on both

## Views
- Categories index: table with parents bold, children indented. Create form has optional parent select.
- Locations index: same structure. Create form has optional settore select.
- Items form: select dropdowns show "Parent > Child" format. Dropdown lists roots first, then children grouped.

## Items Form Detail
Category select: shows all categories, child options prefixed with parent name (e.g. "Tessuti > Cotone"). Uses a simple ordered list in the select, or grouped_options.

Location select: similar, "Settore > Ubicazione" format in the dropdown.
