# DG Style Guide

> Living document maintained by **dez**. Updated through structured Q&A sessions.

## Domain & Users
- **App purpose**: Production tracking (orders, advancement stages F1–F5), warehouse items, office operations
- **Primary users**: Office staff on desktop (not factory floor)
- **Target device**: Desktop monitors (not phone/tablet)
- **Design target**: Office productivity tool — efficient, clear, professional

## Brand
- **Company**: Ok'am Srl (affiliated with Daniela Gregis — high-end Italian fashion)
- **Brand ethos**: Natural, artisanal, warm, quality materials, Italian craftsmanship
- **Visual direction**: Efficient neutral. Tool-like, not decorative
- **Design system**: Swiss/International Style — grid-rational, typography-driven, clean hierarchy, restrained color

## Typography
- **Font family**: Inter var (geometric sans, Swiss-style — keep current)
- **Base size**: 14px (body text)
- **Scale**:
  - 11px — `text-xxs` (table cells, labels, metadata)
  - 14px — `text-sm` / base (body)
  - 16px — `text-base` (card titles, subheaders)
  - 20px — `text-xl` (section headers)
  - 24px — `text-2xl` (page titles)
  - 32px — `text-3xl` (dashboard hero / primary headings)
- **Weights**: 400 (regular), 500 (medium), 600 (semibold) — rely on weight + letter-spacing for hierarchy, not color

## Color Palette
_TBD_

### Color Palette

**Neutrals** (the UI shell):
- Page bg: white / slate-50 (alternating)
- Sidebar: slate-100 bg, slate-600 icons
- Text: slate-900 (headings), slate-700 (body), slate-400 (muted)
- Borders: slate-200, slate-300

