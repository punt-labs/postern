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
