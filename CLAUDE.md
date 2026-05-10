# Postern

Postern is a remote driver for a live Pharo Smalltalk image. It exposes
the running image as an HTTP server: clients send Smalltalk to `/repl`,
read live documentation from `/help`, and drive compile / test / inspect
/ commit loops without going through the Pharo GUI. Postern was carved
out of [`punt-labs/claude-agent-sdk-smalltalk`](https://github.com/punt-labs/claude-agent-sdk-smalltalk)
in early 2026 and ships independently. It has **zero Claude dependency**
by design — agent integration happens at the HTTP boundary, not in the
Smalltalk image.

This file covers the contributor workflow for **developing Postern**.
For agents **using** Postern's runtime (bootstrap, `/help` flow,
`/repl` usage, eval token handling), read [AGENTS.md](AGENTS.md).

The public-facing description is in [README.md](README.md). Architecture
and engineering conventions live below.

## What Postern Is

A single product, three packages plus a baseline:

1. **`Postern-Core`** — the HTTP eval server. `PosternServer` (Zinc-backed)
   binds to `localhost:8422` (or `$EVAL_PORT`), routes `/repl`, `/health`,
   and `/help/*`, enforces auth on `/repl` when configured, and converts
   LF line endings to CR before passing source to the Pharo compiler.
2. **`Postern-Dashboard`** — `PosternDashboard` Morphic UI showing live
   request traffic, status, and request/response bodies. Optional;
   loaded by the `default` group but never required by `Postern-Core`.
3. **`Postern-IcebergExtensions`** — repairs Iceberg reference-commit
   drift after CLI git operations. Optional; loaded by the `default`
   group.
4. **`BaselineOfPostern`** — Metacello baseline declaring all three
   packages plus their `*-Tests` siblings. Three groups: `default`
   (Core + Dashboard + IcebergExtensions), `tests`, `all`.

Loading from another image:

```smalltalk
Metacello new
  baseline: 'Postern';
  repository: 'github://punt-labs/postern:main';
  load.
```

## Architecture

- **HTTP eval server** — `PosternServer` is Zinc-backed (Pharo's built-in
  HTTP). Loopback-only by default. `startOn:` and `startOn:withAuth:`
  bind to localhost; `startPublicOn:` binds to all interfaces and always
  requires a token. `/health` and `/help` are unauthenticated; `/repl`
  uses an `X-Eval-Token` header read from `.tmp/eval-token`.
- **Live `/help` system** — help content is generated from the loaded
  image, not static markdown. `/help/api`, `/help/browse`, `/help/pharo`,
  `/help/dispatch`, `/help/lint`, `/help/git`, `/help/testing`,
  `/help/safety`, `/help/makefile`, `/help/lessons`. Each section
  reflects the actual loaded packages; updating the image updates the
  help.
- **Eval pipeline** — `POST /repl` body is `text/plain` Smalltalk.
  Server normalises line endings, evaluates in `OpalCompiler`, returns
  `printString` of the result. Errors return the exception's
  description. No streaming.
- **Iceberg sync** — `Postern-IcebergExtensions` adds a `repairAfterCli`
  helper for the case where you've committed via CLI (`make` targets,
  `git` directly) and Iceberg's reference commit has drifted.
- **Dashboard** — Morphic; opens from World menu or via
  `PosternDashboard open`. Subscribes to `Postern-Core` announcements
  to render request traffic.

## Packages on Disk

```
src/
├── BaselineOfPostern/                 — Metacello baseline + manifest
├── Postern-Core/                      — HTTP server, /repl, /help, auth
├── Postern-Core-Tests/
├── Postern-Dashboard/                 — Morphic UI
├── Postern-Dashboard-Tests/
├── Postern-IcebergExtensions/         — git-from-CLI repair helpers
└── Postern-IcebergExtensions-Tests/
```

Tonel format. One class per `.class.st` file. `package.st` per package
declares the package name. Tests live in sibling `*-Tests` packages.

## Development Model

Postern is developed against a **live image**. There is no
edit-compile-restart loop:

1. `make start` — boots a Pharo image with Postern loaded.
2. From any tool (curl, the Pharo IDE, another agent), drive `/repl` to
   compile new methods, run tests, and inspect.
