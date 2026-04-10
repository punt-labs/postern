# Postern — Agent Bootstrap

A live Pharo eval server is running at `http://localhost:8422`.

**Read the server's documentation before writing any Smalltalk:**

```bash
curl http://localhost:8422/help
```

This returns a table of contents for nine sections. Read the sections relevant to
your task before starting. The content is served from the live image and reflects
the actual loaded packages — not static docs.

| Section | When to read it |
|---------|----------------|
| `/help/api` | First time connecting — covers endpoints, auth, request format |
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
