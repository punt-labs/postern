# Postern — Agent Bootstrap

A live Smalltalk runtime is available at `http://localhost:8422`. You can compile
code, run tests, inspect objects, and commit — all over HTTP, without touching the IDE.

**Read the server's documentation before writing any Smalltalk:**

```bash
curl http://localhost:8422/help
```

This returns a table of contents for ten sections. Read the sections relevant to
your task before starting. The content is served from the live image and reflects
the actual loaded packages — not static docs.

| Section | When to read it |
|---------|----------------|
| `/help/api` | First time connecting — covers endpoints, auth, request format |
| `/help/browse` | Read-only introspection — classes, selectors, senders, source lookup |
| `/help/pharo` | Before writing any Smalltalk — covers class syntax, protocols, JSON |
| `/help/dispatch` | Before delegating sub-tasks — TDD cycle, required elements |
| `/help/lint` | Before committing — lint discipline and gate |
| `/help/git` | Before committing — Iceberg workflow, CLI merge |
| `/help/testing` | Before running tests — scoped runs only |
| `/help/safety` | If anything behaves unexpectedly — deadlock prevention, recovery |
| `/help/makefile` | To restart or rebuild the image |
| `/help/lessons` | When something goes wrong — incident record |

To evaluate Smalltalk:

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "3 + 4"
# → 7
```

If auth is enabled, add `-H "X-Eval-Token: $(cat .tmp/eval-token)"`.

## Agent Permissions / Config

Local `curl` access to `http://localhost:8422` may be blocked by your agent
tool sandbox unless allowlisted.

### First-Run Checklist

1. Start Postern so the runtime exists:

   ```bash
   make start
   # or: make start-headless
   ```

   On Windows ARM64, use `make start-headless`. That bootstrap path uses
   the Windows `x86_64` Stack VM under emulation, and it is headless-only.

2. In Codex, trust the repo once so project-scoped config is loaded.
3. In Codex or Claude Code, use `/permissions` if `curl` to
   `localhost:8422` is still blocked.
4. Read the live docs before making changes:

   ```bash
   curl -s http://localhost:8422/help
   curl -s http://localhost:8422/help/api
   curl -s http://localhost:8422/help/browse
   curl -s http://localhost:8422/help/pharo
   curl -s http://localhost:8422/help/safety
   ```

- Codex: use `/permissions` for the current session. If you want the same
  localhost calls to stop prompting, persist allow rules for `curl` to
  `/help`, `/health`, and `POST /repl` in your Codex config/rules. This
  repo includes a `.codex/config.toml` that keeps Codex in
  `workspace-write` mode but turns on localhost network access, plus a
  `codex/rules/default.rules` file with the common Postern localhost
  allowlist. Codex only loads project-scoped config after you trust the
  repo once.
- Claude Code: use `/permissions` for the current session. If you want the
  same localhost calls to stop prompting, persist them in Claude Code
  settings (for example `~/.claude/settings.json` or
  `.claude/settings.local.json`).

If calls to `localhost:8422` fail unexpectedly, check agent permissions first
before assuming the Postern server is down.

`make setup` and the startup targets fall back to a repo-local runtime home
under `.tmp/pharo-home` when the normal Pharo config directories are not
writable, so agents usually do not need to override `HOME` manually.

## Ethos & Delegation

Identity: `agent: claude` per `.punt-labs/ethos.yaml`. Sub-agent calls (`Agent(subagent_type=…)`) match ethos identity handles.

Postern is a Pharo Smalltalk live-image runtime exposed over HTTP. Every change happens against a running image — there is no edit-compile-restart loop, only `compile`, `evaluate`, and `commit`. Worker pairs are Smalltalk specialists; evaluators bring Pike-style discipline (lint gate, scoped tests, deadlock recovery). Worker and evaluator must be distinct handles with no shared role. Claude is the leader, never the evaluator.

| Task type | Worker | Evaluator |
|-----------|--------|-----------|
| Smalltalk class / method authoring | `kwb` (Beck) | `rej` (Johnson) |
| Refactoring (rename, extract, move) | `rej` | `kwb` |
| Test authoring (SUnit, scoped runs) | `kwb` | `rej` |
| HTTP endpoint / Seaside / `/help` content | `rej` | `mdm` (Pike) |
| Iceberg / git-from-image workflow | `kwb` | `adb` (Lovelace) |
| REPL token / auth / safety boundary | `djb` (Bernstein) | `kwb` |
| Image bootstrap / Makefile / headless start | `adb` | `mdm` |
| Lint / dispatch / live-docs protocol | `mdm` | `rej` |
| Cross-image deadlock or recovery investigation | `kwb` | `djb` |

Use the `quick` pipeline for single-method or single-test changes inside an existing class. Use `standard` for new classes, protocol changes, or anything that touches the HTTP surface. Always read the relevant `/help/<section>` from the live image before delegating — the live docs reflect the loaded packages, not static files.
