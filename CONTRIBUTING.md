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
