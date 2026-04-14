# Postern — ideas for community reach

Postern is a remote HTTP driver for a live Pharo image. The code is stable
and small. This document captures ideas that could extend Postern's reach
into the broader Pharo community — beyond its original role as the driver
for the Claude Agent SDK for Smalltalk.

These are ideas, not commitments. Each one has been thought through but
none has a bead, a PR, or an owner yet. They are recorded here so the
repositioning conversation has a durable artifact to come back to.

## Repositioning — from "our image driver" to "Pharo release tool"

Current framing: Postern is the HTTP server that lets the Claude Agent
SDK drive a Pharo image remotely.

Possible repositioning: Postern is a release engineering tool for Pharo
itself. The Pharo release workflow is largely human-in-the-loop today —
launch a GUI, eyeball a Transcript, click through to verify a load.
Postern flips that to black-box verification anyone can script.

The repositioning is cheap because Postern already has zero Anthropic
dependency. The change is mostly narrative and distribution (catalog
entry, README first paragraph, community outreach) rather than code.

## Target audiences under the new framing

| Audience | Current pain | What Postern offers |
|----------|--------------|---------------------|
| Pharo core release engineer | Build a 13 image, launch GUI, click to verify classes/methods. No automation. | `curl localhost:8422/repl` from a CI script. Headless bring-up verification in seconds. |
| Package maintainer (compat across 12/13/14) | Install library on each Pharo in turn, eye-check tests, hope nothing regressed | Three images up on three ports, one script diffs test results across all three. Regression matrix in one pass. |
| Release QA | Human-driven smoke test: open browser, compile a known class, check it works | Scripted smoke battery hitting `/repl` with known-good evaluations. Automated go/no-go. |
| VM developer | Correlate VM changes to image-level behavior differences | Run identical eval suite against two VMs + same image. Postern's request log (currently a bounded ring buffer) provides a timeline; a future append-only mode could extend this. |
| Agent-driven dev (future) | None — no existing mechanism | LLM agents drive image iteration, compile/test/revert via tool calls. Pharo becomes LLM-native. |

## Endpoint ideas

Three endpoints that would make Postern more useful for release
engineering work, beyond its current `/repl` + `/help` surface.

### `/info` — environment fingerprint

Returns JSON with:

- Pharo version (major.minor.patch)
- VM version and architecture
- Image hash
- List of loaded Metacello baselines with their resolved commits

One request, full environment fingerprint. Makes matrix reporting
trivial — CI stores the `/info` response alongside the test results so
any regression can be correlated to the exact image it was observed on.

### `/smoke` — scripted smoke battery

Takes a spec (list of baselines to load + assertions to run), returns
structured JSON pass/fail. Pharo release team scripts "did 13.1-rc2
load and pass smoke?" as one HTTP call. The spec is declarative so the
caller doesn't need to know Smalltalk internals.

### Pharo-version-aware `/help`

The existing `/help` endpoint documents the API. Extend it to indicate
which endpoints require which Pharo version, so community users running
older Pharo know what's available without reading source.

## Multi-image orchestration

A thin CLI wrapper (working name: `postern-matrix`) that spins up N
Pharo images on different ports, runs the same request against all,
diffs the results. The mechanism exists in Postern already; this is
packaging and convenience. Example shape:

```bash
postern-matrix start --pharo=12,13,14
postern-matrix run "Smalltalk version"
postern-matrix diff --baseline pharo-12
```

Best home for this is probably a separate repo, not inside Postern
itself, to keep Postern's surface area small.

## Bootstrap mode

An endpoint or CLI mode that drives a bare Pharo image through initial
Metacello loads — essentially what `make rebuild` does for the Claude
Agent SDK repo, but generalized and exposed as a Postern feature. Useful
for CI pipelines that want to assemble a known image state before
testing.

## Distribution — making Postern discoverable

| Asset | Purpose |
|-------|---------|
| `punt-labs/postern` repo | Primary code location (current) |
| Pharo Catalog / Iceberg catalog entry | Discoverability. Users find it via `Metacello catalog`. |
| `punt-labs/pharo-ci-matrix` (new repo) | Reference project showing Postern driving Pharo 12 + 13 + 14 matrix CI. GitHub Actions workflow other projects can copy. |
| ESUG talk | "Headless Pharo release engineering with Postern." ESUG audience includes the people who would use this. |
| Discord / mailing list announcement | Timed to a Pharo GA or alpha release, depending on Pharo's own cadence. |

## Principles to preserve

Three disciplines that keep the repositioning credible, in order of
priority:

1. **Postern stays tiny and stable.** If Postern becomes a kitchen sink,
   the Pharo core team will not trust it for release work. Surface area
   stays small — HTTP + eval + introspection + `/help` plus a couple of
   new endpoints. Everything bigger (CI matrix, smoke batteries,
   orchestration) lives in separate companion projects that depend on
   Postern.
2. **Zero Anthropic surface, visible.** Postern already has zero Claude
   dependency. Double down on that framing. README first paragraph makes
   the neutrality explicit. Community needs to trust this as neutral
   infrastructure, not "that thing the Claude SDK people ship."
3. **Pharo core team gets a path to adopt it.** Stated willingness to
   hand the repo over to the Pharo org, if they want ownership,
   removes hesitation on their side up front.

## Lowest-risk first step (if we pursue the repositioning)

Create `punt-labs/pharo-ci-matrix` as a public demonstration:

- GitHub Actions workflow that spins up Pharo 12, 13, 14 images
- Uses Postern to drive each through the same test suite
- Outputs a pass/fail matrix as a PR comment
- README explains the pattern so other package authors can copy it

Concrete, visible use of Postern serving the community. Once it exists,
catalog entry + Discord post + ESUG talk build on top of it. If the
Pharo core team sees value, organic adoption follows without lobbying.

## Status

None of these ideas are committed to. Multi-Pharo-version support for
Postern itself (the prerequisite for most of this) is being planned
separately; see the docs for the `pharo-13-14-support` effort when it
lands.
