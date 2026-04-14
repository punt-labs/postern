# Postern — Pharo 12, 13, 14 compatibility plan

Postern is stable on Pharo 12. This document is the plan for extending
support to Pharo 13 and 14 without forking the product, duplicating
source, or sacrificing maintainability.

## Configuration management stance

| Pattern | Verdict |
|---------|---------|
| Long-lived version branches (`pharo-12`, `pharo-13`, `pharo-14`) | **Rejected** — fixes duplicate three times, branches drift, release engineering becomes "which branch gets v1.0.1?" |
| Parallel packages (`Postern-Core-Pharo12`, `Postern-Core-Pharo13`) | **Rejected** — single history with duplicated source; worst of both worlds |
| Runtime `Smalltalk version` checks inside methods | **Rejected** — anti-pattern in Pharo; scatters version awareness everywhere; breaks "browse the method, see what it does" |
| Shared core + per-version compat shim packages, Metacello `for:` conditionals | **Adopted** |

One `Postern-Core` package, shared across all supported versions. A
small `Postern-Compat-PharoN` package per Pharo version, containing only
the shims that genuinely differ. `BaselineOfPostern` uses Metacello's
`for: #'pharoN.x'` clause to select the right shim package. One `main`
branch. Tagged releases on top.

## Principles

Three disciplines that keep the pattern working. If any of these
erodes, the structure collapses into one of the rejected patterns.

1. **Core passes the "compat stub" test.** Postern-Core is written to a
   consistent internal API (`PosternIcebergCompat>>refreshDirty:`, etc.)
   and never reaches past that API into version-sensitive internals. If
   a Core method calls an Iceberg or Spec2 internal directly, the
   abstraction has leaked — fix the abstraction, do not add a
   conditional.
2. **Compat packages hold only shims.** Extension methods and
   polyfills. Not parallel implementations. If a compat package grows
   past about 15 classes, divergence has gotten too large; consider a
   parallel `Postern-Dashboard-PharoN` for just the offending package,
   or consider dropping support for the older Pharo version.
3. **No `Smalltalk version` checks inside method bodies.** Version
   awareness lives in the `BaselineOfPostern` `for:` clause and nowhere
   else. A runtime branch is a signal that the shim layer is too thin.

## Repository layout

```text
punt-labs/postern/
├── BaselineOfPostern/                    # single baseline with for: conditionals
│   └── BaselineOfPostern.class.st
├── src/
│   ├── Postern-Core/                     # version-neutral. No version checks.
│   ├── Postern-Dashboard/                # Spec2 UI. Mostly version-neutral.
│   ├── Postern-IcebergExtensions/        # Iceberg-facing. Talks to compat, not internals.
│   ├── Postern-Compat-Pharo12/           # Shims loaded on Pharo 12
│   ├── Postern-Compat-Pharo13/           # Shims loaded on Pharo 13 (and 14 unless 14 diverges)
│   └── Postern-Compat-Pharo14/           # Only if Pharo 14 genuinely diverges from 13
└── .github/workflows/
    └── test.yml                          # matrix: [pharo-12, pharo-13, pharo-14]
```

## BaselineOfPostern structure

```smalltalk
baseline: spec
    <baseline>
    spec for: #common do: [
        spec
            package: 'Postern-Core';
            package: 'Postern-Dashboard' with: [ spec requires: 'Postern-Core' ];
            package: 'Postern-IcebergExtensions' with: [ spec requires: 'Postern-Core' ] ].
    spec for: #'pharo12.x' do: [
        spec package: 'Postern-Compat-Pharo12' with: [ spec requires: 'Postern-Core' ] ].
    spec for: #'pharo13.x' do: [
        spec package: 'Postern-Compat-Pharo13' with: [ spec requires: 'Postern-Core' ] ].
    spec for: #'pharo14.x' do: [
        spec package: 'Postern-Compat-Pharo13' with: [ spec requires: 'Postern-Core' ] ]
```

Pharo 14 reuses `Postern-Compat-Pharo13` by default. Only split to
`Postern-Compat-Pharo14` if 14 actually diverges — the common case is
it doesn't, and keeping them shared reduces duplication.

## The compat API

Postern-Core calls a stable internal API that the compat packages
implement per Pharo version. Example pattern:

