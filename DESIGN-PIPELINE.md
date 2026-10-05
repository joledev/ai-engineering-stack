# Design pipeline (iOS, OpenPencil)

How to run `/ui:design-loop` in your own project with Claude Code and this stack.
The skill designs or improves iOS screens like Claude Design (variants you pick
from, then iteration), has a read-only subagent audit the result, stops for your
approval, applies only what you approved, and audits again.
This guide covers the setup it needs; the loop itself is in
[skills/ui/design-loop/SKILL.md](./skills/ui/design-loop/SKILL.md).

## The idea

The design file is **generated from code**. Screens, components and tokens are
JavaScript modules; a build script turns them into a `.fig` file with
[OpenPencil](https://github.com/open-pencil/open-pencil). You never edit the
`.fig` by hand: you change the source and rebuild. That makes every design
change a diff the agent can make, review and revert.

> Two unrelated projects are called OpenPencil. This pipeline uses
> **open-pencil/open-pencil** (npm `@open-pencil/*`, CLI `openpencil`).
> It is not ZSeven-W/openpencil (Homebrew `op`, `.op` files).

## Prerequisites

| What | Why | How |
|------|-----|-----|
| This stack's agents | The audit runs in the read-only `design-auditor` | `install-global.sh` once per machine |
| The skill | `/ui:design-loop` | `init-project.sh <project> --stack=ios` |
| Node | Runs the build | Tested with Node 24 |
| `@open-pencil/cli` | Builds, exports PNGs, inspects the file | Installed in the design folder (see below). It is a dependency: agree on it with your team first |
| SF Pro | iOS system font, used by the renderer | Download from Apple into `~/Library/Fonts`. Apple's license: never commit it |
| ui-ux-pro-max (optional) | Typography, color and icon lookups during design | `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill`, then `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill`. Without it the loop still runs |

macOS only in practice: the font loader reads SF Pro from `~/Library/Fonts`.

## 1. Lay out the design folder

```
design/
  src/
    tokens.mjs      colors per mode (light/dark), type scale, spacing, radius, sizes
    kit.mjs         shared parts: header, card, row, button... (a part used by 2+ screens)
    screens/*.mjs   one file per section; each screen is built for light and dark
    build.mjs       page list: which screens go on which page
    run.mjs         runner: builds the scene, lays it out, writes the .fig
    fonts.mjs       font loader for the headless renderer
  tools/
    compare.mjs     optional: diffs a screen against a baseline
  fonts/            open-licensed fonts (OFL) the design uses
  app.fig           the output, generated
```

Keeping `design/` as its own git repo (ignored by the main repo) works well:
one commit per apply round, and the app repo stays free of design churn.

Install the CLI inside `design/`:

```bash
npm install @open-pencil/cli
```

## 2. Add the runner and the font loader

`build.mjs` exports `default async (figma) => { ... }` and draws with the
Figma-style API that OpenPencil exposes. `run.mjs` calls it with a real text
measurer and layout pass before writing, so text sizes in the file match the
rendered PNGs:

```js
// design/src/run.mjs
// usage: node --import ./src/fonts.mjs src/run.mjs <build.mjs> <out.fig> [in.fig]
import { readFile, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { IORegistry, BUILTIN_IO_FORMATS } from '@open-pencil/core/io';
import { computeAllLayouts } from '@open-pencil/core/layout';
import { FigmaAPI, SkiaRenderer, initCanvasKit } from '@open-pencil/core';
import { SceneGraph } from '@open-pencil/scene-graph';

const [buildPath, outPath, inPath = 'NEW'] = process.argv.slice(2);
const io = new IORegistry(BUILTIN_IO_FORMATS);
const graph = inPath === 'NEW' ? new SceneGraph()
  : (await io.readDocument({ name: inPath, data: new Uint8Array(await readFile(inPath)) })).graph;

const ck = await initCanvasKit();
const renderer = new SkiaRenderer(ck, ck.MakeSurface(1, 1));
await renderer.loadFonts();

const figma = new FigmaAPI(graph);
const build = (await import(pathToFileURL(buildPath).href)).default;
const result = await build(figma);

for (const page of graph.getPages ? graph.getPages() : []) {
  await renderer.prepareForExport(graph, page.id, page.childIds ?? []);
}
computeAllLayouts(graph);
await writeFile(outPath, (await io.writeDocument('fig', graph)).data);
console.log(JSON.stringify(result ?? 'ok'));
```

```js
// design/src/fonts.mjs
// Preload: serves local font files to OpenPencil's headless renderer.
// SF Pro comes from ~/Library/Fonts (never copied here); OFL fonts live in design/fonts/.
import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { fontManager } from '@open-pencil/core';

const OFL = fileURLToPath(new URL('../fonts/', import.meta.url));
const buf = (b) => b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength);
fontManager.setHostFontLoader(async (family, style) => {
  const s = (style || 'Regular').replace(/\s+/g, '');
  const sf = /^SF Pro (Display|Text)$/.exec(family);
  const path = sf
    ? `${homedir()}/Library/Fonts/SF-Pro-${sf[1]}-${s.replace(/^SemiBold$/i, 'Semibold')}.otf`
    : `${OFL}${family.replace(/\s+/g, '')}-${s}.ttf`;
  try { return buf(await readFile(path)); } catch { return null; }
});
```

Always run with `--import ./src/fonts.mjs`. Without it text falls back to
another font and every measurement in the audit is off.

### Your first screen

Start `build.mjs` with one screen to prove the setup works, then grow it into
`tokens.mjs`, `kit.mjs` and `screens/`:

```js
// design/src/build.mjs
export default async (figma) => {
  const screen = figma.createFrame();
  screen.name = 'Hello · Light';
  screen.resize(393, 852);                       // iPhone 15/16, in points
  screen.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];

  await figma.loadFontAsync({ family: 'SF Pro Display', style: 'Bold' });
  const title = figma.createText();
  title.fontName = { family: 'SF Pro Display', style: 'Bold' };
  title.fontSize = 34;                           // Large Title
  title.characters = 'Hola';
  title.x = 16; title.y = 110;
  screen.appendChild(title);
  return { screens: 1 };
};
```

Build it, then export it with the Build, Find id and Export commands from
section 3. Verified with `@open-pencil/cli` 0.15.1 and Node 24: it writes the
`.fig` and a 1179×2556 PNG (393×852 at 3x) with the title in SF Pro Display Bold.

## 3. Declare the pipeline in CLAUDE.md

The skill reads a `## Design pipeline` section from the project's `CLAUDE.md`
(root, or a `design/CLAUDE.md` linked from the root). A missing section or key
makes it stop and ask: it never guesses a command. Fill in your paths:

```markdown
## Design pipeline

Used by `/ui:design-loop`. Run every command from the repo root.

| Key | Value |
|-----|-------|
| Source | `design/src/` (`screens/*.mjs`, `kit.mjs`, `build.mjs`) |
| Tokens | `design/src/tokens.mjs` |
| Build | `node --import ./design/src/fonts.mjs design/src/run.mjs design/src/build.mjs design/app.fig` |
| Output | `design/app.fig` (each screen as `"<name> · Light"` and `"<name> · Dark"`) |
| Find id | `node design/node_modules/@open-pencil/cli/bin/openpencil.js eval <file.fig> --json -c 'return figma.root.children.flatMap(p=>p.findAll(n=>n.name==="<screen name>").map(n=>n.id))'` |
| Export | `node --import ./design/src/fonts.mjs design/node_modules/@open-pencil/cli/bin/openpencil.js export <file.fig> --node <id> -s 3 -o <out.png>` |
| Compare | `node design/tools/compare.mjs <baseline.fig> <baselineScreenId> design/app.fig "<screen name>"` |
| Spec | `docs/requirements.md` (requirement IDs the screens implement) |
```

Required by the skill: Source, Tokens, Build, Output, Export, Compare, Spec.
Find id is how Export gets a node id from a screen name. No compare tool yet?
Say so in the Compare row; the skill then cannot prove an apply round touched
only the approved rows, so review the PNGs yourself.

## 4. Run the loop

```
/ui:design-loop Ajustes            improve a section (you don't need to know how)
/ui:design-loop R7                 design the screen for requirement R7
/ui:design-loop audit Ajustes      audit only, no redesign
```

It works like Claude Design: you ask, it designs, you look at the result.
What happens, and where you step in:

1. **brief**: it exports the screens and diagnoses them itself against
   [audit-ios.txt](./skills/ui/design-loop/references/audit-ios.txt), plus
   ui-ux-pro-max lookups. Then it asks you at most 3 **product** questions
   (who uses the screen, what they do first). "No sé" is a valid answer. It
   never asks how something should look.
2. **propose**: it builds 2-3 variants, each attacking a different problem, on a
   page `Propuestas · <section>` in the `.fig`, light and dark. Open it in
   OpenPencil. The real screens are untouched.
3. **pick and iterate**: **you pick** a letter, a mix, or none. The pick replaces
   the real screen; then you give feedback ("más aire") until you say "listo".
4. **audit**: the read-only `design-auditor` agent checks the result: Nielsen,
   Apple HIG, WCAG contrast computed from the tokens, hierarchy, errors, control states.
5. **STOP**: a findings table by severity (0-4). **You pick the rows to apply**,
   and you write the text for every `COPY: user decides` row. The skill never
   invents product copy and never continues on silence.
6. **apply**: changes only the approved rows, rebuilds, compares every reachable
   screen against the pre-apply copy, and commits once per round.
7. **re-audit**: a new `design-auditor` checks the applied rows. At most 2
   rounds; what is left is listed for you.

## Rules that save you a bad afternoon

- Never edit the `.fig` by hand. The next build overwrites it.
- Brand accent and platform font are locked: suggestions to change them show up
  as proposals in the table, never as edits.
- One part, one place: a fix shared by several screens goes into `kit.mjs` or
  `tokens.mjs`, once.
- Keep a fidelity baseline in git (for example the first export from your
  design tool) so Compare has something to measure against.
