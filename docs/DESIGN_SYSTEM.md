# Design System

Reference summary of `/stitch/amber_froth/DESIGN.md` ("The Artisanal Draught").
`/stitch` stays the source of truth and is never modified; this document exists
so the tokens below can be implemented natively in Flutter starting in Phase 1
(Design System & App Shell) — nothing here is implemented yet.

## Colors

| Token | Value | Use |
|---|---|---|
| surface | `#faf9f5` | base background |
| surface-container-low | `#f4f4f0` | secondary content blocks |
| surface-container-high | `#e9e8e4` | interactive cards |
| primary | `#795900` | gradient start (CTAs) |
| primary-container | `#ffbf00` | gradient end (CTAs) |
| on-secondary-fixed | `#29180a` | deep dark text — never pure black |
| outline-variant | `#d4c5ab` | borders, at 15% opacity only, accessibility fallback |

## Typography

- **Display/headlines:** Plus Jakarta Sans, bold — used for brand moments and
  gamification milestones (e.g. "Level 10: Brewmaster").
- **Titles/body:** Inter — used for descriptions and tasting notes.
- Deliberate extreme size contrast between display and body sizes is part of
  the editorial feel; avoid a flat type scale.

## Shape & elevation rules

- **No-Line Rule:** no 1px divider lines. Separate content with background
  color shifts and spacing, not borders.
- Corner radii stick to `lg` (1rem) / `xl` (1.5rem) — never 4px/8px.
- Elevation via tonal layering (a lighter card on a darker background), not
  hard shadows. When a shadow is needed (floating elements), use a diffused
  ambient shadow, not a sharp drop shadow.
- Glassmorphism (`backdrop-blur`) for floating CTAs over imagery.

## Interaction

- Pull-to-refresh mimics a beer tap pour.
- Buttons get subtle haptic "bottle-cap" feedback on press.

## Implementation note

These tokens should live in `mobile/lib/design_system/` as shared
colors/typography/spacing constants once Phase 1 starts — not hardcoded
per-widget, per `CLAUDE.md`.
