# iOS design audit checklist

For a static design file (exported PNGs plus the source that generates them).
Only rules a still screen can show are here; runtime behavior (VoiceOver labels,
haptics, animation timing, Dynamic Type reflow) is audited in code, not here.

Each rule names its source. Sources and what was left out: [../../README.md](../../README.md#sources).

## Severity (Nielsen, via ux-heuristics)

| Sev | Meaning | Use when |
|-----|---------|----------|
| 0 | Not a problem | Disagreement, not a usability issue |
| 1 | Cosmetic | Low impact; fix if time |
| 2 | Minor | Causes delay or frustration |
| 3 | Major | Significant task failure, or fails WCAG AA |
| 4 | Catastrophic | Blocks the task |

Weigh frequency, impact and persistence. A spec gap (a requirement with no
screen, or a screen that contradicts the Spec) is at least 3.

## A. Usability: Nielsen 10 (ux-heuristics)

| ID | Rule | Check on the screen |
|----|------|---------------------|
| N1 | Visibility of system status | Loading, saving, sent, error states are drawn, not only the happy path |
| N2 | Match the real world | User's words ("Iniciar sesión", not "Autenticar"); natural order of fields |
| N3 | User control and freedom | Every pushed screen has back; every sheet has close or swipe-down; destructive actions have a way out |
| N4 | Consistency and standards | One term per concept across screens; same control looks the same everywhere |
| N5 | Error prevention | Constrained inputs (picker over free text); gating field first, before the user types the rest |
| N6 | Recognition over recall | Prefilled values, visible options; nothing the user must remember from a previous screen |
| N7 | Flexibility | Frequent actions are one tap; secondary actions can live in a menu or swipe |
| N8 | Minimalist design | Every element earns its place; one primary action per screen |
| N9 | Recover from errors | See rule E1 |
| N10 | Help | Hints sit next to the field that needs them (password rules, formats) |

Skipped from ux-heuristics: search box, browser back, hover, breadcrumbs, the Trunk Test's "where is search".

## B. Platform: Apple HIG (ios-hig-design, corrected)

| ID | Rule | Check on the screen |
|----|------|---------------------|
| H1 | Touch targets | Every tappable thing has a hit area of at least 44×44pt, text links included |
| H2 | Safe areas | No interactive element under the status bar, Dynamic Island or home indicator (34pt) |
| H3 | Margins | Content 16-20pt from screen edges, consistent per screen |
| H4 | Native navigation | Tab bar for 2-5 top destinations, push for drill-down, sheet for focused tasks; no hamburger, no FAB, no top tabs |
| H5 | Back button | Top-left, with the previous screen's title or a chevron |
| H6 | Destructive actions | Red, separated from safe actions, with a confirmation when irreversible |
| H7 | Primary action in thumb reach | Bottom of the screen or nav bar trailing |
| H8 | Text styles | Sizes map to iOS text styles: Large Title 34, Title1 28, Title2 22, Title3 20, Headline 17 semibold, Body 17, Callout 16, Subheadline 15, Footnote 13, Caption1 12, Caption2 11. Nothing under 11pt |
| H9 | Light and dark | Every screen exists in both modes and keeps its hierarchy in both |
| H10 | Meaning not by color alone | Errors and states pair color with an icon or text |
| H11 | SF Symbols | Standard icons are SF Symbols (or match their weight and optical size) |

Corrected from ios-hig-design: it lists "Title: 17pt Medium". Apple's Title1 is
28pt; 17pt semibold is Headline. Use the H8 table.

## C. Contrast: WCAG 2.1 AA (computed from Tokens)

| ID | Rule |
|----|------|
| C1 | Text under 18pt regular / 14pt bold: at least 4.5:1 against what is behind it |
| C2 | Large text (18pt+, or 14pt+ bold): at least 3:1 |
| C3 | Non-text UI (field borders, icons that carry meaning, selected states): at least 3:1 |

Compute it, don't eyeball it. Read both colors from Tokens, per mode. A color with
alpha is composited over its real background first (`c = a·fg + (1−a)·bg` per
channel), then: relative luminance `L = 0.2126R + 0.7152G + 0.0722B` on linearized
channels (`v ≤ 0.04045 ? v/12.92 : ((v+0.055)/1.055)^2.4`), ratio `(L1+0.05)/(L2+0.05)`.
Report the measured ratio as the evidence. Text on an accent fill counts too
(white on a bright green fails in dark mode).

Apple system colors (`secondaryLabel` and similar) below 4.5:1 are Sev 1, not 3:
the platform adjusts them with Increase Contrast. Custom colors get no such pass.

## D. Visual hierarchy (Refactoring UI)

| ID | Rule | Check on the screen |
|----|------|---------------------|
| V1 | Squint test | Blurred or in grayscale, the primary element still reads first |
| V2 | One lever at a time | Primary text is larger OR bolder OR darker; all three only for the single most important element |
| V3 | Labels below values | Field labels and metadata are smaller or lighter than the data they label |
| V4 | Grouping | Space between groups is larger than space inside a group |
| V5 | Spacing scale | Spacing values come from Tokens; a one-off value needs a reason |
| V6 | Elevation | Shadow size matches how high the element floats (card < sheet < alert) |
| V7 | Avatars and overlaps | Overlapping elements don't hide content (initials, numbers) of the one below |

Skipped from refactoring-ui: the 4/8/16 px scale (use the project's Tokens), "darkest
is #111827, never pure black" and "tint your grays" (iOS dark mode uses true black and
system grays), Tailwind classes, max-width rules.

## E. Errors, signifiers, constraints (Design of Everyday Things)

| ID | Rule | Check on the screen |
|----|------|---------------------|
| E1 | Error message | Says what went wrong, how to fix it, doesn't blame, keeps the user's input, offers another path when the user can't fix it |
| E2 | Signifiers | Tappable things look tappable (links underlined or tinted, buttons filled or outlined); decorative things don't |
| E3 | Constraints | Invalid actions are impossible or disabled (Continue disabled until the form is valid) |
| E4 | Mapping | Controls sit next to what they change |
| E5 | Feedback is drawn | For every action on the screen, the "after" state exists somewhere in the file |

## F. Focus and unseen surfaces (Steve Jobs design review)

| ID | Rule | Check |
|----|------|-------|
| F1 | One intent | The screen's purpose fits in one sentence; if not, it is two screens |
| F2 | Steps to value | A new user reaches the section's core value in 3 steps or fewer |
| F3 | Back of the fence | Empty, error, blocked and settings screens get the same care as the hero screen |
| F4 | Cut list | Report what can be removed, not only what to add |

## G. Control states (Microinteractions)

| ID | Rule | Check |
|----|------|-------|
| G1 | States drawn | Each control that changes state shows its states somewhere: default, disabled, loading, selected |

## Output

One row per finding, highest severity first:

| # | Sev | Screen | Rule | Evidence | Proposed fix |
|---|-----|--------|------|----------|--------------|

Close with what passed (one line per screen) so the user sees what was checked.
