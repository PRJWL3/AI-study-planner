---
name: Lumina Study
colors:
  surface: '#f9f9fc'
  surface-dim: '#dadadc'
  surface-bright: '#f9f9fc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f6'
  surface-container: '#eeeef0'
  surface-container-high: '#e8e8ea'
  surface-container-highest: '#e2e2e5'
  on-surface: '#1a1c1e'
  on-surface-variant: '#594042'
  inverse-surface: '#2f3133'
  inverse-on-surface: '#f0f0f3'
  outline: '#8d7072'
  outline-variant: '#e1bec0'
  surface-tint: '#b42243'
  primary: '#b42243'
  on-primary: '#ffffff'
  primary-container: '#ff5c77'
  on-primary-container: '#63001d'
  inverse-primary: '#ffb2b9'
  secondary: '#006a63'
  on-secondary: '#ffffff'
  secondary-container: '#8bf1e6'
  on-secondary-container: '#006f67'
  tertiary: '#835500'
  on-tertiary: '#ffffff'
  tertiary-container: '#c98921'
  on-tertiary-container: '#432900'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdadc'
  primary-fixed-dim: '#ffb2b9'
  on-primary-fixed: '#40000f'
  on-primary-fixed-variant: '#91002e'
  secondary-fixed: '#8ef4e9'
  secondary-fixed-dim: '#71d7cd'
  on-secondary-fixed: '#00201d'
  on-secondary-fixed-variant: '#00504a'
  tertiary-fixed: '#ffddb4'
  tertiary-fixed-dim: '#ffb954'
  on-tertiary-fixed: '#291800'
  on-tertiary-fixed-variant: '#633f00'
  background: '#f9f9fc'
  on-background: '#1a1c1e'
  surface-variant: '#e2e2e5'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '800'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: '1.3'
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '700'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: '1.5'
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.5'
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  margin-mobile: 20px
  gutter: 16px
  card-padding: 24px
  section-gap: 32px
---

## Brand & Style

The design system is centered on an **optimistic, playful, and high-energy** personality tailored for students. It utilizes a **Modern-Organic** aesthetic that blends structured layouts with fluid, biological shapes. 

The goal is to reduce the cognitive load and stress associated with studying by using a "toy-like" interface—where every interaction feels tactile and rewarding. We employ a mix of **vibrant color blocking** and **soft glassmorphism** to create a sense of depth that feels friendly rather than corporate. The UI should evoke feelings of progress, clarity, and encouragement.

## Colors

The palette is **vibrant yet creamy**, avoiding harsh pure whites in favor of a soft "off-white" paper-like background (`#FCF9F2`). 

- **Primary (Rose):** Used for main actions, streaks, and urgent progress indicators.
- **Secondary (Teal):** Used for focus modes, calm states, and completed tasks.
- **Tertiary (Amber):** Used for gamification elements, gold medals, and highlights.
- **Quaternary (Lavender):** Used for secondary subject categories and soft backgrounds.
- **Neutral:** A deep charcoal-blue is used for high-contrast text to ensure readability against the colorful background blocks.

Color is used functionally: each subject or study module should be assigned one of the brand's vibrant hues to aid in visual categorisation.

## Typography

This design system uses **Plus Jakarta Sans** exclusively to maintain a cohesive, modern, and friendly tone. Its geometric shapes with slightly rounded terminals complement the organic UI elements.

- **Headlines:** Use heavy weights (700-800) with tight letter spacing for a punchy, editorial feel.
- **Body:** Stays at a medium weight (500-600) to ensure legibility against colored card backgrounds.
- **Labels:** Used for metadata (e.g., "12 Topics"), employing uppercase and increased letter spacing to differentiate from body text.

## Layout & Spacing

The layout follows a **fluid-to-fixed model**. On mobile, it utilizes a 20px side margin. The rhythm is based on a **4px baseline grid**, but allows for "organic" breathing room—meaning large cards often have generous internal padding (24px) to feel spacious and approachable.

**Reflow Rules:**
- **Mobile:** Single column stacked cards. Navigation is a floating bottom "pill" bar.
- **Tablet/Desktop:** Content expands into a multi-column masonry grid. The sidebar becomes a fixed organic-shaped panel on the left.

## Elevation & Depth

This design system eschews traditional shadows for **Tonal Stacking** and **Soft Ambient Occlusion**.

1.  **Level 0 (Base):** The off-white background surface.
2.  **Level 1 (Cards):** Vibrant, solid-colored blocks. These do not use shadows; instead, they rely on high color contrast to pop.
3.  **Level 2 (Active Elements):** Elements like "Start" buttons or active selection chips use a very soft, large-radius shadow (Blur: 20px, Opacity: 10%) tinted with the primary color to suggest they are "floating" and ready to be pressed.
4.  **Overlays:** High-blur glassmorphism (Backdrop-filter: 12px) is used for floating navigation bars and modal backgrounds to maintain a sense of context.

## Shapes

The shape language is **distinctly rounded and organic**. 

- **Primary Cards:** Use a 24px (rounded-xl) corner radius.
- **Buttons & Inputs:** Use a full pill shape (rounded-full) or a 16px radius.
- **Decorative Elements:** Occasional use of "squircle" shapes or fluid, wave-like dividers between sections (e.g., the header transition) to break the rigidity of the grid.

## Components

### Buttons
- **Primary:** Full-pill shape, high-contrast background (Primary Rose or Secondary Teal), bold white text. Use a subtle inner-glow to make them feel tactile.
- **Ghost:** Transparent background with a 2px stroke matching the text color.

### Cards
Cards are the primary container. They should always have a colored background (avoiding white cards on white backgrounds). High-contrast text is mandatory. Inside a card, use **Glass-Pills** for metadata (e.g., a semi-transparent white bubble to hold the text "12 lessons").

### Input Fields
Inputs should be large and chunky with a 16px corner radius. Use a light-tinted version of the background color for the field, and a thick 2px border that appears only on focus.

### Progress Bars
Progress bars are thick (12px+) with fully rounded caps. They should use a secondary color (Teal) against a lower-opacity version of the same hue for the track.

### Navigation Bar
A floating "island" at the bottom of the screen. Dark neutral background (`#1A1C1E`) with high-contrast icons. The active state is indicated by a vibrant colored pill surrounding the icon.