```smalltalk
"Postern-Core — version-neutral"
self assertDirtyRefreshFor: workingCopy.

"Postern-IcebergExtensions — defines the abstraction"
PosternIcebergCompat class >> refreshDirty: aWorkingCopy
    "Subclasses in Postern-Compat-PharoN override this."
    ^ self subclassResponsibility

"Postern-Compat-Pharo12 — concrete implementation for Pharo 12"
PosternIcebergCompat class >> refreshDirty: aWorkingCopy
    ^ aWorkingCopy refreshDirtyPackages

"Postern-Compat-Pharo13 — concrete implementation for Pharo 13"
PosternIcebergCompat class >> refreshDirty: aWorkingCopy
    ^ aWorkingCopy forceCalculateDirtyPackages
```

The compat class is tiny — it holds only what genuinely differs between
Pharo versions. Core never knows which Pharo it is running on.

Areas that are likely to need shims, based on typical Pharo
version-to-version churn:

| Area | 12 → 13 shim burden | 13 → 14 shim burden |
|------|---------------------|---------------------|
| Zinc HTTP | None expected | None expected |
| STON | None expected | None expected |
| `ZnReadEvalPrintDelegate` | Stable | Stable |
| Spec2 (dashboard presenters) | Light — 2-4 override methods plausible | Usually light |
| Iceberg internals (`IceWorkingCopy`, `IceRepository`) | **Heaviest** — most version churn lives here | Usually moderate |
| Metaclass reflection (`protocolNames`, etc.) | None — we already use current-form selectors | None expected |
| Renraku lint rule set | Not functional — new lints may surface, fix in Core | Same |

## Execution plan

Six PRs, each small and independently reviewable.

### PR 1 — Introduce the compat seam on Pharo 12 only

Still on Pharo 12. No new Pharo version support yet. Goal: when a Pharo
13 image later tries to load, the only code that breaks is one class.

- Create `PosternIcebergCompat` in `Postern-IcebergExtensions`. Class
  methods for every Iceberg internal call Postern-Core or
  Postern-IcebergExtensions makes: `refreshDirty:`, `headCommitOf:`,
  `workingCopyOf:`, etc.
- Find every call in Postern that names a version-sensitive Iceberg
  internal and route it through `PosternIcebergCompat`.
- Do the same audit for `Postern-Dashboard` — move any Spec2 internals
  that are known to shift across Pharo versions (`whenClosedDo:`
  location, any presenter hook rename) behind a `PosternSpec2Compat`
  utility class, even if the current implementation is trivial.
- Pharo 12 implementation is identical to current behavior. Tests stay
  green. No functional change.

Tag: `v1.1.0-compat-seam` (or just merge; the tag is optional).

### PR 2 — Rewrite `BaselineOfPostern` with `for:` conditionals

Still Pharo 12 only.

