# Contributing

Postern is developed against a running image. See [CLAUDE.md](CLAUDE.md)
for the development model and conventions, and `/help/makefile`,
`/help/lint`, and `/help/testing` in the running image for details.

## Setup

```bash
make setup
```

```bash
make start-headless
```

## Quality Gates

Run these before every commit. Most of them talk to the running image, so
start it first.

Shellcheck the scripts and lint every Postern class. Every class must
report `clean`:

```bash
make lint
```

Run the Postern test suites. Failures and errors must be 0:

```bash
make test
```

Confirm every package in `src/` is loaded and the Iceberg working copy is
clean:

```bash
make check
```

Lint the Markdown files, as the Docs CI job does:

```bash
npx markdownlint-cli2 "**/*.md" "#pharo" "#node_modules"
```

### Ethos handoff snapshot

Ethos runs the blocking handoff checks (ShellCheck and markdownlint-cli2 on
the changed files) inside a verified snapshot described by
`.punt-labs/ethos/checks/snapshots/postern.yaml`. The snapshot uses a pinned
runtime bundle (Node.js, ShellCheck and the locked markdownlint-cli2 closure
in `tools/handoff-runtime/`) instead of host tools. Install it once per
machine:

```bash
make handoff-runtime
```

This downloads the published bundle for your platform, or rebuilds it from
digest-pinned upstream archives, and installs it only if its SHA-256 matches
the profile's pin. Until it is installed, Ethos defers the handoff checks
with `runtime-missing` and asks you to run the gate yourself.

The bundle is reproducible: `scripts/postern-handoff-runtime release OUT`
rebuilds every pinned platform and fails if any digest moved. To change a
pinned tool, update the script or lock file and print each platform's new
digest with `scripts/postern-handoff-runtime build PLATFORM OUT` (`build`
does not check the old pin). Copy the digests into the profile with a new
`handoff-runtime-vN` URL and a new `epoch`, confirm them with `release`,
and after merge run the Handoff runtime workflow on `main` with that tag to
publish the assets.

## Source Completeness

The image is disposable; all code lives in `src/` in Tonel format.
`make rebuild` stops Pharo, deletes the image, and builds a new one from
`src/`. It must always succeed; if it fails, the source files are
incomplete.

```bash
make rebuild
```

## Other Development Targets

Reload the Tonel packages from `src/` into the running image:

```bash
make filein
```
