"
Holds the content for the /help endpoint of a Postern image. All
methods are class-side string methods returning Markdown documents.
The endpoint itself is routed by PosternDelegate>>handleHelpRequest:
which dispatches via PosternHelp class >> sectionFor: aPathSegment.

10 sections are authored: api, browse, makefile, pharo, lint,
dispatch, git, testing, safety, lessons. Each returns a standalone Markdown document
an external agent fetches via GET /help/<section>.

Drift-detection tests in PosternHelpTest verify that every code fence
parses, every referenced selector exists, every referenced project
class exists, and the Pharo version pin matches the running image.

### Examples

```
PosternHelp tableOfContents class
>>> ByteString
```

```
(PosternHelp sectionFor: 'api') size > 1000
>>> true
```

```
PosternHelp sectionFor: 'nonsense'
>>> nil
```

"
Class {
	#name : 'PosternHelp',
	#superclass : 'Object',
	#category : 'Postern-Core',
	#package : 'Postern-Core'
}

{ #category : 'help content' }
PosternHelp class >> api [
	"The eval server HTTP protocol: endpoints, content types, auth, examples."
	^ '# /help/api — Eval Server Protocol

## Overview

Postern exposes a live Pharo 12 image as an HTTP REPL on
`localhost:8422`. POST a Smalltalk expression, get back the
`printString` of the result.

## Endpoints

### POST /repl

Evaluate a Smalltalk expression and return the result.

- **Method**: POST
- **Content-Type**: `text/plain`
- **Body**: A Smalltalk expression (UTF-8, LF line endings)
- **Response**: The `printString` of the evaluation result
- **Auth**: `X-Eval-Token` header required when auth is enabled

The server normalizes LF to CR before evaluation. Pharo''s compiler
expects CR line endings internally. You send LF (the POSIX default);
the server handles the conversion.

```bash
# Simple expression
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "3 + 4"
# => 7

# Multi-line expression (LF is fine — server converts to CR)
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "| x |
x := 42.
x factorial"
# => 1405006117752879898543142606244511569936384000000000

# Define a class
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "(Object << #MyClass slots: { #name }; package: ''MyPackage'') install"

# Compile a method
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "MyClass compile: ''name ^ name'' classified: ''accessing''"

# Run tests
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "MyClassTest buildSuite run"
```

### GET /health

Returns `ok` (text/plain) with HTTP 200. No auth required.
Use this to check if the server is alive.

```bash
curl -s http://localhost:8422/health
# => ok
```

### GET /help

Returns the help table of contents (text/markdown). No auth required.

```bash
curl -s http://localhost:8422/help
```

### GET /help/{section}

Returns a specific help section (text/markdown). No auth required.
Returns 404 if the section name is unknown.

Valid sections: `api`, `browse`, `makefile`, `pharo`, `lint`,
`dispatch`, `git`, `testing`, `safety`, `lessons`.

```bash
curl -s http://localhost:8422/help/api
curl -s http://localhost:8422/help/safety
```

## Authentication

Auth is optional. When enabled, every `/repl` request must include
the `X-Eval-Token` header with the correct token. `/health` and
`/help` are exempt from auth — they work without a token.

The default local startup path (`PosternServer startOn:`, `make start`,
or `make start-headless`) does **not** enable auth. When auth is enabled,
it only checks whether
the caller has the shared token. It does not sandbox evaluation, limit
what code can do, or provide separate read-only and write permissions.
Any client that can call `/repl` successfully can run normal Smalltalk
code in the image.

```bash
# With auth enabled
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -H "X-Eval-Token: a1b2c3d4" \
  -d "1 + 1"
```

When the server starts with auth (`PosternServer startOn: 8422
withAuth: true`), it generates an 8-character hex token and writes
it to `.tmp/eval-token`. Read that file and add the `X-Eval-Token`
header explicitly in your client requests. The default `make start`
and `make start-headless` targets do not enable auth.

An unauthenticated request to `/repl` returns HTTP 401.

## Error Shape

Evaluation errors return HTTP 200 with the error description as
the response body. The server does not use HTTP error codes for
Smalltalk evaluation failures — only for protocol-level issues.

```bash
# Evaluation error (HTTP 200, error in body)
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "1 / 0"
# => ZeroDivide

# Unknown help section (HTTP 404)
curl -s http://localhost:8422/help/nonexistent
# => /help has no section "nonexistent"

# Missing auth (HTTP 401)
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "1 + 1"
# => (empty body, 401 status)
```

## Line Ending Convention

- **Input (you → server)**: Send LF. The server converts LF to CR
  before passing to the Pharo compiler.
- **Output (server → you)**: `/repl` returns whatever `printString`
  produces (usually CR). `/help` sections return LF — the server
  normalizes CR to LF at the HTTP boundary for Markdown responses.

## Server Lifecycle

```smalltalk
"Start without auth"
PosternServer startOn: 8422.

"Start with auth (token written to .tmp/eval-token)"
PosternServer startOn: 8422 withAuth: true.

"From the CLI"
make start    "starts on port 8422"
make stop     "kills the VM — does NOT save the image"
```

## Key Classes

- `PosternServer` — factory that creates and starts the ZnServer
- `PosternDelegate` — the Zn delegate that normalizes LF→CR and
  dispatches /health, /help, and /repl
- `PosternHelp` — class-side methods returning help section content
- `PosternImageBrowser` — introspection facade for browsing classes,
  methods, senders, implementors, and code search from outside
'
]

{ #category : 'help content' }
PosternHelp class >> browse [
	"Read-only introspection patterns for external agents."
	^ '# /help/browse — Read-Only Image Introspection

## Overview

Use this section when you need to understand the loaded image without
changing it. The goal is fast orientation: classes, selectors,
implementors, senders, and source lookups.

For read-only work:

- Prefer `GET /help/*` and `POST /repl` expressions that query state.
- Avoid `compile:classified:`, class installation, refactorings, or
  anything that mutates classes.
- Keep expressions focused and inspect one thing per request.

## Basic Introspection

```bash
# List Postern packages currently loaded
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "(RPackageOrganizer default packages
    collect: [ :p | p name ]) select: [ :n | n beginsWith: ''Postern-'' ]"
```

```bash
# List classes in a package
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "((Smalltalk globals allClasses
    select: [ :c | c package name = ''Postern-Dashboard'' ])
    collect: #name) sorted"
```

```bash
# Read class comment and protocols
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "PosternDashboard comment"
```

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "PosternDashboard protocolNames"
```

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "PosternDashboard class protocolNames"
```

## Selector and Source Lookup

```bash
# Implementors of a selector
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "(SystemNavigation default allImplementorsOf: #sectionFor:)
    collect: [ :m | m methodClass name -> m selector ]"
```

```bash
# Senders of a selector
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "(SystemNavigation default allSendersOf: #refreshLogTable)
    collect: [ :m | m methodClass name -> m selector ]"
```

```bash
# Fetch exact method source
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "(PosternHelp class >> #tableOfContents) sourceCode"
```

## Using `PosternImageBrowser`

`PosternImageBrowser` provides a query facade oriented to external
tools. Use it for concise summaries before drilling into raw source.

```bash
# Class summary
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "PosternImageBrowser browseClass: ''PosternDashboard''"
```

```bash
# Method summary
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "PosternImageBrowser browseMethod: ''PosternDashboard'' selector: ''refreshLogTable''"
```

```bash
# References and implementors
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "PosternImageBrowser sendersOf: #sectionFor:"
```

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "PosternImageBrowser implementorsOf: #sectionFor:"
```

## Read-Only Checklist

Before reporting architecture or behavior:

1. Confirm package and class names from the running image.
2. Confirm selectors with implementors/senders (no guessing).
3. Quote behavior from method source when precision matters.
4. Avoid touching mutable APIs unless the task explicitly asks for edits.
'
]

{ #category : 'help content' }
PosternHelp class >> dispatch [
	"How to dispatch a kwb-style sub-agent: template, TDD cycle, gates."
	^ '# /help/dispatch — Delegating to a Sub-Agent

## Overview

All Smalltalk implementation in this image goes through a sub-agent
(kwb). Every dispatch follows a mandatory template. Skipping steps
has historically produced multi-round review cycles.

## The Dispatch Template

Every sub-agent spec must include:

### 1. Eval Server Pattern

```bash
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "EXPRESSION"
```

Each call is exactly ONE curl command. No chaining.

### 2. Class Definition (Fluid Syntax)

```smalltalk
(Object << #MyClass
  slots: { #name };
  package: ''MyPackage'') install.
```

Never the deprecated `subclass:instanceVariableNames:` form.

### 3. Method Compilation

```smalltalk
MyClass compile: ''name ^ name'' classified: ''accessing''.
```

Always `compile:classified:`. Never bare `compile:`.

### 4. TDD Cycle

For each class:

1. Define test class
2. Compile test methods — they should FAIL
3. Define production class
4. Compile production methods
5. Run tests — they should PASS
6. Run `make lint` — should be clean
7. Repeat

### 5. Lint Gate

```bash
make lint 2>&1 | grep -v '': clean$'' | grep -v ''^$''
# Must produce empty output
```

`make lint` from the CLI. Not per-method `m critiques`. See
`/help/lint` for why.

### 6. Iceberg Commit

```smalltalk
| repo |
repo := IceRepository registry
  detect: [ :r | r name = ''claude-agent-sdk-smalltalk'' ].
repo workingCopy refreshDirtyPackages.
repo workingCopy commitWithMessage: ''feat: description''.
```

Always `refreshDirtyPackages` before commit.

## Required Spec Elements

Every dispatch spec must include:

1. **The lint gate as `make lint`** (CLI, not per-method probe)
2. **The test gate** as specific `MyTest buildSuite run` invocations
3. **The Iceberg commit instruction** with `refreshDirtyPackages`
4. **An out-of-scope list** — what NOT to touch
5. **Stop conditions** — when to halt and report instead of pushing
   through
6. **Success criteria** with specific probe results expected

## Anti-Patterns That Cost Rounds

- **Per-method `m critiques` as the lint gate** — misses class-level
  rules. This caused 7 rounds on a single bead (2026-04-07 COE).
- **Inventing a new spec structure each time** — produces
  inconsistent gates and missed steps. Use the template.
- **Dispatching without reading existing source** — produces specs
  that name selectors or classes that do not exist.
- **Adding tests for a smell instead of removing the smell** — the
  test papers over the problem.
- **Running review cycles when the spec was wrong** — fix the spec,
  not the symptom.

## Post-Dispatch Verification

After the sub-agent reports back:

1. **Cross-check with `make lint` from CLI.** Do not trust the
   sub-agent''s own probe.
2. **Read the diff.** `git diff <prior>..<new>` end-to-end.
3. **Verify Iceberg ref sync** if any CLI git ops happened.

## JSON Serialization Pattern

When the spec involves classes with JSON serialization:

```smalltalk
"No reflection. Explicit accessors."
asJson
  | dict |
  dict := OrderedDictionary new.
  name ifNotNil: [ dict at: ''name'' put: name ].
  ^ dict

MyClass class >> fromJson: aDictionary
  ^ self new
    name: (aDictionary at: ''name'' ifAbsent: [ nil ]);
    yourself
```

## Verify Clean Source

After all methods are compiled, verify no LF in source:

```smalltalk
MyClass methods allSatisfy: [ :m |
  (m sourceCode includesSubstring:
    (String with: Character lf)) not ]
"Must return true"
```
'
]

{ #category : 'version' }
PosternHelp class >> expectedPharoVersion [
	"The Pharo version these help sections were authored against.
	When the image is upgraded, this test fails, forcing a review
	of the help content."
	^ 'Pharo-12.0.0'
]

{ #category : 'help content' }
PosternHelp class >> git [
	"Iceberg for Tonel commits, CLI for merges, package completeness."
	^ '# /help/git — Git and Iceberg Integration

## Overview

This repository uses Iceberg (Pharo''s libgit2 binding) for commits
and pushes. Merges are done from the CLI. SSH uses an ed25519 key.

## Iceberg for Tonel Commits

Iceberg writes Smalltalk packages to Tonel format files under `src/`.
Use Iceberg for commits that touch Smalltalk code.

```smalltalk
"Get the repository"
| repo |
repo := IceRepository registry
  detect: [ :r | r name = ''claude-agent-sdk-smalltalk'' ]
  ifNone: [ self error: ''Repository not registered'' ].

"Refresh dirty packages (REQUIRED before commit)"
repo workingCopy refreshDirtyPackages.

"Commit"
repo workingCopy commitWithMessage: ''fix: something''.
```

### Why `refreshDirtyPackages` is Required

Without `refreshDirtyPackages`, `commitWithMessage:` silently
no-ops on working copies that Monticello has not refreshed. The
commit appears to succeed but no commit is actually created.
Always call it before committing.

## CLI for Merges

Iceberg handles commit and push. Use the CLI for merges, rebases,
and branch operations:

```bash
git merge main
git rebase main
git checkout -b feature/my-branch
```

## Syncing After CLI Commits

If you make a commit from the CLI (e.g., `git commit` from bash)
on the same branch Iceberg is tracking, sync the reference commit:

```smalltalk
| repo |
repo := IceRepository registry
  detect: [ :r | r name = ''claude-agent-sdk-smalltalk'' ].
repo workingCopy referenceCommit: repo head commit.
```

Without this, Iceberg shows stale state and subsequent commits
may fail or diverge.

## Package Completeness Validation

Before committing via Iceberg, verify all expected packages are
loaded in the image. If a package is missing, Iceberg interprets
its Tonel files as "deleted" and commits the deletion.

This happened on 2026-04-06: two packages were deleted from the
repository because they were not loaded in the image when an
Iceberg commit ran.

### How to check

```smalltalk
"List packages on disk"
| srcDir expected |
srcDir := FileSystem disk workingDirectory / ''src''.
expected := (srcDir directories
  select: [ :d | (d / ''package.st'') exists ]
  thenCollect: [ :d | d basename ]) asArray.

"List packages in image"
| loaded |
loaded := RPackageOrganizer default packages
  collect: [ :p | p name ].

"Find missing"
| missing |
missing := expected reject: [ :name | loaded includes: name ].
missing isEmpty
  ifTrue: [ ''All packages loaded'' ]
  ifFalse: [ ''MISSING: '', ('', '' join: missing) ]
```

### The `make check` target

```bash
make check
```

This verifies both package completeness and Iceberg working copy
cleanliness in one command.

## Iceberg Commit Discipline

1. `refreshDirtyPackages` before every commit
2. Verify package completeness (no missing packages)
3. Check the dirty package count — if more packages are dirty
   than you expect, investigate before committing
4. After CLI operations on the same branch, sync `referenceCommit`

## Inspecting Working Copy State

```smalltalk
| repo |
repo := IceRepository registry
  detect: [ :r | r name = ''claude-agent-sdk-smalltalk'' ].

"Check if clean"
repo workingCopyDiff isEmpty.
# => true (clean) or false (dirty)

"See what changed"
repo workingCopy refreshDirtyPackages.
repo workingCopy changes.
```
'
]

{ #category : 'help content' }
PosternHelp class >> lessons [
	"Distilled lessons from COEs: cascade, process failure, package deletion, rename."
	^ '# /help/lessons — Lessons from Incidents

## Overview

Four incidents shaped the safety rules in this image. Each produced
mechanizations that prevent recurrence. Understanding the incidents
explains why the rules exist.

## Incident 1: Dashboard Cascade (2026-04-06)

### What happened

An agent built a Spec2 dashboard with methods referencing an
undeclared instance variable (`server`). Pharo accepted the methods
at compile time (undeclared variables become globals). The agent
also created a request logger that subscribed to
`ZnLogEvent announcer` without unsubscribing on window close.

Across the session, 14 leaked logger instances accumulated. When
a request arrived, all 14 fired, hit the nil model bug, and spawned
63 debugger windows in seconds. The user accidentally closed the
workbench window while trying to dismiss debuggers, losing the
conversation.

### Root causes

1. Methods referenced undeclared state — `m critiques` would have
   caught this immediately but was never run
2. No subscription lifecycle management — `whenClosedDo:` was not
   used to unsubscribe on window close
3. No instance limit — 14 loggers subscribed to the same announcer
4. No debugger storm detection — Pharo opens unlimited debuggers

### Mechanizations

- **Lint after compile**: Run `m critiques` after compiling methods
  that reference state. Undeclared variables surface immediately.
- **Subscription cleanup**: Any presenter that subscribes to a
  global announcer must register a `whenClosedDo:` block that
  unsubscribes.
- **Singleton enforcement**: Resources that should be unique (one
  logger per server) use a class-side singleton pattern.

## Incident 2: Process Failure — 7 Rounds (2026-04-07)

### What happened

A single bead took 7 dispatch rounds and 11 commits where 1-3
should have sufficed. Every round reported "lint zero" using
per-method `m critiques` probes. The probes missed class-level
Renraku rules (unused instance variables, excessive variables).
When `make lint` was finally run from the CLI, it found 12
findings the entire session had been hiding.

### Root causes

1. Per-method `m critiques` was used as the lint gate — it misses
   class-level rules entirely
2. The dispatch template was not read — specs were invented from
   scratch each round
3. The kwb agent definition had been silently stripped of its
   safety rules section by a prior sub-agent

### Mechanizations

- **`make lint` is the only gate**: Per-method probes are debugging
  tools. The canonical lint check is `make lint` from the CLI.
- **Two-pass discipline**: Author runs `make lint` after each class.
  Reviewer runs `make lint` independently before merge.
- **Verify agent definition before dispatch**: Run
  `git diff .claude/agents/kwb.md` before dispatching. If the file
  has been modified, restore from HEAD.

## Incident 3: Iceberg Package Deletion (2026-04-06)

### What happened

A `LibC resultOfCommand: ''make lint''` call from inside the VM
created a circular dependency (see `/help/safety`). The VM hung.
After killing the VM, an orphan subprocess held port 8422. A new
image was started from an old image file that predated two packages.
An Iceberg commit then ran against this incomplete image. Iceberg
interpreted the missing packages as deleted and committed the
deletion.

### Root causes

1. LibC subprocess called back into the eval server — deadlock
2. `make filein` had a hardcoded package list that missed new
   packages
3. Iceberg commit did not validate package completeness

### Mechanizations

- **No LibC subprocess that contacts the eval server** (see
  `/help/safety`)
- **Auto-discovered package loading**: `make filein` now scans
  `src/` for directories containing `package.st`
- **Package completeness validation**: Before committing, verify
  all expected packages are loaded. `make check` does this
  automatically.

## Incident 4: Rename Method Cascade (2026-04-08)

### What happened

An agent renamed `TTTBoardMorph>>#model` to `#game` using
`RBRenameMethodRefactoring` without passing an explicit scope.
The refactoring defaulted to system-wide scope and renamed every
`#model` method and every sender of `#model` across the entire
image — 97 non-project classes across 35 Pharo system packages,
rewriting 1,336 send sites.

The image was internally consistent (all definitions and senders
matched), so tests continued passing. The cascade was only
discovered when an Iceberg commit pulled in 10 files instead of
the expected 3.

### Root causes

1. `RBRenameMethodRefactoring` defaults to system-wide scope —
   the `in: aClass` parameter only identifies the starting class,
   not the scope
2. The tool wrapper did not pass an `RBBrowserEnvironment` to
   limit the scope
3. No blast-radius check was performed after the refactoring

### Mechanizations

- **Always scope refactorings explicitly**:

```smalltalk
| scope refactoring |
scope := RBBrowserEnvironment new
  forPackageNames: { MyClass package name }.
refactoring := RBRenameMethodRefactoring
  renameMethod: #oldSelector
  in: MyClass
  to: #newSelector
  permutation: #(1).
refactoring model: (RBNamespace onEnvironment: scope).
refactoring execute.
```

- **Post-refactor blast radius check**: After any RB refactoring,
  verify implementor and sender counts changed by the expected
  amount. If `oldSelectorCallers` dropped to near zero for a
  common selector, the refactoring cascaded. Stop and undo.
- **Iceberg dirty package count as backstop**: Before committing,
  check how many packages are dirty. If more than expected,
  investigate.
- **Undo via RB**: `RBRefactoryChangeManager default undoOperation`
  reverses the last refactoring atomically.

## Common Thread

Every incident shares the same pattern: **a tool that silently
succeeds when it should have warned or failed.** The compiler
accepts undeclared variables. The lint probe misses class-level
rules. Iceberg commits incomplete state. The refactoring engine
rewrites the entire image without asking.

The mechanizations all follow the same counter-pattern: **make
the tool fail loud at the point of error, not silently downstream.**
Lint gates, package completeness checks, blast-radius probes,
subscription cleanup — each one converts a silent success into
an immediate, actionable signal.
'
]

{ #category : 'help content' }
PosternHelp class >> lint [
	"Lint discipline: make lint is the gate, not per-method critiques."
	^ '# /help/lint — Lint Discipline

## The Rule

**`make lint` from the CLI is the only lint gate.** Run it before
every commit. Zero findings required.

```bash
make lint 2>&1 | grep -v '': clean$'' | grep -v ''^$''
# Expected output: nothing (empty = clean)
```

If any line remains after filtering, the lint is dirty. Fix every
finding before committing.

## Why `make lint` and Not Per-Method Critiques

Renraku (Pharo''s lint engine) has two layers of rules:

### Per-method rules (caught by `m critiques`)
- Empty exception handler
- Unnecessary `= true`
- Uses of `isKindOf:`
- Long methods
- Sends deprecated messages

### Class-level rules (ONLY caught by `make lint`)
- Unused instance variable
- Instance variable not read or not written
- Excessive number of variables
- Excessive number of methods
- Class not referenced
- Sends different super message

**`(MyClass >> #myMethod) critiques` does NOT see class-level
rules.** A per-method probe will report zero findings while the
class has unused instance variables, excessive slots, or other
class-level smells.

This is not theoretical. On 2026-04-07, seven dispatch rounds
reported "lint zero" using per-method probes while 12 class-level
findings were silently accumulating. The canonical `make lint`
target caught all of them when finally run.

## Per-Method Critiques as a Debugging Tool

Per-method critiques are useful for investigating a specific
finding after `make lint` has identified it:

```smalltalk
"OK — diving into a specific finding"
(MyClass >> #specificMethod) critiques.

"OK — checking a class for class-level rules"
MyClass critiques.
```

These are debugging tools, not gates. The gate is `make lint`.

## False Positives

If a finding is a documented false positive, suppress it via a
package `Manifest` class. Do not ignore it silently.

```smalltalk
"Example: ManifestPosternCore in Postern-Core package"
(PackageManifest << #ManifestPosternCore
  package: ''Postern-Core'') install.
ManifestPosternCore class compile:
  ''ruleExcessiveVariablesRuleV1FalsePositive ^ #()''
  classified: ''code-critics''.
```

Existing manifest in this image: `ManifestPosternCore`.

## The Two-Pass Discipline

1. **Author pass**: After completing each class, run `make lint`
   from the CLI. Fix every finding before moving to the next class.
2. **Reviewer pass**: Before merge, run `make lint` independently.
   Cross-check against the author''s claim.

Both passes use `make lint`. Neither uses per-method probes as
the gate.

## Safety Note

`make lint` must be run from the CLI (Bash tool), NOT from inside
the VM via `LibC resultOfCommand:`. Running `make lint` from inside
the VM creates a circular dependency that deadlocks. See
`/help/safety` for details.'
]

{ #category : 'help content' }
PosternHelp class >> makefile [
	"Disposable image discipline and make targets."
	^ '# /help/makefile — Image Lifecycle and Make Targets

## Disposable Image Discipline

The Pharo image is disposable. All code lives in `src/` as Tonel
format files. The image is a workspace you rebuild from source —
never a precious artifact you protect.

This means:

- **`make rebuild` is the recovery path.** Corrupted image? Rebuild.
  Unknown state? Rebuild. Weird errors after a crash? Rebuild.
- **`make stop` does NOT save the image.** Saving captures socket
  state and process references that break on restore.
- **Never commit the image.** `pharo/` is gitignored. Only `src/`
  is committed.

## Make Targets

### Setup and Lifecycle

| Target | What it does |
|--------|-------------|
| `make` / `make help` | Show the available make targets |
| `make setup` | Download Pharo VM + image, load all Tonel packages from `src/` |
| `make start` | Start Postern with the Pharo GUI on port 8422 |
| `make start-headless` | Start Postern headlessly on port 8422 |
| `make start-ui` | Alias for `make start` |
| `make stop` | Kill the VM (does NOT save). Cleans up orphan processes |
| `make rebuild` | `stop` + clean image + `setup`. Fresh image from scratch |

### Development

| Target | What it does |
|--------|-------------|
| `make filein` | Reload all Tonel packages into the running image |
| `make eval` | Interactive Smalltalk eval (type expression, Ctrl-D to send) |
| `make test` | Run all project test suites |
| `make lint` | Lint all project classes (the canonical lint gate) |
| `make status` | Health check: confirms server is alive, reports class count |
| `make check` | Verify all packages loaded + Iceberg working copy clean |
| `make transcript` | Read the Pharo Transcript output |

### Cleanup

| Target | What it does |
|--------|-------------|
| `make clean` | Remove image, VM, PID file, logs — full reset |
| `make clean-image` | Remove the image, logs, setup state, and repo-local runtime home |

## Launch Mode

`make` with no target defaults to `make help`.

`make start` is the default visual workflow and launches the Pharo
GUI on macOS and Linux desktop sessions.

`make start-headless` is the terminal/CI path.

`make start-ui` is an alias for `make start`.

Any target can override the default port, for example:

```bash
make PORT=8432 start-headless
```

If port 8422 is already occupied, the start targets fail fast instead
of silently attaching to an existing listener.

On Linux, `make start` requires an active `DISPLAY` or
`WAYLAND_DISPLAY` session. Use `make start-headless` if no GUI
session is available.

## Typical Workflows

### First time setup

```bash
make          # shows available targets
make setup    # downloads VM + image, loads packages
make start    # starts Postern with the GUI on :8422
make status   # confirms it is alive
```

### Daily development

```bash
make start    # if not already running
make test     # run tests
make lint     # check lint
make stop     # when done
```

### After editing Tonel files on disk

```bash
make filein   # reload packages into running image
make test     # verify
```

### Recovery from any problem

```bash
make rebuild  # nuclear option — always works
make start
```

## Package Loading

`make setup` and `make filein` auto-discover all packages under
`src/` by looking for directories containing `package.st`. Packages
load in dependency order using a priority map:

1. `Postern-Core`
2. `Postern-Dashboard` and `Postern-IcebergExtensions`
3. `BaselineOfPostern`
4. `*-Tests` packages (loaded last)

After loading, the loader normalizes any LF line endings in method
source to CR (Pharo''s internal convention).

If Pharo cannot write to its usual user config directory during
`make setup` (for example in a restricted agent sandbox), Postern
falls back to a repo-local runtime home under `.tmp/pharo-home`.
`make clean-image` and `make clean` remove that fallback directory.

## Port

The default port is 8422. It is hardcoded in the Makefile as the
`PORT` variable. All make targets use this port.
'
]

{ #category : 'help content' }
PosternHelp class >> pharo [
	"Pharo 12 coding standards enforced in this image."
	^ '# /help/pharo — Pharo 12 Standards

## Class Definition (Fluid Syntax)

Pharo 12 uses the fluid class definition syntax. The old
`subclass:instanceVariableNames:classVariableNames:package:` is
deprecated and must not be used.

```smalltalk
"Production class"
(Object << #MyClass
  slots: { #name. #age };
  package: ''MyPackage'') install.

"Subclass"
(MyClass << #MySubclass
  slots: { #extra };
  package: ''MyPackage'') install.

"Test class"
(TestCase << #MyClassTest
  slots: {};
  package: ''MyPackage-Tests'') install.
```

## Method Compilation

Always use `compile:classified:` — never bare `compile:`.

```smalltalk
MyClass compile: ''name
  ^ name'' classified: ''accessing''.

MyClass compile: ''name: aString
  name := aString'' classified: ''accessing''.
```

The `classified:` argument is the protocol name. Every method must
be in a named protocol. No `as yet unclassified`.

## Protocols

| Protocol | What goes in it |
|----------|----------------|
| `accessing` | Getters and setters |
| `initialization` | `initialize` and setup methods |
| `json` | `asJson`, `fromJson:`, `jsonKeyMap` |
| `testing` | Boolean queries (`isEmpty`, `isValid`) |
| `tests` | Test methods (`test*`) in TestCase subclasses |
| `printing` | `printOn:` |
| `instance creation` | Class-side constructors |
| `converting` | Type conversion methods |
| `private` | Internal implementation details |

## JSON Serialization Pattern

No reflection. Each class implements `asJson`/`fromJson:` with
explicit accessors. `jsonKeyMap` documents the wire-name mapping.

```smalltalk
"Instance side — protocol: json"
asJson
  | dict |
  dict := OrderedDictionary new.
  name ifNotNil: [ dict at: ''name'' put: name ].
  age ifNotNil: [ dict at: ''age'' put: age ].
  ^ dict

"Class side — protocol: json"
MyClass class >> fromJson: aDictionary
  ^ self new
    name: (aDictionary at: ''name'' ifAbsent: [ nil ]);
    age: (aDictionary at: ''age'' ifAbsent: [ nil ]);
    yourself

"Class side — protocol: json"
MyClass class >> jsonKeyMap
  ^ {
    #name -> ''name''.
    #age -> ''age''
  } asDictionary
```

Wire keys are snake_case. Smalltalk accessors are camelCase. The
`jsonKeyMap` documents the mapping and is used by tests.

## Class Comments

Every class must have a comment. Comments must include at least one
runnable example using the `>>>` doc comment convention:

```smalltalk
"A person with a name and age.

  MyClass new name: ''Alice''; age: 30
  >>> a MyClass

  MyClass new name: ''Alice''; name
  >>> ''Alice''
"
```

A class without a runnable example in its comment is incomplete.

## Deprecated APIs

| Deprecated | Use instead |
|-----------|-------------|
| `subclass:instanceVariableNames:...` | `<< #Name slots: {...}; package: ''...''` |
| `compile:` | `compile:classified:` |
| `cls organization categories` | `cls protocolNames` |
| `cls organization listAtCategoryNamed:` | `cls selectorsInProtocol:` |
| `ref actualClass` | `ref methodClass` |
| `FileStream fileIn:` | `CodeImporter evaluateFileNamed:` |
| `Compiler evaluate:` | `self class compiler evaluate:` |

## Line Endings

Pharo uses CR internally. External tools (curl, editors) use LF.
The eval server converts LF to CR on input. When writing Smalltalk
strings that contain line breaks, use `String cr` or embed literal
CR characters. The `/help` endpoint converts CR back to LF for
HTTP responses.

## Naming Conventions

- **Classes**: descriptive, CamelCase. Domain prefix for product
  classes (e.g., `Claude*`, `Postern*`).
- **Methods**: intention-revealing per Kent Beck. `sendMessage:` not
  `postToMessagesEndpoint:`. `textContent` not
  `collectTextBlocksAndJoin`.
- **Packages**: `Family-SubFamily-Module` (e.g., `Postern-Core`,
  `Claude-SDK-Types`). Test packages end with `-Tests`.
'
]

{ #category : 'help content' }
PosternHelp class >> safety [
	"LibC subprocess deadlock and image safety rules."
	^ '# /help/safety — LibC Deadlock and Image Safety

## Security Warning

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

## The LibC Self-Call Deadlock

The most dangerous thing you can do from inside the Pharo VM is
spawn a subprocess that calls back into the eval server.

### The failure mode

```
1. Smalltalk code calls LibC resultOfCommand: ''make lint''
2. make lint spawns a subprocess that curls localhost:8422/repl
3. The subprocess sends an HTTP request to the eval server
4. The eval server cannot respond — the VM is blocked waiting
   for LibC resultOfCommand: to return
5. The subprocess waits for the HTTP response
6. Deadlock: VM waits for subprocess, subprocess waits for VM
7. The VM hangs ("not responding")
8. If you kill the VM, the subprocess survives as an orphan
   holding port 8422
9. make start fails because the port is occupied
10. You must find and kill the orphan process manually
```

This happened on 2026-04-06. The orphan subprocess held port 8422,
preventing restart. The recovery required manual process hunting.

### Safe from inside the VM (LibC does NOT contact the eval server)

```smalltalk
LibC resultOfCommand: ''git status''.
LibC resultOfCommand: ''git add src/''.
LibC resultOfCommand: ''git commit -m "fix: something"''.
LibC resultOfCommand: ''ls -la''.
LibC resultOfCommand: ''cat some-file.txt''.
```

### UNSAFE from inside the VM (subprocess calls back to eval server)

```smalltalk
"ALL OF THESE DEADLOCK:"
LibC resultOfCommand: ''make lint''.
LibC resultOfCommand: ''make test''.
LibC resultOfCommand: ''make status''.
LibC resultOfCommand: ''make filein''.
LibC resultOfCommand: ''curl localhost:8422/repl -d "1+1"''.
```

### Safe alternatives from inside the VM

```smalltalk
"Run tests (instead of make test)"
MyClassTest buildSuite run.

"Run lint on a specific method (instead of make lint)"
(MyClass >> #myMethod) critiques.

"Run lint on a class"
MyClass critiques.
```

### From the CLI (Bash tool) — everything is safe

When you run commands from the CLI (not from inside the VM via
LibC), there is no circular dependency. The CLI process and the
VM are separate OS processes.

```bash
# All safe from CLI:
make lint
make test
make status
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" -d "1 + 1"
```

The rule is: **no LibC subprocess that calls back into the VM.**
It is NOT "never run make." `make lint` from the Bash tool is the
canonical lint gate.

## Image Discipline

The Pharo image is disposable. All code lives in `src/` as Tonel
files. The image is a workspace, not a repository.

### Key rules

1. **`make rebuild` must always work.** If it fails, the Tonel
   source files are incomplete. Fix the source, not the image.
2. **`make stop` does NOT save the image.** Saving captures socket
   state, file handles, and process references that cause errors
   on restore. The image is rebuilt from source, not restored.
3. **Never commit the Pharo image or VM.** The `pharo/` directory
   is gitignored. Only Tonel files under `src/` are committed.
4. **`make rebuild` is the recovery path.** If the image is
   corrupted, polluted, or in an unknown state, rebuild it.
   Do not try to repair a broken image.

## Orphan Process Recovery

If the VM hangs and you kill it, check for orphan processes:

```bash
# Find orphan Pharo processes
pgrep -x pharo

# Kill them
kill <pid>

# If that doesn''t work
kill -9 <pid>

# Verify port 8422 is free
lsof -i :8422

# Then restart
make start
```

`make stop` already handles orphan cleanup — it kills the main
process and then sweeps for any remaining `pharo` processes.
'
]

{ #category : 'dispatching' }
PosternHelp class >> sectionFor: aPathSegment [
	"Return the Markdown body for /help/<aPathSegment>, or nil if unknown.
	The section table is a literal Dictionary of {segment name -> 0-arg
	block returning the content}. Only segments in the table are served."
	| segment block |
	segment := [ aPathSegment asString ] on: Error do: [ :ex | ^ nil ].
	block := self sectionTable at: segment ifAbsent: [ ^ nil ].
	^ block value
]

{ #category : 'dispatching' }
PosternHelp class >> sectionTable [
	"Dictionary mapping /help/<segment> path strings to 0-arg blocks
	returning the Markdown content. The set of keys IS the whitelist
	for sectionFor:."
	^ Dictionary new
		at: 'api' put: [ self api ];
		at: 'browse' put: [ self browse ];
		at: 'makefile' put: [ self makefile ];
		at: 'pharo' put: [ self pharo ];
		at: 'lint' put: [ self lint ];
		at: 'dispatch' put: [ self dispatch ];
		at: 'git' put: [ self git ];
		at: 'testing' put: [ self testing ];
		at: 'safety' put: [ self safety ];
		at: 'lessons' put: [ self lessons ];
		yourself
]

{ #category : 'help content' }
PosternHelp class >> tableOfContents [
	"Top-level help table of contents."
	^ '# Postern /help

Postern is a live Pharo 12 image exposed as an HTTP REPL. These
help sections document how to drive the image from an external
agent or tool.

## Sections

- [`/help/api`](/help/api) — Eval server protocol: endpoints, auth, examples
- [`/help/browse`](/help/browse) — Read-only introspection: classes, methods, senders, implementors, source lookup
- [`/help/makefile`](/help/makefile) — Image lifecycle: make targets, disposable image discipline
- [`/help/pharo`](/help/pharo) — Pharo 12 standards: fluid syntax, protocols, JSON pattern
- [`/help/lint`](/help/lint) — Lint discipline: `make lint` is the gate
- [`/help/dispatch`](/help/dispatch) — Sub-agent delegation: template, TDD cycle, anti-patterns
- [`/help/git`](/help/git) — Git integration: Iceberg commits, CLI merges, package safety
- [`/help/testing`](/help/testing) — Test runs: scoped tests, never the full suite
- [`/help/safety`](/help/safety) — Safety: LibC deadlock, image discipline, orphan recovery
- [`/help/lessons`](/help/lessons) — Lessons from incidents: cascades, process failures, scope safety

## Quick Start

```bash
# Check the server is alive
curl -s http://localhost:8422/health

# Evaluate a Smalltalk expression
curl -s -X POST http://localhost:8422/repl \
  -H "Content-Type: text/plain" \
  -d "3 + 4"

# Read the API docs
curl -s http://localhost:8422/help/api

# Read the safety rules (do this first)
curl -s http://localhost:8422/help/safety
```
'
]

{ #category : 'help content' }
PosternHelp class >> testing [
	"How to run tests: scoped test runs, never the full suite."
	^ '# /help/testing — Running Tests

## The Rule

Only run project package tests. NEVER the full Pharo test suite.

```smalltalk
"Run one test class"
MyClassTest buildSuite run.
"=> 5 run, 5 passed, 0 failed, 0 errors"
```

```bash
# Run all project tests from the CLI
make test
```

## Running Tests from Inside the VM

Use `buildSuite run` on the specific test class:

```smalltalk
PosternHelpTest buildSuite run.
PosternServerTest buildSuite run.
PosternDashboardTest buildSuite run.
PosternRequestLoggerTest buildSuite run.
PosternImageBrowserTest buildSuite run.
```

The result object reports: run count, passed count, failure count,
error count. A clean run has zero failures and zero errors.

### Checking results programmatically

```smalltalk
| result |
result := MyClassTest buildSuite run.
result hasPassed.          "=> true if zero failures and errors"
result failureCount.       "=> 0"
result errorCount.         "=> 0"
result runCount.           "=> number of test methods run"
result passedCount.        "=> number that passed"
```

## Running Tests from the CLI

```bash
make test
```

This runs all test classes in packages ending with `-Tests` that
belong to the project (prefixed `Claude-`, `Postern-`,
`PharoKeyring-`, or `PharoSupervisedProcess-`). It reports a
single summary line with totals.

## What NOT to Do

```smalltalk
"NEVER — runs thousands of Pharo platform tests"
TestRunner runAll.

"NEVER — includes unrelated test classes"
TestSuite new addTests: (Smalltalk allClasses
  select: [ :c | c isTestCase ]) tests; run.
```

Running the full Pharo test suite takes minutes, produces failures
in platform tests unrelated to your code, and provides no useful
signal.

## Test Class Conventions

Test classes are `TestCase` subclasses in `-Tests` packages:

```smalltalk
(TestCase << #MyClassTest
  slots: {};
  package: ''MyPackage-Tests'') install.

MyClassTest compile: ''testSomething
  self assert: 1 + 1 equals: 2'' classified: ''tests''.

MyClassTest compile: ''testAnotherThing
  self deny: false'' classified: ''tests''.
```

- Test methods go in the `tests` protocol
- Setup methods (`setUp`, `tearDown`) go in the `testing` protocol
- Helper methods go in the `testing` protocol
- Method names start with `test`

## Assertion Methods

```smalltalk
self assert: actual equals: expected.   "equality"
self assert: aBoolean.                  "true check"
self deny: aBoolean.                    "false check"
self assert: actual isKindOf: aClass.   "type check"
self should: [ expr ] raise: Error.     "exception check"
```

## TDD Cycle

1. Define the test class
2. Compile test methods — they should FAIL (class under test
   does not exist yet)
3. Define the production class
4. Compile production methods
5. Run tests — they should PASS
6. Run `make lint` — should be clean
7. Repeat for the next class

## Safety Note

`make test` must be run from the CLI (Bash tool), NOT from inside
the VM via `LibC resultOfCommand:`. Running `make test` from inside
the VM creates a circular dependency that deadlocks. See
`/help/safety` for details.

From inside the VM, use `MyClassTest buildSuite run` directly.
'
]
