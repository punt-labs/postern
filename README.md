# Postern

> Drive a live Pharo image from any coding agent or HTTP client — full development cycle, no GUI required.

[![Pharo 12](https://img.shields.io/badge/Pharo-12-%23aac9ff.svg)](https://pharo.org/download)
[![License](https://img.shields.io/github/license/punt-labs/postern)](LICENSE)

Pharo is a live programming environment. Compiling a method installs it into the
running image immediately — no restart, no recompile step. Postern exposes that
capability over HTTP: a server on `localhost:8422` accepts Smalltalk expressions,
executes them in the live image, and returns the result. Any outside
tool — Claude Code, a CI job, a shell script — can drive the full development
cycle without touching the Pharo GUI.

**Platforms:** macOS, Linux (Pharo 12)

## Quick Start

```bash
git clone https://github.com/punt-labs/postern.git
cd postern
make          # shows available targets
make setup    # downloads Pharo 12 VM + image, loads all Postern packages
make start    # starts Postern with the Pharo GUI on macOS and Linux desktop sessions
# make start-headless  # optional: start without the GUI instead
```

On headless Linux sessions without `DISPLAY` or `WAYLAND_DISPLAY`, use
`make start-headless`.

If port `8422` is already in use, override it on the command line, for
example `make PORT=8432 start-headless`.

```bash
curl -s http://localhost:8422/health    # → ok
curl -s http://localhost:8422/help     # → self-documenting table of contents
```

## Security Warning

Postern accepts Smalltalk code over HTTP and runs it in the live image.
A client that can successfully call `/repl` can do what normal Smalltalk
code in that image can do: change classes and methods, inspect objects,
read and write files, and run shell commands with the OS permissions of
the user running Pharo.

By default, `make start` and `make start-headless` bind to `localhost`
only and do **not** enable auth. That is intended for local development
on a trusted machine. If you enable auth, the `X-Eval-Token` is a shared
secret for `/repl`; it is not a sandbox, permission system, or read-only
mode. `/help` and `/health` remain unauthenticated even when auth is on.

Do not expose Postern to untrusted networks or untrusted agents. Do not
run it in an environment containing secrets or data you would not hand to
arbitrary code running as your user account.

## Trivia

The name is intentional: a postern is a back door or gate, a private side
entrance, or in fortification usage, a small secondary gate in a wall or castle.
That fits this project pretty literally: it gives tools a deliberate side
entrance into a live Pharo image without making the GUI the only way in.

## The live image model

Most language environments store code as files. An agent editing Python, Go, or
TypeScript writes to files, a compiler processes them, and the runtime loads the
result — typically requiring a process restart before new code can execute.

Pharo stores code in a live object graph called an image. Compiling a method
installs it into that graph immediately. The same session can define a class,
call a method on it, run its tests, and inspect the live objects it creates —
all without a restart. Each of those steps happens in the running process.

For agent-driven coding this tightens the loop at every increment. After sending
a compile request, the agent can call the new method in the next request, observe
the real runtime result, and branch on it — not on a static type check or a test
run that spawned a subprocess. When the increment is complete, Iceberg (Pharo's
git integration) runs inside the same image, so the agent can commit without
leaving the session.

Postern's role is to make that image accessible to tools that speak HTTP.

## Coding Agents + Pharo

Any coding agent that can make HTTP requests and follow instructions can drive the
full TDD cycle. The agent sends Smalltalk to `/repl` and reads `/help` to learn the
image's API, conventions, and safety rules. From there it drives define → compile →
test → commit without leaving its session. Claude Code, Codex, Cursor, and any
other agent that speaks HTTP all work the same way.

The `/help` endpoint is the interface contract between an external agent and the
image. A session that has never seen the image before reads `/help` first and uses
those ten sections to navigate correctly:

| Section | What it documents |
|---------|-------------------|
| `/help/api` | Eval server protocol: endpoints, auth, request/response format |
| `/help/browse` | Read-only introspection: classes, methods, senders, implementors, source lookup |
| `/help/pharo` | Pharo 12 standards: fluid class syntax, protocols, JSON pattern |
| `/help/dispatch` | Sub-agent delegation: TDD cycle, required spec elements, anti-patterns |
| `/help/lint` | Lint discipline: `make lint` is the gate, not per-method critiques |
| `/help/git` | Iceberg commits, CLI merges, reference commit sync |
| `/help/testing` | Scoped test runs, never the full Pharo suite |
| `/help/safety` | LibC deadlock prevention, image discipline, orphan recovery |
| `/help/makefile` | Image lifecycle: setup, start, stop, rebuild |
| `/help/lessons` | Incident record: cascades, process failures, scope safety |

The content is served from the live image at runtime, so it reflects the actual
loaded packages and the conventions that image was built with — not a static
documentation site.

For Codex users, this repo also includes `.codex/config.toml` and
`codex/rules/default.rules` so localhost help/REPL access can be
preconfigured after the repo is trusted once.

## System in Action

A complete feature cycle — define a class, compile a method, run tests, commit —
using nothing but HTTP to the server.

```bash
# Agent reads the image's API and conventions before writing anything
curl -s http://localhost:8422/help/api
curl -s http://localhost:8422/help/pharo
```

```bash
# Define a class (Pharo 12 fluid syntax — server converts LF to CR automatically)
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "(Object << #Counter
  slots: { #count };
  package: 'MyPackage') install"
# → a Counter
```

```bash
# Compile a method — takes effect in the running image immediately
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "Counter compile: 'increment
  count := (count ifNil: [0]) + 1' classified: 'actions'"
# → a CompiledMethod
```

```bash
# Run the tests — these exercise the live compiled method
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "CounterTest buildSuite run"
# → 3 ran, 3 passed, 0 failures, 0 errors
```

```bash
# Lint gate — must be empty before commit
make lint 2>&1 | grep -v ': clean$' | grep -v '^$'
# (no output)
```

```bash
# Commit via Iceberg — from inside the running image
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "| repo |
repo := IceRepository registry detect: [:r | r name = 'my-project'].
repo workingCopy refreshDirtyPackages.
repo workingCopy commitWithMessage: 'feat(counter): add increment'"
# → an IceCommit
```

The image stays live between steps. The agent can inspect live objects, browse class
hierarchies, query running servers, and call methods at any point in the cycle.

## Production Use

[`punt-labs/claude-agent-sdk-smalltalk`](https://github.com/punt-labs/claude-agent-sdk-smalltalk)
was developed using this workflow. That project ships five products for building
Claude agents in Pharo: an API client for the Claude Messages API, an in-image
agent tool runner, a Morphic GUI, and two integration layers. It currently has
199 classes, 2,358 methods, and 765 passing tests across approximately 32,000
lines of Smalltalk — all written, tested, and committed through Postern.

## Packages

| Package | Contents |
|---------|----------|
| `Postern-Core` | `PosternServer`, `PosternDelegate`, `PosternHelp` (10-route `/help` endpoint), `PosternImageBrowser` (introspection facade), `PosternWidget` (menu-bar status strip) |
| `Postern-Dashboard` | `PosternDashboard` — Spec2 traffic monitor with per-server log isolation; `PosternRequestLogger`, `PosternDashboardModel` |
| `Postern-IcebergExtensions` | `PosternSyncReferenceCommitCommand` — Iceberg context-menu command that syncs the working copy reference commit after CLI git operations |

Load via `BaselineOfPostern`:

```smalltalk
Metacello new
  baseline: 'Postern';
  repository: 'github://punt-labs/postern:main';
  load.
```

Load including tests:

```smalltalk
Metacello new
  baseline: 'Postern';
  repository: 'github://punt-labs/postern:main';
  load: 'all'.
```

## API Reference

### Eval server

| Route | Method | Description |
|-------|--------|-------------|
| `/repl` | `POST` | Evaluate Smalltalk (`text/plain` body). Returns `printString` of result. |
| `/health` | `GET` | Liveness check. Returns `ok`. No auth required. |
| `/help` | `GET` | Table of contents for the ten help sections. No auth required. |
| `/help/{section}` | `GET` | `api`, `browse`, `pharo`, `dispatch`, `lint`, `git`, `testing`, `safety`, `makefile`, or `lessons`. |

**Binding and authentication:**

| Method | Binding | Auth |
|--------|---------|------|
| `PosternServer startOn: 8422` | loopback | none |
| `PosternServer startOn: 8422 withAuth: true` | loopback | required |
| `PosternServer startPublicOn: 8422` | all interfaces | required |

There is no unauthenticated public mode. When auth is enabled, `/repl` requires an
`X-Eval-Token` header; the token is written to `.tmp/eval-token`, and clients
should read that file and send the header explicitly. `/health` and `/help` are
always unauthenticated.

**Line endings:** send LF. The server converts to CR before passing to the Pharo
compiler. `/help` responses use LF.

### Dashboard

Open from the World menu: **Postern > Dashboard**, or evaluate:

```smalltalk
PosternDashboard open.
```

Shows live traffic per server: method, path, status code, duration, body snippet.
The filter field takes keyboard focus on open. Multiple windows can monitor
different servers simultaneously.

### Iceberg sync

After CLI git operations, Iceberg's working copy reference commit can drift from
filesystem HEAD, showing a false "dirty" state. Fix it: right-click a repo in
the Iceberg browser → **Postern > Sync reference commit**. Or evaluate:

```smalltalk
repo workingCopy referenceCommit: repo head commit.
```

## Development

```bash
make rebuild     # fresh image from Tonel (proves source completeness)
make test        # run all Postern tests
make lint        # Renraku lint — zero non-clean lines required before commit
make filein      # reload Tonel packages into running image
make eval        # interactive Smalltalk eval (stdin to eval server)
make transcript  # read Pharo Transcript
make status      # health check — reports loaded class count
make stop        # kill Pharo (no save — image is disposable)
```

The image is disposable. All code lives in `src/` (Tonel format). `make rebuild`
must always succeed — if it fails, the source files are incomplete.

## License

MIT — see [LICENSE](LICENSE).
