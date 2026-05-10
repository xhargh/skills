---
name: repo-docs
description: "Generate, reconcile, and keep up-to-date repository documentation: user-facing README.md files, developer-facing doc/ or docs/ folders, API references, usage examples mined from tests, and PlantUML architecture diagrams. Use when the user asks to document a repo, update docs, generate README/API docs, reconcile stale documentation with code, create developer guides, or keep docs up to date."
---

# repo-docs

Use one of two modes: **generate** when documentation is missing, and **reconcile** when existing documentation must be synced with code.

Hard rule: Do not add, infer, recommend, or run project build, run, test, install, or setup commands unless the user explicitly asks for those commands. Many repo environments have non-obvious invocation paths; when command documentation is requested, verify it from authoritative repo docs or ask the user instead of guessing from build files.

For detailed heuristics on language detection, component discovery, diagram selection, and document templates, read only the relevant section of [REFERENCE.md](REFERENCE.md).

## Phase 1 — Orient

1. Inspect the repository root and existing docs before editing.
2. Detect language and project type from build files and dominant extensions. Use this for orientation only, not to infer build/run/test instructions. Use [REFERENCE.md](REFERENCE.md#language-detection) when the project type is unclear.
3. Discover components/modules. Use [REFERENCE.md](REFERENCE.md#component-discovery) for language-specific boundaries.
4. Detect the diagram convention. Use [REFERENCE.md](REFERENCE.md#plantuml-diagram-storage) before adding or changing PlantUML.
   - **Default:** standalone `.puml` / `.plantuml` source files with generated `.png` files linked from Markdown. Use this whenever no prior convention is found.
   - If existing docs use only inline `plantuml` fences and have no standalone `.puml` / `.plantuml` files, continue with inline fences.
   - If existing docs have standalone `.puml` / `.plantuml` files and generated `.png` files, that convention is mandatory. Do not create inline `plantuml` fences.
5. Check whether `README.md`, `doc/`, or `docs/` exist.
   - Neither exists → **generate mode** (jump to Phase 3).
   - Either exists → **reconcile mode** (continue to Phase 2).

## Phase 2 — Reconcile existing docs

For each existing doc file:

1. Read it fully.
2. Compare every factual claim against the current code.
   - **Code wins.** If doc says X but code does Y, update the doc.
3. Identify any intent or design rationale that cannot be verified from code alone.
   - Ask the user inline: "Doc says `<claim>` — is this still accurate? Should it live as a code comment instead?"
4. Identify any public API / component that exists in code but is undocumented → add it.
5. Identify any doc section that references code that no longer exists → remove it.
6. Do not add a `Build`, `Run`, `Test`, `Install`, or setup section unless the user explicitly asks for it. If a generated-looking command section is present and the user did not ask for command docs, remove it.
7. Run a coverage audit before handing off. Look for missing docs for:
   - CLI commands, environment variables, config files, defaults, generated files, and failure behavior;
   - machine-readable output schemas and public file formats;
   - user-facing interactive tools or generated reports, including controls, state, filtering, and limitations;
   - troubleshooting and current limitations that are evident from code or tests;
   - stale roadmap, plan, or ADR documents that now conflict with implementation; mark historical docs clearly or move them only if the repo already has an archive convention.

Also read existing standalone `.puml` / `.plantuml` diagram sources discovered during Phase 1. Treat them as documentation that must be reconciled against the current code:

- If a diagram is stale, update the PlantUML source file, regenerate its PNG, and keep the Markdown link pointing at the PNG.
- If a diagram appears intentionally partial or simplified, for example it uses `...`, `..`, comments such as `partial`, `simplified`, `omitted`, `not shown`, or a title/label indicating a subset, do not silently expand it to the full code truth.
  Ask the user inline: "Diagram `<diagram>` appears intentionally partial (`<marker>`). Should it stay simplified, be expanded, or be split into additional diagrams?"
- If a linked generated PNG is stale but the PlantUML source is correct, regenerate only the PNG.
- Do not replace a standalone PlantUML + PNG convention with inline Markdown diagrams.

After reconciliation, continue to Phase 3 only for missing files or sections.

## Phase 3 — Generate

### README.md (user-facing)

Focus: **what the repo does and how to use it**. Public API only. Do not include build, run, test, install, or setup commands unless the user explicitly asks for command documentation.

Structure:
```
# <repo name>
<one-paragraph description>

## Usage
<code examples mined from tests, manifests, and public API surface>
<examples for public APIs or documented CLIs; no build/run/test/install/setup commands unless explicitly requested>

## API Reference
<public functions / classes / CLI commands / config files / environment variables / output files, with signatures or shapes and brief descriptions>
```

### doc/index.md (developer entry point)

Do not include a `Build`, `Run`, `Test`, `Install`, or setup section unless the user explicitly asks for it.

Structure:
```
# Developer Guide
<brief description of the internal architecture>

## Components
<links to each component page>

## Architecture
<component/package diagram — create a standalone `.puml` file, render a `.png`, and link the PNG; use an inline `plantuml` block only if the repo already uses inline fences exclusively>
```

### doc/<component>.md (one per component)

Structure:
```
# <Component Name>
<purpose and responsibilities>

## Key types / interfaces
<class diagram — OOP-heavy code only; create a standalone `.puml` file, render a `.png`, and link the PNG; use an inline `plantuml` block only if the repo already uses inline fences exclusively>

## Key flows
<sequence diagram — for non-trivial control flows; create a standalone `.puml` file, render a `.png`, and link the PNG; use an inline `plantuml` block only if the repo already uses inline fences exclusively>

## Public API
<signatures + descriptions>

## Implementation notes
<anything a developer modifying this needs to know>
```

Choose diagram types using [REFERENCE.md](REFERENCE.md#diagram-selection).

## Phase 4 — Hand off

- Print a summary of what was created/updated, what verification ran, what questions remain open, and any important documentation gaps deliberately left for later.
- Regenerate PNGs for all standalone PlantUML files with `scripts/render-plantuml.sh <repo-root>` before handoff. Skip only if the repo uses inline fences exclusively and has no standalone `.puml` / `.plantuml` files.
- Verify every inline `plantuml` fenced block and standalone `.puml` / `.plantuml` file with `scripts/verify-plantuml.sh <repo-root>` before handoff.
  - If verification passes, include "PlantUML syntax verified" in the summary.
  - If PlantUML is unavailable, say "PlantUML syntax not verified: CLI unavailable" and leave the docs in place.
  - If verification fails, fix the diagram syntax and rerun verification before handoff.
- Do **not** commit. Leave changes for the developer to review and commit.
- If any intent questions were deferred (user was AFK), leave them as `<!-- TODO: verify intent: <question> -->` comments in the relevant doc.
