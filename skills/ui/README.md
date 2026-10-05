# UI

Design skills for native apps. Installed with `--stack=ios`.

- **[design-loop](./design-loop/SKILL.md)** — Create or improve screens in a code-generated design file, audit them in a fresh subagent against an iOS checklist, stop for approval, apply only the approved findings, re-audit. Setup guide: [DESIGN-PIPELINE.md](../../DESIGN-PIPELINE.md).

## Sources

`design-loop` borrows rules, not code. Each rule in
[audit-ios.md](./design-loop/references/audit-ios.md) names the skill it came from.
Versions are the ones read on 2026-10-04.

| Source | Version | License | Taken | Left out, and why |
|--------|---------|---------|-------|-------------------|
| [wondelai/skills · ux-heuristics](https://github.com/wondelai/skills/tree/main/ux-heuristics) (Nielsen, Krug) | 1.6.0 | MIT | Nielsen's 10 heuristics, severity scale 0-4, per-screen findings table | Search box, browser back, hover, breadcrumbs, Trunk Test: web-only |
| [wondelai/skills · ios-hig-design](https://github.com/wondelai/skills/tree/main/ios-hig-design) (Apple HIG) | 1.5.1 | MIT | 44pt targets, safe areas, margins, native navigation, destructive actions, light/dark, SF Symbols | SwiftUI modifiers, VoiceOver, haptics, Dynamic Type reflow: not visible in a static file. Its "Title: 17pt Medium" is wrong (Title1 is 28pt) and was replaced with Apple's text style table |
| [wondelai/skills · refactoring-ui](https://github.com/wondelai/skills/tree/main/refactoring-ui) (Wathan, Schoger) | 1.5.1 | MIT | Squint/grayscale test, one hierarchy lever at a time, labels below values, grouping, elevation scale | 4/8/16 px scale, "never pure black", tinted grays, Tailwind classes: conflict with iOS system colors and the project's tokens |
| [wondelai/skills · design-everyday-things](https://github.com/wondelai/skills/tree/main/design-everyday-things) (Don Norman) | 1.4.0 | MIT | Error message checklist, signifiers, constraints, mapping, drawn feedback | Seven stages and HCD process: method, not a checkable rule |
| [wondelai/skills · steve-jobs-design-review](https://github.com/wondelai/skills/tree/main/steve-jobs-design-review) | 1.2.0 | MIT | One intent per screen, steps to value, "back of the fence" for empty/error states, cut list | Demo on device, "what did we remove this cycle": process, not a screen check |
| [wondelai/skills · microinteractions](https://github.com/wondelai/skills/tree/main/microinteractions) (Dan Saffer) | 1.4.1 | MIT | Control states must be drawn | Timing, loops, modes: runtime behavior, audit it in code |
| [wondelai/skills · top-design](https://github.com/wondelai/skills/tree/main/top-design) | 1.6.0 | MIT | Nothing | Bans system fonts and pure black/white, asks for smooth-scroll libraries, parallax and custom cursors: award-site web design, contradicts iOS |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 2.13.0 | MIT | Called at runtime (not copied): `--domain` lookups for typography, color, ux, icons, and `--stack swiftui` | `--design-system`, Pattern, Key Effects, web checklist: built for web landing pages and ignores the brand |
| [WCAG 2.1](https://www.w3.org/TR/WCAG21/) (W3C) | 2.1 | W3C | Contrast thresholds 4.5:1 / 3:1 and the luminance formula | — |

ui-ux-pro-max is a prerequisite, installed as a Claude Code plugin. The wondelai
skills are not installed: their useful rules live in `audit-ios.md`, rewritten for iOS.