3. `make commit` writes Tonel files to `src/` and stages them.

Concretely, this means **all code changes are made through the running
image**, not by editing files on disk and reloading. The Tonel files in
`src/` are the persisted form of the image's state, not the source of
truth during a development session.

When dispatching to a worker:

- **Read `/help/<section>` from the live image** before writing
  Smalltalk. The live docs reflect what's actually loaded; static
  references in this file may lag the image.
- **Use scoped test runs** (`Postern-Core-Tests` not `all`) — running
  every test in the image during a tight TDD loop is a footgun.
- **Lint passes through `/help/lint`** — the image enforces conventions
  you can't reproduce from a file editor.

## Postern Eval Server (developer view)

For runtime usage (curl examples, auth tokens, `/help` discovery flow),
see [AGENTS.md](AGENTS.md). Below is the developer-side surface.

| Route | Method | Auth | What it does |
|-------|--------|------|--------------|
| `/repl` | `POST` | Required when enabled | Evaluate Smalltalk from `text/plain` body, return `printString` |
| `/health` | `GET` | None | Return `ok` |
| `/help` | `GET` | None | Live table of contents for the loaded image |
| `/help/{section}` | `GET` | None | Section: `api`, `browse`, `pharo`, `dispatch`, `lint`, `git`, `testing`, `safety`, `makefile`, `lessons` |

Binding modes:

| Constructor | Binds to | Auth |
|-------------|----------|------|
| `PosternServer startOn: 8422` | loopback | none |
| `PosternServer startOn: 8422 withAuth: true` | loopback | required |
| `PosternServer startPublicOn: 8422` | all interfaces | required (always) |

There is no unauthenticated public mode. The token is written to
`.tmp/eval-token`; clients read it and pass it back as `X-Eval-Token`.

## Pharo 12 Standards

- **Tonel** is the on-disk format. Do not commit `.image` / `.changes`
  artefacts — `.gitignore` covers them.
- **Class comments** are mandatory on every class. Lint gate fails on
  empty comments.
