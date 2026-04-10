# Postern

> Remote image driver for Pharo — HTTP eval server, `/help` endpoint, Iceberg sync.

Postern starts an HTTP server on `localhost:8422` inside a running Pharo image. Any
outside tool — Claude Code, a test runner, a CI job, a shell script — can evaluate
Smalltalk, introspect the image, and sync Iceberg without touching the Pharo GUI.

**Platforms:** macOS, Linux (Pharo 12)

**Zero Claude dependency.** Postern ships with no Anthropic SDK requirement. It is
useful on its own for any tooling that needs to drive a live image remotely.

## Quick Start

```bash
git clone https://github.com/punt-labs/postern.git
cd postern
make setup    # downloads Pharo 12 VM + image, loads all Postern packages
make start    # launches Pharo GUI with eval server on port 8422
```

```bash
curl -s http://localhost:8422/health                    # liveness check
curl -s http://localhost:8422/help                      # self-documenting TOC
curl -s http://localhost:8422/help/api                  # eval server protocol
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" -d "3 + 4"             # evaluates to 7
```

## Packages

| Package | Contents |
|---------|----------|
| `Postern-Core` | `PosternServer`, `PosternDelegate`, `PosternWidget` (menu-bar strip), `PosternHelp` (9-route `/help` endpoint) |
| `Postern-Dashboard` | `PosternDashboard` — Spec2 presenter for monitoring live traffic; `PosternRequestLogger`, `PosternDashboardModel` |
| `Postern-IcebergExtensions` | `PosternSyncReferenceCommitCommand` — Iceberg context-menu command to sync the working copy reference commit after CLI git operations |

Load all three via `BaselineOfPostern`:

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
| `/repl` | `POST` | Evaluate Smalltalk. Body: `text/plain`. Returns the printString of the result. |
| `/health` | `GET` | Liveness check. Returns `ok`. |
| `/help` | `GET` | Self-documenting table of contents (9 sub-routes). |
| `/help/api` | `GET` | Eval server protocol and authentication. |
| `/help/commands` | `GET` | Common eval patterns and examples. |
| `/help/classes` | `GET` | Key classes and their roles. |
| `/help/tools` | `GET` | Available agent tools. |
| `/help/workflow` | `GET` | Development workflow using Postern. |
| `/help/errors` | `GET` | Error handling and retry patterns. |
| `/help/standards` | `GET` | Coding standards and conventions. |
| `/help/version` | `GET` | Version information. |
| `/help/packages` | `GET` | Loaded package list. |

### Dashboard

Open from the World menu: **Postern > Dashboard**, or evaluate:

```smalltalk
PosternDashboard open.
```

The dashboard shows live traffic: method, path, status, duration, and body snippets.
Filter by typing in the filter field. The dashboard isolates log entries per server —
multiple servers can be monitored simultaneously, each in its own window.

### Iceberg sync

After CLI git operations (commit, merge, pull), Iceberg's working copy reference
commit can diverge from the filesystem HEAD, showing a false "dirty" state.
`PosternSyncReferenceCommitCommand` fixes this in one click: right-click a repo in
the Iceberg browser and choose **Postern > Sync reference commit**.

Or evaluate:

```smalltalk
| repo |
repo := IceRepository registry detect: [:r | r name = 'your-repo'].
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
make status      # health check
make stop        # kill Pharo (no save — image is disposable)
```

The image is disposable. All code lives in `src/` (Tonel format). `make rebuild`
must always succeed — if it fails, the source files are incomplete.

## Third-party status

This project is not affiliated with, endorsed by, or supported by Anthropic.

## License

MIT — see [LICENSE](LICENSE).