**Accent** (buttons, links, active states, focus rings):
- Primary: `accent` (alias for #1E3581 navy blue, defined in tailwind.config.js)
- Light bg: accent-50, accent-100
- Dark: accent-700/800 (icon buttons, hover states)

**Semantic** (data states only):
- Success: emerald-600
- Warning: amber-500
- Error: red-500
- Info: accent (reuse primary accent)

**Warm accent** (sparing — active nav, date highlights):
- amber-500 / amber-50 bg (calendar selected days, badges)

## Spacing & Grid
- **Base unit**: 4px (Tailwind default: p-1=4, p-2=8, p-3=12, p-4=16, p-6=24, p-8=32, etc.)
- **Sidebar**: fixed 4rem (w-16), icon-only, slate-100 bg — kept as-is
- **Content**: flexible width, no max-width constraint (data pages need full width)
- **Tables**: `overflow-x-auto` wrapper with horizontal scroll pattern — no fixed column widths that break
- **Card padding**: _TBD_
- **Gaps between sections**: _TBD_

## Components
_TBD_

### Buttons
- Primary: `bg-accent text-white text-xs rounded-sm px-2 py-1` (via `style_main_btn`)
- Confirm/Save: `bg-green-600 text-white text-xs rounded-sm` (via `button_class`)
- Danger: `bg-red-500 text-white` (PDF, delete — `style_action_pdf`, `style_import_pdf`)
- Secondary: `bg-slate-100 text-slate-700 border border-slate-300` (future)
- Icon: `bg-accent-800 text-white h-10 w-10 hover:bg-accent-700` (via `style_main_btn_icon`)
- Import action: `bg-accent text-white uppercase text-xs rounded-sm` (via `style_import_btn`)

### Cards
- Background: _TBD_
- Padding: _TBD_
- Shadow/border: _TBD_

### Tables
- Header: `bg-slate-100 text-xs font-normal lowercase text-start border border-slate-200 p-3`
- Cells: `text-xs border border-slate-300 p-3`
- Row hover: `hover:bg-slate-50`
- Container: `overflow-x-auto` wrapper for horizontal scroll
- Child tables: header `p-2 bg-slate-50`, cells `p-2 text-sm`

### Forms
- Input style: _TBD_
- Label style: _TBD_
- Select style: _TBD_
- Error states: _TBD_

### Navigation
- Side menu: 4rem wide, slate-100 bg, icons with micro-text labels
- Top bar: _TBD_
- Active state: _TBD_

### Notifications / Toasts
- **Position**: `fixed bottom-4 right-4` (macOS-style bottom-right)
- **Elevation**: `z-50` (above all page content)
- **Width**: `max-w-sm` (384px), content-driven height
- **Background**: White (`bg-white`), `rounded-lg shadow-xl`
- **Accent border**: `border-l-4` — emerald-500 for success/notice, red-500 for error/alert
- **Layout**: Flex row, icon + text with `gap-3`
- **Icon**: Material Symbols Outlined — `check_circle` (emerald-500) for notice, `error` (red-500) for alert
- **Text**: `text-sm text-slate-800`
- **Animation** (via `notifications` Stimulus controller):
  - Start: `translate-x-full opacity-0` (off-screen to the right)
  - Slide in: remove those classes → CSS `transition-all duration-300 ease-out` animates to final position
  - Auto-dismiss: after 4000ms (configurable via `data-notifications-auto-dismiss-value`)
  - Slide out: re-add `translate-x-full opacity-0`, then `remove()` after 300ms
- **Controller**: `data-controller="notifications"` on the toast element
- **Target**: `<turbo_frame_tag 'success'>` kept in layout for Turbo Stream responses

#### Example (notice — success)
```erb
<div data-controller="notifications"
     data-notifications-auto-dismiss-value="4000"
     class="fixed bottom-4 right-4 z-50 max-w-sm w-full
            translate-x-full opacity-0
            transition-all duration-300 ease-out
            bg-white rounded-lg shadow-xl border-l-4 border-emerald-500 p-4
            flex items-start gap-3">
  <span class="material-symbols-outlined text-emerald-500 text-xl flex-shrink-0">check_circle</span>
  <span class="text-sm text-slate-800 pt-0.5"><%= notice %></span>
</div>
```

#### Example (alert — error)
```erb
<div data-controller="notifications"
     data-notifications-auto-dismiss-value="4000"
     class="fixed bottom-4 right-4 z-50 max-w-sm w-full
            translate-x-full opacity-0
            transition-all duration-300 ease-out
            bg-white rounded-lg shadow-xl border-l-4 border-red-500 p-4
            flex items-start gap-3">
  <span class="material-symbols-outlined text-red-500 text-xl flex-shrink-0">error</span>
  <span class="text-sm text-slate-800 pt-0.5"><%= alert %></span>
</div>
```

## Icons
- System: Material Symbols Outlined
- Default size: 18px (inline), 24px (standalone)
- Style: _TBD_ (fill vs outline weight)

## Tailwind Config
- Plugins: @tailwindcss/forms, @tailwindcss/aspect-ratio, @tailwindcss/typography, @tailwindcss/container-queries
- Extensions:
  - `fontSize.xxs`: 11px
  - `colors.accent`: #1E3581 navy palette (DEFAULT=base, plus 50–900)
  - `fontFamily.sans`: Inter var

## Accessibility
_TBD_

- Color contrast targets: WCAG AA
- Focus indicators: _TBD_
- Touch targets: _TBD_

## Dark Mode

### Golden Rule
**Never change light mode colors.** Only add `dark:` prefixed classes. Every `dark:` addition is an override — light mode stays untouched.

### Palette (Tailwind Slate)
| Token | Light | Dark |
|---|---|---|
| Page bg | white / slate-50 | `dark:bg-slate-900` |
| Card bg | white | `dark:bg-slate-800` |
| Input bg | white | `.dark input { background: #334155 }` (CSS rule) |
| Text (primary) | slate-800/900 | `dark:text-slate-200` |
| Text (body) | slate-700 | `dark:text-slate-200` |
| Text (muted) | slate-400 | `dark:text-slate-300` or `dark:text-slate-400` |
| Borders | slate-200/300 | `dark:border-slate-600/700` |
| Hover bg | slate-50 | `dark:hover:bg-slate-700/50` or `dark:hover:bg-slate-700` |
| Sidebar bg | slate-100 | `dark:bg-slate-800` |

### White-on-Dark Cards (Labels / Etix)
Some `.cell` divs must stay **white in both modes** (print-oriented label previews):
```html
<div class="cell bg-white text-slate-800 ...">
```
No `dark:` background override needed — the white is intentional for label rendering on any background.

### Semantic Colors in Dark Mode
Brand/status colors that are too dark on dark bg:
| Light | Dark fix | Example |
|---|---|---|
| `text-emerald-700` | `dark:text-emerald-400` | Entrate title |
| `text-red-700` | `dark:text-red-400` | Uscite title |
| `text-indigo-700` | `dark:text-indigo-400` | Production percentage |
| `text-blue-900` | `dark:text-blue-300` | Section headers |

### Accent in Dark Mode
- Links / hover: `dark:text-accent-300` (instead of `text-accent`)
- Hover bg: `dark:bg-accent-900/30` (subtle accent tint on hover)
- Icon buttons: keep `bg-accent-800` (already dark enough)

### Hover States
Always pair light hover with a dark variant:
```erb
hover:bg-slate-50 dark:hover:bg-slate-700/50
```

### Global CSS Overrides
In `application.tailwind.css`:
```css
/* Dark mode inputs */
.dark input[type="text"],
.dark input[type="search"],
.dark input[type="email"],
.dark input[type="password"],
.dark input[type="number"],
.dark select,
.dark textarea {
  background-color: #334155;
}

/* QR code white bg on dark */
.dark td svg { background: white; }
```

### JIT Safelist
Dynamic ERB-injected classes won't be picked up by Tailwind JIT. Add to `tailwind.config.js`:
```js
safelist: [
  'dark:bg-blue-600',
  'dark:text-white',
]
```

### Section Labels (Swiss Style)
Section labels like "Ultimo inserimento" use a consistent dark-mode-safe treatment:
```erb
<h5 class="text-xs uppercase tracking-widest font-semibold text-slate-500 dark:text-slate-300 ml-2 -mt-4">
```

---

## PDF / Print
_TBD_

- wicked_pdf overrides in `app/assets/stylesheets/pdf.css`
- Print margins: _TBD_
- Font size: _TBD_