- **Method protocols** must be sensible English (`accessing`, `private`,
  `testing`, `initialization`). Don't dump everything in `as yet
  unclassified`.
- **No Object subclasses without justification.** If a class doesn't
  need to extend `Object` directly, find a more specific superclass.
- **Use the Pharo collection protocols.** `do:`, `collect:`,
  `select:`, `reject:`, `inject:into:`. Don't import imperative loops
  from other languages.
- **`OpalCompiler`** is the entry point for all evaluation. Don't
  bypass it.
- **Zinc** is the HTTP stack. Don't introduce alternate HTTP libraries.
- **Pharo built-ins only** for parsing, JSON, sockets — `STON`,
  `NeoJSONReader/Writer`, `ZnClient`, `ZnServer`. No external Metacello
  dependencies in `Postern-Core`.

## Quality Gates

Run before every commit:

```bash
make check
```

Expands to: lint pass over Tonel sources, scoped test run, markdownlint
on docs, and a `health` ping to make sure the running image is alive.

If `make check` fails, fix the underlying issue. The "no pre-existing
excuse" rule applies here as everywhere — if you see something broken,
fix it.

## Ethos & Delegation

Identity: `agent: claude` per `.punt-labs/ethos.yaml`. Sub-agent calls
(e.g. `Agent(subagent_type="kwb")`) match ethos identity handles.

Postern is a Pharo Smalltalk live-image runtime exposed over HTTP.
Every change happens against a running image — there is no
edit-compile-restart loop, only `compile`, `evaluate`, and `commit`.
Worker pairs are Smalltalk specialists; evaluators bring Pike-style
discipline (lint gate, scoped tests, deadlock recovery). Within each
row, the worker and evaluator must be distinct handles. Claude is the
leader, never the evaluator.

| Task type | Worker | Evaluator |
|-----------|--------|-----------|
| Smalltalk class / method authoring | `kwb` (Beck) | `rej` (Johnson) |
| Refactoring (rename, extract, move) | `rej` | `kwb` |
| Test authoring (SUnit, scoped runs) | `kwb` | `rej` |
| HTTP endpoint / Zinc / `/help` content | `rej` | `mdm` (McIlroy) |
| Iceberg / git-from-image workflow | `kwb` | `adb` (Lovelace) |
| REPL token / auth / safety boundary | `djb` (Bernstein) | `kwb` |
| Image bootstrap / Makefile / headless start | `adb` | `mdm` |
| Lint / dispatch / live-docs protocol | `mdm` | `rej` |
| Cross-image deadlock or recovery investigation | `kwb` | `djb` |
| Cross-repo coordination with claude-agent-sdk-smalltalk | `claude` (leader) | `mcg` (Cagan) |

The Smalltalk pair (`kwb` / `rej`) is the working core. Engage `rej`
for class-hierarchy design, refactoring decisions, and framework
extraction; engage `kwb` for tight TDD cycles, lint discipline, and
live-image work. Use the `quick` pipeline for single-method or
single-test changes inside an existing class. Use `standard` for new
classes, protocol changes, or anything that touches the HTTP surface.

**Always read the relevant `/help/<section>` from the live image
before delegating** — the live docs reflect the loaded packages, not
static files.

## Naming Conventions

- **Class prefixes** — `Postern` for production classes
  (`PosternServer`, `PosternDashboard`, `PosternRequest`). `Posternxx`
  for nothing — there's no abbreviation form.
- **Test classes** — suffix `Test` (singular), one test class per
  production class where feasible. Test methods start with `test`.
- **Method selectors** — keyword form when there's an argument
  (`startOn:`, `startOn:withAuth:`). Unary for accessors. Don't invent
  Java-style getters.
- **Categories on packages** — `Postern-Core-Server`,
  `Postern-Core-Help`, `Postern-Dashboard-Views`. Categories within a
  package use the package's prefix.
- **Resource files** — under `resources/`, kebab-case names.

## Beads (Task Tracking)

This project uses **bd** for issue tracking. Conventions match the org
standard:

```bash
bd ready              # find available work
bd show <id>          # view issue
bd update <id> --status=in_progress
bd close <id>
bd sync
```

Bead IDs start with `postern-`. Work that affects multiple repos (e.g.
the Postern <-> claude-agent-sdk-smalltalk integration) should be
tracked in punt-kit instead — see the org-wide CLAUDE.md "where to
create a bead" section.

## Git Integration

Postern's own `Postern-IcebergExtensions` package handles the
git-from-image workflow. The CLI side is conventional:

- Branch naming: `feat/...`, `fix/...`, `chore/...`, `docs/...`.
- Squash-merge PRs.
- Branch protection enforces required checks: lint, test, docs.
- Commits on `main` are made by the `claude-puntlabs` identity (signed
  with the org GPG key); see the org-wide CLAUDE.md "Claude Agento"
  section.

When committing **from inside the image**, use the Iceberg pane in the
Pharo IDE and let `Postern-IcebergExtensions` repair any drift after.
When committing **from CLI**, run `make iceberg-repair` from the image
side to keep Iceberg's reference commit aligned.

## Cross-Repo Relationship

Postern is a sibling of `claude-agent-sdk-smalltalk`. That repo loads
Postern as a development dependency (`BaselineOfPostern` via Metacello)
to support the in-image dev workflow for the Claude Agent SDK and the
Workbench. Postern itself does not depend on anything in the agent-sdk
repo and must not start to.

When a change here affects how `claude-agent-sdk-smalltalk` consumes
Postern (e.g. a `/repl` contract change, an `X-Eval-Token` semantics
change, a renamed class in `Postern-Core`), follow the cross-repo
breaking-change protocol in the org-wide CLAUDE.md: biff the agent
responsible for the consumer repo, get explicit ack, ship in order,
verify integration end-to-end, release together.

## Standards References

- [Workflow](https://github.com/punt-labs/punt-kit/blob/main/standards/workflow.md)
- [GitHub](https://github.com/punt-labs/punt-kit/blob/main/standards/github.md)
- [Makefile](https://github.com/punt-labs/punt-kit/blob/main/standards/makefile.md)
- [Shell](https://github.com/punt-labs/punt-kit/blob/main/standards/shell.md)
- [README](https://github.com/punt-labs/punt-kit/blob/main/standards/readme.md)
