# Postern

> Drive a live Pharo image over HTTP from a coding agent or shell.

[![License](https://img.shields.io/github/license/punt-labs/postern)](LICENSE)
[![Lint](https://img.shields.io/github/actions/workflow/status/punt-labs/postern/lint.yml?label=Lint)](https://github.com/punt-labs/postern/actions/workflows/lint.yml)
[![Test](https://img.shields.io/github/actions/workflow/status/punt-labs/postern/test.yml?label=Test)](https://github.com/punt-labs/postern/actions/workflows/test.yml)
[![Docs](https://img.shields.io/github/actions/workflow/status/punt-labs/postern/docs.yml?label=Docs)](https://github.com/punt-labs/postern/actions/workflows/docs.yml)
[![Pharo 12](https://img.shields.io/badge/Pharo-12-%23aac9ff.svg)](https://pharo.org/download)

Postern exposes a running Pharo image as an HTTP server. Clients send
Smalltalk expressions to `/repl`, read `/help` from the live image, and
drive compile, test, inspect, and commit loops without going through the
Pharo GUI. It is intended for local development, CI, and agent-driven
workflows where the image itself is the runtime.

**Platforms:** macOS, Linux (`x86_64`, `arm64`/`aarch64`), Windows (`x86_64`; ARM64 via x86_64 Stack VM emulation) (Pharo 12)

## Quick Start

```bash
git clone https://github.com/punt-labs/postern.git
cd postern
make
make setup
make start
```

`make setup` downloads the matching Pharo image and VM for the current
host. If Pharo cannot write to its usual user config directories
(for example inside a Codex or Claude Code sandbox), Postern falls back
to a repo-local runtime home under `.tmp/pharo-home`.

On Windows ARM64, `make setup` automatically uses the Windows `x86_64`
Stack VM under emulation because the default Windows JIT VM is not
reliable there.

On headless Linux sessions without `DISPLAY` or `WAYLAND_DISPLAY`, use
`make start-headless`.

If port `8422` is already in use, override it on the command line, for
example `make PORT=8432 start-headless`.

```bash
curl -s http://localhost:8422/health
curl -s http://localhost:8422/help
```

Before exposing Postern beyond your machine or handing it to an agent,
read [Security](#security).

## Features

- **HTTP REPL** — Evaluate Smalltalk in a live image through `POST /repl`.
- **Live help from the image** — `/help` documents the loaded packages,
  conventions, and workflow directly from the running image.
- **GUI and headless startup** — `make start` launches the Pharo UI and
  `make start-headless` runs without it.
- **Dashboard** — `PosternDashboard` shows live request traffic, status,
  and request and response bodies.
- **Iceberg sync helper** — Repairs Iceberg reference-commit drift after
  CLI Git operations.
- **Optional token auth** — Loopback mode can run without auth; public
  binding always requires a token.

## What It Looks Like

```text
$ curl -s http://localhost:8422/health
ok

$ make status
alive -- <class-count> Postern classes loaded

$ make test
Tests: <run-count>  Passed: <pass-count>  Failures: 0  Errors: 0
```

![Postern Dashboard showing live `/repl` activity, including the test run driven through Postern](docs/images/postern-dashboard.png)

*The dashboard after driving Postern through `make test` and related
`/repl` activity.*

## API

### Eval Server

| Route | Method | Description |
|-------|--------|-------------|
| `/repl` | `POST` | Evaluate Smalltalk from a `text/plain` body and return the `printString` of the result. |
| `/health` | `GET` | Return `ok`. No auth required. |
| `/help` | `GET` | Return the table of contents for the live help. No auth required. |
| `/help/{section}` | `GET` | Return a specific help section: `api`, `browse`, `pharo`, `dispatch`, `lint`, `git`, `testing`, `safety`, `makefile`, or `lessons`. |

#### Binding and Authentication

| Method | Binding | Auth |
|--------|---------|------|
| `PosternServer startOn: 8422` | loopback | none |
| `PosternServer startOn: 8422 withAuth: true` | loopback | required |
| `PosternServer startPublicOn: 8422` | all interfaces | required |

There is no unauthenticated public mode. When auth is enabled, `/repl`
requires an `X-Eval-Token` header. The token is written to
`.tmp/eval-token`, and clients should read that file and send the header
explicitly. `/health` and `/help` are always unauthenticated.

Send LF line endings in requests. The server converts them to CR before
passing source to the Pharo compiler. `/help` responses use LF.

### Dashboard

Open from the World menu: **Postern > Dashboard**, or evaluate:

```smalltalk
PosternDashboard open.
```

The dashboard shows live traffic per server: method, path, status code,
duration, and body snippet. The filter field takes keyboard focus on
open. Multiple windows can monitor different servers simultaneously.

### Iceberg Sync

After CLI Git operations, Iceberg's working copy reference commit can
drift from filesystem `HEAD`, showing a false dirty state. Fix it from
the Iceberg browser with **Postern > Sync reference commit**, or
evaluate:

```smalltalk
repo workingCopy referenceCommit: repo head commit.
```

## Setup

### Load into Another Image

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

### Agent Bootstrap

External agents should read the live help before writing Smalltalk:

```bash
curl -s http://localhost:8422/help
curl -s http://localhost:8422/help/api
curl -s http://localhost:8422/help/browse
curl -s http://localhost:8422/help/pharo
curl -s http://localhost:8422/help/safety
```

The `/help` endpoint is served by the running image, so it reflects the
loaded packages and current conventions instead of a static doc set.

| Section | What it documents |
|---------|-------------------|
| `/help/api` | Eval server protocol: endpoints, auth, request and response format |
| `/help/browse` | Read-only introspection: classes, methods, senders, implementors, source lookup |
| `/help/pharo` | Pharo 12 standards: fluid class syntax, protocols, JSON pattern |
| `/help/dispatch` | Sub-agent delegation: TDD cycle, required spec elements, anti-patterns |
| `/help/lint` | Lint discipline: `make lint` is the gate, not per-method critiques |
| `/help/git` | Iceberg commits, CLI merges, reference commit sync |
| `/help/testing` | Scoped test runs, never the full Pharo suite |
| `/help/safety` | Deadlock prevention, image discipline, orphan recovery |
| `/help/makefile` | Image lifecycle: setup, start, stop, rebuild |
| `/help/lessons` | Incident record: cascades, process failures, scope safety |

For Codex users, this repo also includes `.codex/config.toml` and
`codex/rules/default.rules` so localhost help and REPL access can be
preconfigured after the repo is trusted once. `make setup` already
handles the common sandbox case by falling back to `.tmp/pharo-home`
when the normal Pharo config directories are not writable.

## Security

Postern accepts Smalltalk code over HTTP and runs it in the live image.
A client that can successfully call `/repl` can do what normal Smalltalk
code in that image can do: change classes and methods, inspect objects,
read and write files, and run shell commands with the OS permissions of
the user running Pharo.

By default, `make start` and `make start-headless` bind to `localhost`
only and do **not** enable auth. When auth is enabled, the
`X-Eval-Token` is a shared secret for `/repl`; it is not a sandbox,
permission system, or read-only mode. `/help` and `/health` remain
unauthenticated even when auth is on.

Do not expose Postern to untrusted networks or untrusted agents. Do not
run it in an environment containing secrets or data you would not hand
to arbitrary code running as your user account.

## Live Image Model

Pharo stores code in a live object graph called an image. Compiling a
method installs it into that graph immediately. The same session can
define a class, call a method on it, run its tests, and inspect the
objects it creates without a process restart.

For agent-driven coding, that means the loop stays inside the running
system. After sending a compile request, the agent can call the new
method in the next request and branch on the real runtime result, not a
restarted subprocess. Iceberg runs inside the same image, so commit
operations can stay in the same session too.

## Agent Workflow

An external agent can drive a complete edit cycle through HTTP: read the
live help, define or compile code, run scoped tests, and commit through
Iceberg. A typical sequence looks like this:

```bash
curl -s http://localhost:8422/help/api
curl -s http://localhost:8422/help/pharo
```

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "(Object << #Counter
  slots: { #count };
  package: 'MyPackage') install"
```

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "Counter compile: 'increment
  count := (count ifNil: [ 0 ]) + 1' classified: 'actions'"
```

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "CounterTest buildSuite run"
```

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "| repo |
repo := IceRepository registry detect: [ :r | r name = 'my-project' ].
repo workingCopy refreshDirtyPackages.
repo workingCopy commitWithMessage: 'feat(counter): add increment'"
```

## Packages

| Package | Contents |
|---------|----------|
| `Postern-Core` | `PosternServer`, `PosternDelegate`, `PosternHelp`, `PosternImageBrowser`, `PosternWidget` |
| `Postern-Dashboard` | `PosternDashboard`, `PosternRequestLogger`, `PosternDashboardModel` |
| `Postern-IcebergExtensions` | `PosternSyncReferenceCommitCommand` for Iceberg reference-commit sync |

## Trivia

The name is intentional: a postern is a back door or gate, a private
side entrance, or in fortification usage, a small secondary gate in a
wall or castle. That fits this project literally: it gives tools a side
entrance into a live Pharo image without making the GUI the only way in.

## Development

```bash
make rebuild     # fresh image from Tonel (proves source completeness)
make test        # run all Postern tests
make lint        # Renraku lint — zero non-clean lines required before commit
make filein      # reload Tonel packages into a running image
make eval        # interactive Smalltalk eval (stdin to eval server)
make transcript  # read the Pharo Transcript
make status      # health check and loaded-class count
make stop        # kill Pharo without saving the image
```

The image is disposable. All code lives in `src/` in Tonel format.
`make rebuild` must always succeed; if it fails, the source files are
incomplete.

## License

MIT — see [LICENSE](LICENSE).
