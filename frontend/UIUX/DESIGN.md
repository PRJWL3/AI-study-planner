---
name: Lumina Study
colors:
  surface: '#f9f9ff'
  surface-dim: '#cfdaf1'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eeff'
  surface-container-high: '#dee8ff'
  surface-container-highest: '#d8e3fa'
  on-surface: '#111c2c'
  on-surface-variant: '#3d4943'
  inverse-surface: '#263142'
  inverse-on-surface: '#ebf1ff'
  outline: '#6d7a72'
  outline-variant: '#bccac1'
  surface-tint: '#006c4d'
  primary: '#006c4d'
  on-primary: '#ffffff'
  primary-container: '#3eb489'
  on-primary-container: '#00402d'
  inverse-primary: '#69dbad'
  secondary: '#674bb5'
  on-secondary: '#ffffff'
  secondary-container: '#ab8ffe'
  on-secondary-container: '#3f1e8c'
  tertiary: '#546259'
  on-tertiary: '#ffffff'
  tertiary-container: '#96a49b'
  on-tertiary-container: '#2d3a33'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#86f8c8'
  primary-fixed-dim: '#69dbad'
  on-primary-fixed: '#002115'
  on-primary-fixed-variant: '#005139'
  secondary-fixed: '#e8ddff'
  secondary-fixed-dim: '#cebdff'
  on-secondary-fixed: '#21005e'
  on-secondary-fixed-variant: '#4f319c'
  tertiary-fixed: '#d7e6dc'
  tertiary-fixed-dim: '#bbcac0'
  on-tertiary-fixed: '#121e18'
  on-tertiary-fixed-variant: '#3c4a42'
  background: '#f9f9ff'
  on-background: '#111c2c'
  surface-variant: '#d8e3fa'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  container-padding: 24px
  gutter: 16px
---

## Brand & Style

The design system focuses on creating a supportive, high-focus, and optimistic environment for students. The brand personality is that of a "smart companion"—encouraging, organized, and technologically advanced without being cold. 

The visual style is **Glassmorphic Modernism**. It utilizes soft, multi-layered translucency to create a sense of lightness and depth. Friendly 3D character illustrations act as anchoring focal points, humanizing the AI aspect of the application. The aesthetic prioritizes "soft-focus" visuals, using background blurs and organic color transitions to reduce cognitive load and evoke a sense of calm productivity.

## Colors

The palette is anchored in **Mint Green** (Primary) and **Lavender** (Secondary). Mint Green represents growth and focus, used for primary actions and success states. Lavender provides a soft, academic contrast, used for secondary features and organizational categories.

- **Primary (Mint):** Used for main CTAs, progress bars, and active states.
- **Secondary (Lavender):** Used for decorative elements, secondary buttons, and specific subject tagging.
- **Backgrounds:** A mix of ultra-light mint tints and white. Backgrounds often feature a subtle mesh gradient to give life to the glassmorphism effects.
- **Neutrals:** Soft charcoals and slate greys are used for text to maintain readability without the harshness of pure black.

## Typography

This design system utilizes **Plus Jakarta Sans** for all roles to maintain a cohesive, friendly, and modern geometric feel. The font’s open counters and soft terminals ensure high legibility and an approachable tone.

- **Headlines:** Use Bold or ExtraBold weights with tighter letter spacing for a punchy, contemporary look.
- **Body:** Regular weights with generous line heights to ensure long-form study notes are easy to digest.
- **Labels:** Semibold weights for better visibility at smaller scales, particularly within buttons and status chips.

## Layout & Spacing

The layout philosophy follows a **fluid-to-fixed model**. Mobile devices use a 4-column grid with 24px outer margins, while desktop views expand to a 12-column grid centered in the viewport.

Spacing is based on an 8px root system to maintain mathematical harmony. We employ "breathable" layouts, meaning whitespace is prioritized over information density. This prevents the "study stress" often associated with cluttered academic tools. Cards and containers should have generous internal padding (typically `md` or 24px) to allow the glassmorphic background blurs to feel substantial.

## Elevation & Depth

Hierarchy is established through **Glassmorphic Layering** rather than traditional heavy shadows.

- **Base Layer:** A soft, multi-colored mesh gradient (Mint and Lavender) that remains static.
- **Secondary Layer (Surfaces):** Containers use a semi-transparent white background (`rgba(255, 255, 255, 0.7)`) with a `blur(20px)` backdrop filter. 
- **Borders:** "Inner-glow" borders are used—a 1px solid white border with 30% opacity—to define edges against vibrant backgrounds.
- **Shadows:** Only used for interactive elements like floating action buttons. These shadows are ultra-diffused, using a tinted primary color (`rgba(62, 180, 137, 0.15)`) instead of black.

## Shapes

The design system uses a **Rounded** shape language to reinforce the friendly and safe brand personality. 

- **Containers & Cards:** Use `rounded-xl` (1.5rem / 24px) to create a soft, friendly framing for content.
- **Buttons & Inputs:** Use `rounded-lg` (1rem / 16px) for a modern, tactile feel.
- **Small Elements (Chips/Tags):** Use a full-pill radius to distinguish them from structural components.
- **3D Characters:** These should feature smooth, rounded geometries to match the UI’s curvature.

## Components

### Buttons
- **Primary:** Solid Mint Green with white text. High-contrast, bold weight.
- **Secondary:** Transparent with a Lavender border or soft Lavender tint.
- **Glass Button:** Semi-transparent white with heavy backdrop blur, used for over-image actions.

### Input Fields
- **Login Inputs:** Large touch targets with 16px padding. Light grey or semi-transparent backgrounds. Active states are indicated by a 2px Mint Green border.
- **Placeholders:** Soft slate grey, using a slightly smaller font size than the input text.

### Cards
- Standard containers for tasks and AI insights. Must include a 1px soft white border and `rounded-xl` corners. 
- **Active Card:** Features a subtle Mint Green glow or an icon indicator.

### Chips & Tags
- Used for task difficulty (High, Medium, Low). These utilize the full-pill shape.
- Colors follow the status: High (Red tint), Medium (Orange tint), Low (Mint tint).

### Navigation
- A floating bottom bar with glassmorphism. Active icons use a Primary Mint tint and a small dot indicator below the icon.