- Rewrite the baseline to the structure shown in [Baseline structure](#baselineofpostern-structure),
  but with only the `#common` and `#'pharo12.x'` branches populated.
- Create `Postern-Compat-Pharo12`. Move the concrete implementations of
  `PosternIcebergCompat` (and any other compat class) class methods from
  `Postern-IcebergExtensions` into the new compat package. The
  `PosternIcebergCompat` class itself (with its abstract method
  signatures) stays in `Postern-IcebergExtensions`.
- Tests still green on Pharo 12.
- Verify: a Pharo 13 image attempting this baseline currently fails
  because no `for: #'pharo13.x'` branch exists. Expected — PR 3 fixes.

### PR 3 — Add Pharo 13 support

- Build a Pharo 13 image locally.
- Add `spec for: #'pharo13.x'` stanza loading `Postern-Compat-Pharo13`
  (empty placeholder package at first).
- Run the test suite against the Pharo 13 image. Catalog failures —
  that is the shim backlog.
- For each failure: implement the missing method in
  `Postern-Compat-Pharo13`. One method at a time. Re-run tests.
- When tests pass on both Pharo 12 and Pharo 13: done.

Budget: 1-2 review cycles. If the compat package grows past 15 classes,
the divergence has exceeded the shim model — stop and consider either
(a) splitting the offending Postern package (probably Dashboard) into
`Postern-Dashboard-Pharo12` / `Postern-Dashboard-Pharo13`, or (b)
dropping Pharo 12 support entirely and announcing EOL.

### PR 4 — CI matrix on Pharo 12 + Pharo 13

Add to `.github/workflows/test.yml`:

```yaml
strategy:
  matrix:
    pharo: ['12', '13']
  fail-fast: false
```

SmalltalkCI supports both versions natively via `-s Pharo12.0` /
`Pharo13.0`. Red on either cell blocks the PR.

Tag: `v1.1.0`. User-visible install command is unchanged:

```smalltalk
Metacello new
    baseline: 'Postern';
    repository: 'github://punt-labs/postern:main';
    load.
```

Metacello picks the right compat package automatically.

### PR 5 — Add Pharo 14 support

Start optimistic — have `for: #'pharo14.x'` load `Postern-Compat-Pharo13`.

```smalltalk
spec for: #'pharo14.x' do: [
    spec package: 'Postern-Compat-Pharo13' with: [ spec requires: 'Postern-Core' ] ]
```

Run tests on a Pharo 14 image.

- If green: done. Tag `v1.1.1` or include in `v1.2.0` if 14 is
  advertised as a headline feature.
- If red: create `Postern-Compat-Pharo14`, follow the PR 3 pattern for
  the delta. Usually small.

Add `'14'` to the CI matrix.

### PR 6 — README + catalog + release notes

- README supported-versions table:

  ```markdown
  ## Supported Pharo versions

  | Pharo | Status   |
  |-------|----------|
  | 14.x  | Supported |
  | 13.x  | Supported |
  | 12.x  | Supported |
  ```

- Pharo Catalog entry updated to reflect multi-version support.
- Release notes for the tagged release explain the compat pattern so
  downstream users understand how it works.

## Branches

Only one active branch: `main`. No long-lived Pharo-version branches.

A `pharo-12-maintenance` branch only comes into existence if Pharo 12
support is later frozen — meaning `main` has moved on and we are only
applying security + critical-bug fixes to a pinned Pharo 12 version.
That branch is an end-of-life marker, not a development target. It
exists to provide a stable `repository:` URL for users who cannot
upgrade.

## Tagged releases

Semantic versioning on `main`:

- `v1.0.x` — Pharo 12 only (current state as of this plan)
- `v1.1.0` — adds Pharo 13 support
- `v1.1.x` — patch fixes, all Pharo versions
- `v1.2.0` — adds Pharo 14 support (or included in v1.1.x if 14 reuses
  Compat-Pharo13 cleanly)
- `v2.0.0` — reserved for a breaking change (e.g., dropping Pharo 12
  support)

Release description in every tag includes the matrix note: "Tested on
Pharo 12.0.x, 13.0.x, 14.0-alpha" (or whatever is accurate at the time).

## Signals that the structure is breaking down

Four things to watch for. Any of them means the compat-shim pattern has
outgrown its usefulness and the structure should evolve.

1. **Compat package > 20 classes.** Shim layer is too thick. Split the
   offending Postern package (probably Dashboard) into parallel
   per-Pharo packages, or drop the older Pharo version.
2. **Developers find themselves cherry-picking between releases.** A
   sign that informal branching has started. Root-cause it — usually
   means a feature went into `main` that should have been held for the
   next minor version, or a fix needs to be backported via a tagged
   patch release rather than a branch.
3. **Zinc / STON / core HTTP APIs diverge between supported Pharo
   versions.** If Pharo itself breaks its core library compatibility
   that hard, library authors across the ecosystem will be dropping
   old versions — follow the herd, drop the older version rather than
   shim at that depth.
4. **`Smalltalk version` checks start appearing in method bodies during
   review.** A code smell; the compat API has missed a method. Do not
   merge the check — add the missing compat method and route through
   it.

## Summary

| Decision | Rationale |
|----------|-----------|
| Single `main` branch | Single source of truth, one fix lands once |
| Shared `Postern-Core` | DRY; no duplication of stable code |
| Per-version compat shim packages | Isolates version-sensitive code; small blast radius |
| Metacello `for: #'pharoN.x'` conditionals | Canonical Smalltalk mechanism; community expects this pattern |
| CI matrix across all supported versions | Fail-fast detection of regressions on any Pharo |
| Tagged releases on `main` | Clear user-facing version story without branch proliferation |
| EOL-only maintenance branches | Only when a Pharo version is frozen, never for active development |
