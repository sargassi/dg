# Dark Mode Implementation

## Approach
- **Strategy**: Tailwind `darkMode: 'class'` — class-based toggling via Stimulus, persists in `localStorage`, respects `prefers-color-scheme` on first visit.
- **Palette**: `slate-900` body bg, `slate-800` card/surface bg, `slate-700` borders, `slate-200` primary text, `slate-400` secondary text.

## Files Changed

### Config
- `config/tailwind.config.js` — added `darkMode: 'class'`

### Stimulus
- `app/javascript/controllers/theme_controller.js` — toggle, localStorage persistence, system preference detection, icon swap

### Layout
- `app/views/layouts/application.html.erb` — `<html data-controller="theme">`, `<body>` dark bg/text classes, flash notifications dark variants, login page dark bg
- `app/views/layouts/menus/side/_structure.html.erb` — theme toggle `<li>` added before logout
- `app/views/layouts/menus/side/_logout.html.erb` — dark variant classes
- `app/views/layouts/menus/top/_macro.html.erb` — dark text variant

### CSS
- `app/assets/stylesheets/application.tailwind.css` — `.dark` overrides for hardcoded color rules: `.linx:hover`, `.active`, `#legend`, `.section-qr`, `.simple-calendar` (all sub-elements)

### Helpers (`app/helpers/application_helper.rb`)
All `style_*` methods updated with `dark:` variants:
- Sidebar: `style_side_ul`, `style_side_li`, `style_side_a`
- Forms: `form_container`, `select_class`, `input_class`, `style_toggle_switch`
- Layout: `style_container_head`, `style_subcontainer_linx`, `style_main_cnt`, `style_main_header_container`, `style_main_header`, `style_main_sub_header`
- Cards: `style_main_card`, `style_main_card_header`, `style_main_card_link`, `style_main_card_badge`
- Calendar: `calendar_cell_classes`, `calendar_day_classes`
- Lists: `style_main_lists_head`, `style_main_lists_p_border`, `style_agenda_li`, `style_actions_linx`, `style_main_lists_subtitle`, `style_main_lists_subtitle_nomarg`
- Tables: `style_table_th`, `style_table_td`, `style_table_td_parent`, `style_table_th_children`, `style_table_td_children`
- Inputs: `style_main_input`, `style_input`, `style_select_class`
- Import: `style_import_form`, `style_import_field`

### Partials
- `app/views/atoms/_header.html.erb`
- `app/views/atoms/ux/_pagy.html.erb`
- `app/views/atoms/ux/_list.html.erb`
- `app/views/atoms/ux/_legenda.html.erb`
- `app/views/atoms/ux/_fltrs.html.erb`
- `app/views/atoms/home/_card.html.erb`
- `app/views/atoms/menu/_lab.html.erb`
- `app/views/atoms/menu/_ufficio.html.erb`
- `app/views/atoms/_search_single.html.erb`

## Remaining Issues (to improve)
- **Form inputs**: `@tailwindcss/forms` plugin may need manual dark overrides for select/input/checkbox default styles
- **Hardcoded colors in views**: Some views may still have inline `bg-white`, `text-slate-*`, `border-slate-*` without `dark:` counterparts (audit needed)
- **Legacy partials**: `_search_qr.html.erb`, `_form_*.html.erb`, and other atom partials may need dark variants
- **Turbo Stream responses**: Flash notices rendered via Turbo Stream may not carry dark mode classes
- **PDF layout**: Explicitly excluded (no dark mode needed for PDFs)
- **Accent color**: `#1E3581` (dark navy) is near-invisible on `slate-900`. Consider using `accent-300` (`#7f9be0`) or a lighter accent variant in dark mode
- **Toggle icon**: The sidebar toggle shows the correct icon on page load but may not update after Turbo navigations (verify)
- **Transitions**: Only `body` has `transition-colors` — sub-elements may snap instead of fade

## Toggle
- Located in the sidebar before the logout button
- Icon swaps between `light_mode` (sun) and `dark_mode` (moon)
- Preference persisted in `localStorage` under key `"theme"`
- First-time visitors respect `prefers-color-scheme` media query
