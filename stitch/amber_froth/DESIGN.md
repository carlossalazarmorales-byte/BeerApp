# Design System Document: The Artisanal Draught

## 1. Overview & Creative North Star: "The Digital Sommelier"
This design system moves away from the clinical, flat nature of standard "utility" apps to embrace the tactile, rich, and celebratory world of craft brewing. Our Creative North Star is **"The Digital Sommelier"**—an experience that feels editorial, expert, and deeply sensory.

To break the "template" look, we employ **intentional asymmetry** and **tonal layering**. We treat the mobile screen not as a flat canvas, but as a series of stacked, high-end materials. By overlapping high-fidelity beer photography with oversized, bold typography and translucent surfaces, we create a layout that feels like a premium beer magazine rather than a database.

---

## 2. Colors & Surface Architecture
The palette is inspired by the brewing process: the clarity of a pilsner, the richness of a stout, and the lightness of foam.

### The "No-Line" Rule
**Explicit Instruction:** Do not use 1px solid borders to section content. Traditional lines create a "grid-trap" that feels cheap. Boundaries must be defined through:
1.  **Background Color Shifts:** Use `surface-container-low` sections against a `surface` background.
2.  **Tonal Transitions:** Vertical white space and soft color blocks are the primary separators.

### Surface Hierarchy & Nesting
Treat the UI as physical layers. Use the following tokens to create "nested" depth:
*   **Surface (Lowest/Background):** `#faf9f5` (The base "Foam" layer).
*   **Surface-Container-Low:** `#f4f4f0` (Used for large, secondary content blocks).
*   **Surface-Container-High:** `#e9e8e4` (Used for interactive cards or elevated sections).
*   **Surface-Bright:** `#faf9f5` (Reserved for hero areas that need to "pop").

### The "Glass & Gradient" Rule
To add "soul" to the UI, use **Glassmorphism** for floating elements (e.g., a "Rate this Beer" button floating over a photo). Apply a `backdrop-blur: 12px` and use a semi-transparent `surface-container-highest` color.
*   **Signature Gradient:** For primary CTAs, use a linear gradient from `primary` (#795900) to `primary_container` (#ffbf00). This mimics the way light hits a glass of amber ale.

---

## 3. Typography: The Editorial Voice
We use a high-contrast pairing to balance authority with modern readability.

*   **Display & Headlines (Plus Jakarta Sans):** These are our "Brand Hooks." They should be bold and unapologetic. Use `display-lg` for gamification milestones (e.g., "Level 10: Brewmaster") to create a sense of achievement.
*   **Titles & Body (Inter):** Inter provides the functional clarity required for reading beer descriptions and tasting notes.
*   **Intentional Scale:** Use `display-md` (2.75rem) in close proximity to `body-sm` (0.75rem). This extreme contrast creates a premium, high-end editorial feel.

---

## 4. Elevation & Depth
Depth is achieved through **Tonal Layering**, not structural rigidity.

*   **The Layering Principle:** Place a `surface-container-lowest` card on a `surface-container-low` background. This creates a "soft lift" that feels organic and sophisticated.
*   **Ambient Shadows:** When an element must float (like a bottom sheet), use an extra-diffused shadow.
    *   *Spec:* `box-shadow: 0px 12px 32px rgba(41, 24, 10, 0.06);` (The shadow uses a hint of `on_secondary_fixed` to feel like natural light passing through liquid).
*   **The "Ghost Border" Fallback:** If a border is required for accessibility, use the `outline_variant` (#d4c5ab) at **15% opacity**. Never use 100% opaque borders.

---

## 5. Components

### Buttons & CTAs
*   **Primary:** Features the signature Amber gradient. Large corner radius (`xl` / 1.5rem). High-gloss finish.
*   **Secondary:** `secondary_container` background with `on_secondary_container` text. Subtle and sophisticated.
*   **Floating Action (Playful):** Use a circular `full` radius button with a `tertiary` color for gamification triggers (e.g., "Scan Label").

### Cards & Discovery Lists
*   **Rule:** Forbid divider lines.
*   **Beer Discovery Cards:** Use `surface-container-highest` for the card background. The beer imagery should "bleed" off one edge or overlap the header to break the box-model feel.
*   **Spacing:** Use generous padding (24px - 32px) to let the typography breathe.

### Gamification Elements (Chips & Badges)
*   **Status Badges:** For locked items, use `surface_dim` with `on_surface_variant` text.
*   **Achievement Chips:** Use `tertiary_container` with a subtle `primary` glow to signify a "rare" find.

### Inputs & Fields
*   **Styling:** Minimalist. Use `surface_container_highest` as the fill. No bottom line. On focus, transition the background to `primary_fixed_dim` at 10% opacity.

---

## 6. Do’s and Don’ts

### Do
*   **Do** use high-quality, "sweating" glassware imagery with blurred backgrounds.
*   **Do** overlap text on images using a subtle dark-to-transparent gradient overlay for legibility.
*   **Do** use asymmetrical layouts where a headline is left-aligned but the supporting image is slightly offset to the right.

### Don't
*   **Don't** use black (#000000). Use `on_secondary_fixed` (#29180a) for deep darks; it keeps the warmth.
*   **Don't** use standard 4px or 8px rounded corners. Stick to the `lg` (1rem) and `xl` (1.5rem) scale to maintain a modern, friendly feel.
*   **Don't** use dividers between list items. Use a 12px or 16px gap and a subtle background shift.

---

## 7. Interactive Philosophy
*   **The "Pour" Animation:** When refreshing a list, the pull-to-refresh icon should mimic a beer tap filling a glass.
*   **Micro-interactions:** Buttons should have a subtle "bounce" (haptic feedback) when pressed, mimicking the tactile click of a bottle cap being popped.
*   **Tonal Progression:** As a user unlocks more beers, the background of their profile should subtly shift from `surface` to a more intense `primary_fixed` to reflect their "Gold" status.