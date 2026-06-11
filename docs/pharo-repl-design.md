# Background REPL on the Pharo Scheduler — Design & ADRs

A command REPL that accepts requests (e.g. "run these unit tests"), executes
arbitrary user code, and **never freezes the UI**, built on Pharo's green-thread
process model.

---

## 1. Platform model (context for every decision below)

Pharo runs all Smalltalk code as **green-thread `Process` objects on a single OS
thread**, scheduled by the in-VM `ProcessorScheduler` (the `Processor` singleton).
The VM spawns additional OS threads only for GC, FFI calls, and the heartbeat
timer — never for Smalltalk execution.

Scheduling is a **priority-based preemptive / same-priority cooperative** hybrid:

- Higher-priority runnable Process **immediately preempts** a lower one.
- Same priority → round-robin time slicing (~ tens of ms).
- A Process yields by blocking: `Semaphore wait`, `Delay wait*`, `Processor yield`, `Processor sleep:`, or any I/O that waits on a Semaphore internally.

Priority constants on `ProcessorScheduler` (higher number = higher priority).
Exact values vary by version; representative scale:

| Priority | Constant | Typical use |
|---|---|---|
| 100 | `timingPriority` | heartbeat-driven timers |
| 80 | `highIOPriority` | network/IO handlers |
| 60 | `lowIOPriority` | lower-urgency IO |
| 50 | `userInterruptPriority` | — |
| 40 | `userSchedulingPriority` | **UI / typical user code** |
| 30 | `backgroundUserPriority` | background work |
| 10 | `systemBackgroundPriority` | idle/system |

**Consequences inherited by this design:**

- No true parallelism by default → no data races on object state from
  simultaneous execution. (Closer to a GIL / goroutine-on-one-thread model than to pthreads.)
- Deadlock and **priority starvation are still possible**: a busy Process at
  priority ≥ the UI starves the UI.
- The escape hatch from a stuck image is the VM heartbeat-driven interrupt
  (`Alt+.` / `Cmd+.`), not a cooperative yield.

> **Verify in your target version:** the priority of the live UI process. Pharo's
> Morphic UI process is commonly `userSchedulingPriority` (40); earlier notes in
> this design used 50. The design below depends only on the *ordering*
> (§ADR-002), and the chosen numbers bracket the UI whether it is 40 or 50.

---

## 2. Architecture overview

Three roles, separated strictly by priority:

```text
priority 60   REPL loop        (above UI)   — reads commands, dispatches work, blocks when idle
priority 40   UI event loop    (the floor)  — must always be the highest *runnable* process under load
priority 30   Work execution   (below UI)   — compiles + runs arbitrary user code
```

Control flow for one command:

```text
input source ──submit:──▶ SharedQueue
                              │  (REPL loop blocks on `next`)
REPL loop (60) ◀──────────────┘
   │  fork worker at 30
   ▼
worker (30): redirect Transcript→capture ; compile+eval ; catch errors ; ensure: cleanup+signal
   │
REPL loop (60) blocks on resultSem ──── UI (40) runs freely while worker computes ────▶
   │  resultSem signalled
   ▼
REPL reads { outcome . capturedOutput } and prints
```

The two load-bearing invariants:

1. **Priority ordering** `REPL > UI > worker` (§ADR-002).
2. **The REPL only ever runs while holding nothing and blocks the instant it has
   no command/result to process** (§ADR-003) — otherwise its high priority would
   starve the UI.

---

## 3. Architecture Decision Records

### ADR-001 — Execute on green-thread Processes, accept the single-OS-thread model

**Status:** Accepted (platform-imposed; documented for its consequences).

**Context.** Pharo offers no production multi-OS-thread execution of Smalltalk;
all `Process`es share one OS thread.

**Decision.** Build the REPL entirely on `Process`/`Semaphore`. Do not attempt to
offload work to OS threads.

**Consequences.**

- (+) No locks needed to protect ordinary object state against parallel mutation; data races from simultaneous execution cannot occur.
- (+) Reasoning reduces to *priority + explicit yield points*.
- (−) CPU-bound work cannot use multiple cores; a tight non-yielding loop monopolizes the single thread.
- (−) Deadlock and starvation remain possible and are the main failure modes to design against.

---

### ADR-002 — Priority invariant: REPL > UI > worker

**Status:** Accepted.

**Context.** Two competing requirements: (a) the REPL must remain responsive to
control commands (including *cancel*) even while heavy work runs; (b) user-submitted
work must never block the UI.

**Decision.** Assign **REPL = 60**, **worker = 30**, with the **UI as the middle
band**. The invariant `priority(REPL) > priority(UI) > priority(worker)` is the
contract; 60/30 satisfy it whether the UI process is 40 or 50.

**Consequences.**

- (+) The REPL can preempt running work to handle a cancel request immediately.
- (+) Work at 30 is preempted by the UI (40) whenever events arrive → UI stays responsive.
- (−) A REPL bug that *spins* at 60 starves the UI outright. This raises the
  blocking discipline of ADR-003 from "nice" to "mandatory."

**Alternatives considered.**

- *REPL below UI (e.g. 30, work at 10).* Rejected: a UI-priority work item or a busy UI could delay the REPL's response to cancel.
- *REPL = work priority.* Rejected: cannot preempt to cancel; relies on cooperative time-slicing.

---

### ADR-003 — The REPL idles by blocking; it never busy-waits

**Status:** Accepted. (Direct corollary of ADR-002.)

**Context.** Because the REPL sits above the UI, any CPU it consumes is taken
*from* the UI.

**Decision.** The REPL spends all idle time **blocked on a Semaphore**. Command
intake uses a `SharedQueue`, whose `next` blocks on an internal Semaphore until an
item is enqueued. Completion uses an explicit result `Semaphore`. Between these
waits the REPL does only short, non-blocking bookkeeping.

**Consequences.**

- (+) While blocked, the REPL is not runnable, so the UI (40) is the highest runnable process — full UI responsiveness.
- (−) Every code path between two `wait`s must be short and must not perform
  spinning I/O. Standard Pharo streams (Transcript, Socket, File) block correctly
  on Semaphores, so ordinary intake is safe; a hand-rolled polling read would
  reintroduce starvation.

---

### ADR-004 — Submit work via fork-at-30 plus a Semaphore completion handshake

**Status:** Accepted.

**Context.** The REPL must hand work to a lower priority and then wait for a result
without consuming CPU.

**Decision.** For each command the REPL forks a worker Process at priority 30 and
blocks on a fresh result `Semaphore`. The worker computes, stores its outcome, and
signals. `[...] forkAt: 30` is the shorthand; the long form
(`newProcess; priority: 30; resume`) is used when a handle to the Process is needed
for cancellation (ADR-007).

**Consequences.**

- (+) Clean separation: the REPL's wait is a block, not a poll; the worker runs in the UI's shadow.
- (+) One Semaphore per command keeps completion signalling unambiguous.
- (−) The handshake assumes one in-flight command at a time. Concurrent commands
  would need a worker pool and per-command result routing (out of scope).

---

### ADR-005 — Compile and evaluate user source *inside* the worker Process

**Status:** Accepted.

**Context.** REPL input is arbitrary Smalltalk source (a `String`). It must be
compiled and run. *Where* compilation happens determines where compile errors land.

**Decision.** Wrap `Smalltalk compiler evaluate: aString` (equivalently
`OpalCompiler new source: ...; evaluate`) **inside the forked worker block**, not
in the REPL before forking. For class-context evaluation use
`OpalCompiler new source: src; receiver: anObject; evaluate`.

**Consequences.**

- (+) **Syntax/semantic errors raise inside the worker**, where they are caught as
  values (ADR-006) instead of being thrown into the REPL's stack.
- (+) `Processor activeProcess` observed by user code is the **worker**, not the
  REPL — automatically correct, no extra wiring. Naming the worker
  (`'REPL worker'`) makes this visible in the Process Browser.
- (−) Compilation cost is paid on every evaluation. Acceptable for a REPL;
  cache `CompiledMethod`s if a hot path emerges.

---

### ADR-006 — Capture exceptions as return values, never propagate them

**Status:** Accepted.

**Context.** User code routinely raises. An exception escaping the worker into the
REPL would corrupt the loop; one escaping into the UI would open a debugger.

**Decision.** Evaluate under `on: Error, Halt do: [ :e | e ]`. The exception object
*becomes the outcome*. `Error` covers compile errors (`OCSemanticError` is an
`Error`) and runtime errors; `Halt` covers `self halt` debugging traps. The
process-termination signal used by cancel is deliberately **not** caught here — it
must unwind (ADR-007).

**Consequences.**

- (+) The REPL receives either a value or an exception object, uniformly, and decides how to render it.
- (+) A stray raise can never kill the REPL or surface a UI debugger.
- (−) Broad capture can mask conditions a developer might prefer to debug live.
  Tunable by narrowing the caught set.

---

### ADR-007 — Cancellation via `Process>>terminate`, with `ensure:` for cleanup and wakeup

**Status:** Accepted.

**Context.** Runaway user code (infinite loop, hung wait) must be abortable from
the REPL, and the REPL — blocked on the result Semaphore — must be woken when that
happens.

**Decision.** Retain the worker handle. `cancel` sends it `terminate` (safe to call
after completion — it is then a no-op). All teardown is placed in **`ensure:`**
blocks, relying on Pharo's guarantee that `ensure:`/`ifCurtailed:` blocks run during
`terminate`'s stack unwind. Nesting matters:

```smalltalk
[ proxy redirectProcess: thisProcess to: outStream.
  [ outcome := <eval under on:do:> ]
    ensure: [ proxy stopRedirecting: thisProcess ] ]   "inner: runs first on unwind"
ensure: [ resultSem signal ]                           "outer: always wakes the REPL"
```

The default outcome is pre-set to `#canceled`, so termination yields a meaningful
return rather than a stuck waiter.

**Consequences.**

- (+) Cancel is immediate (REPL preempts worker per ADR-002) and leaves no leaked
  redirect: the inner `ensure:` removes the worker from the output map *before* the
  outer `ensure:` wakes the REPL, so by the time the REPL reads the captured output
  the worker can no longer append to it.
- (+) Races are benign: terminate-after-finish is a no-op; a second Semaphore signal with no waiter is harmless.
- (−) `terminate` stops **only the worker**. Processes the user's code itself forked keep running (see Limitations).

---

### ADR-008 — Capture output via a process-routed proxy over the `Transcript` global; reject compiler bindings

**Status:** Accepted. **Supersedes** an earlier compiler-bindings approach.

**Context.** Captured stdout-equivalent output is needed (test output, `printNl`,
`Transcript show:`). Pharo has no Unix stdout in image mode — `Transcript` *is* the
output stream. Capture must (a) catch output from arbitrary call depth, not just the
top-level expression, and (b) be **per-process**, so concurrent UI logging is
unaffected.

**Decision.** Install a `ProcessRoutedStream` proxy as the global `Transcript` once
at startup. It keeps an `IdentityDictionary` of `Process → captureStream` and routes
each write to `streamsByProcess at: Processor activeProcess ifAbsent: [ default ]`,
where `default` is the original real Transcript (preserved, so the UI window keeps
updating). The REPL registers the worker → its capture stream for the duration of an
evaluation (registration/teardown via ADR-007's `ensure:`).

Reassigning `Smalltalk globals at: #Transcript put:` updates the existing binding's
value; compiled code reads `Transcript` through that binding, so **every** reference
in the image — including deep inside library methods — now resolves to the proxy.

**Consequences.**

- (+) Captures **all synchronous output at any call depth**, the key advantage over bindings.
- (+) Per-process: non-worker processes resolve to `default` and behave normally.
- (+) The proxy implements the writing protocol (`nextPut:`, `nextPutAll:`, `show:`,
  `showln:`, `print:`, `display:`, `<<`, `cr`, `tab`, `space`, `flush`) and
  forwards everything else (control/GUI methods like `clear`, `endEntry`) to
  `default` via `doesNotUnderstand:`.
- (−) Output from processes the *user code itself* forks is not captured (their
  `activeProcess` is unregistered) — same boundary as ADR-007.
- (−) Reassigning a core global is load-bearing and version-sensitive: **verify**
  that `Smalltalk globals at: #Transcript put:` updates the binding seen by compiled
  code in your version (a one-liner confirms it).

**Alternatives considered.**

- *Compiler `bindings: { #Transcript -> stream }`.* Rejected as the primary
  mechanism: it overrides the name **only in the directly-compiled expression**;
  output from any method that expression *calls* still hits the real Transcript.
  Adequate only for trivial top-level writes.
- *Globally swap the real Transcript object (no proxy).* Rejected: not per-process —
  it would redirect the UI's output too.

---

### ADR-009 — Lock-free proxy reads via atomic instVar swap; copy-on-write writes under a Mutex

**Status:** Accepted.

**Context.** `currentStream` runs on **every** character/string write, so it must be
cheap; but the `Process → stream` map is shared mutable state, and a `Dictionary`
is unsafe under concurrent read+write (a rehash during a read can corrupt it).

**Decision.** Treat the map as **immutable once published**. Registration and
teardown copy the map, mutate the copy, then assign the instance variable
(`streamsByProcess := copy`) inside a `Mutex critical:` block. Reads take **no
lock** and simply index the current map.

Safety rests directly on ADR-001's single-OS-thread model: an instVar store is a
single bytecode and a process switch cannot tear a pointer slot, so a reader always
observes either the complete old map or the complete new one — both valid, immutable
snapshots. The Mutex serializes *writers* only (relevant if evaluations ever overlap).

**Consequences.**

- (+) Zero lock contention on the hot read path; full correctness under preemption.
- (+) Writers are rare (once per evaluation start/end) so the copy cost is negligible.
- (−) The lock-free argument is **specific to the single-OS-thread VM**. If Pharo's
  multi-threaded VM is ever adopted, reads would need a real memory barrier /
  lock — this ADR must be revisited then.

---

### ADR-010 — Treat `Stdio` stderr/stdout redirection as a best-effort extension

**Status:** Accepted (scoped limitation).

**Context.** In headless/CLI Pharo, output may go to `Stdio stdout` / `Stdio stderr`
rather than Transcript, and a true *stderr* channel exists only there. The request
mentioned standard error/output explicitly.

**Decision.** Reuse the **same** `ProcessRoutedStream` class, installed over the
`Stdio` stream references, mapping the worker to a second `errStream`; return
`{ outcome . stdout . stderr }`. Because `Stdio` caches its streams in
version-specific internals without a uniform public setter, this path is **best-effort**
and must be verified per version. Transcript capture (ADR-008) is the solid path and
covers the overwhelming majority of interactive output.

**Consequences.**

- (+) One mechanism for all three streams when the install points are available.
- (−) Fragile across versions; do not rely on it without a version-specific test.
- (−) In image (Morphic) mode there is no distinct stderr at all — output and error collapse into Transcript.

---

## 4. Known limitations

1. **User-forked subprocesses are invisible to both cancel and capture.**
   `terminate` (ADR-007) kills only the worker; the output map (ADR-008) keys on the
   worker's `activeProcess`. Any Process the user's code spawns runs and writes
   outside both. Closing this requires tracking descendant Processes (Pharo keeps no
   parent links by default) — deliberately out of scope.
2. **`Stdio` redirection is version-dependent** (ADR-010).
3. **A fully frozen event loop has no in-image rescue.** `Alt+.`/`Cmd+.` depends on
   the VM heartbeat being able to interrupt into a still-functional image; if the
   event loop itself is wedged, the only recourse is killing the OS process.
4. **Single in-flight command** (ADR-004). Concurrency needs a worker pool.
5. **Global-binding reassignment** (ADR-008) and the **lock-free read argument**
   (ADR-009) are both contingent on current VM behavior and must be re-validated
   against a future multi-threaded VM.

---

## 5. Operational notes

- **Interrupting a stuck evaluation by hand:** `Alt+.` (Linux/Windows) / `Cmd+.`
  (macOS) raises a debugger via the VM heartbeat OS thread — it fires regardless of
  what the single Smalltalk thread is doing (so long as the image can still service
  the interrupt).
- **Visibility:** name every Process (`worker name: 'REPL worker'`) so it is
  identifiable in the Process Browser.
- **VM OS threads** exist only for GC, FFI, and the heartbeat timer; none run
  Smalltalk, so they do not affect the priority reasoning above.

---

## 6. Consolidated reference implementation

```smalltalk
"=== Generic per-process output router (ADR-008, ADR-009) ============="

Object subclass: #ProcessRoutedStream
    instanceVariableNames: 'default streamsByProcess writeMutex'
    classVariableNames: ''
    package: 'MyRepl'

ProcessRoutedStream >> initialize
    streamsByProcess := IdentityDictionary new.
    writeMutex := Mutex new.

ProcessRoutedStream >> default: aStream
    default := aStream

"Lock-free read — safe because instVar swap is atomic on the single VM thread"
ProcessRoutedStream >> currentStream
    ^ streamsByProcess at: Processor activeProcess ifAbsent: [ default ]

ProcessRoutedStream >> redirectProcess: aProcess to: aStream
    writeMutex critical: [
        | copy |
        copy := streamsByProcess copy.
        copy at: aProcess put: aStream.
        streamsByProcess := copy ]

ProcessRoutedStream >> stopRedirecting: aProcess
    writeMutex critical: [
        | copy |
        copy := streamsByProcess copy.
        copy removeKey: aProcess ifAbsent: [ ].
        streamsByProcess := copy ]

"--- writing protocol → captured stream ---"
ProcessRoutedStream >> nextPut: aCharacter      ^ self currentStream nextPut: aCharacter
ProcessRoutedStream >> nextPutAll: aCollection   ^ self currentStream nextPutAll: aCollection
ProcessRoutedStream >> show: anObject     self currentStream nextPutAll: anObject asString. ^ self
ProcessRoutedStream >> showln: anObject   self currentStream nextPutAll: anObject asString; nextPut: Character lf. ^ self
ProcessRoutedStream >> print: anObject    self currentStream print: anObject.   ^ self
ProcessRoutedStream >> display: anObject  self currentStream display: anObject. ^ self
ProcessRoutedStream >> << anObject        self currentStream << anObject.       ^ self
ProcessRoutedStream >> cr                 self currentStream nextPut: Character lf. ^ self  "use Character cr to mirror Transcript exactly"
ProcessRoutedStream >> lf                 self currentStream nextPut: Character lf. ^ self
ProcessRoutedStream >> tab                self currentStream tab.   ^ self
ProcessRoutedStream >> space              self currentStream space. ^ self
ProcessRoutedStream >> flush              self currentStream flush. ^ self

"--- control / GUI methods (clear, endEntry, ...) pass through to the real Transcript ---"
ProcessRoutedStream >> doesNotUnderstand: aMessage
    ^ aMessage sendTo: default

ProcessRoutedStream class >> installOn: aGlobalSymbol
    | current proxy |
    current := Smalltalk globals at: aGlobalSymbol.
    (current isKindOf: self) ifTrue: [ ^ current ].   "idempotent"
    proxy := self new default: current; yourself.
    Smalltalk globals at: aGlobalSymbol put: proxy.
    ^ proxy

ProcessRoutedStream >> uninstallFrom: aGlobalSymbol
    Smalltalk globals at: aGlobalSymbol put: default


"=== The REPL (ADR-002..007) ==========================================="

Object subclass: #Repl
    instanceVariableNames: 'inputQueue worker resultSem outcome transcriptProxy running'
    classVariableNames: ''
    package: 'MyRepl'

Repl >> initialize
    inputQueue := SharedQueue new.    "blocking `next` = idle-block, ADR-003"
    running := false.

"Install capture once, fork the REPL loop above the UI (ADR-002)"
Repl >> start
    transcriptProxy := ProcessRoutedStream installOn: #Transcript.
    running := true.
    [ self runLoop ] forkAt: 60.

Repl >> stop
    running := false.
    inputQueue nextPut: nil.          "unblock the loop"

"Called from any input source (text field, socket, ...) in its own process"
Repl >> submit: aSourceString
    inputQueue nextPut: aSourceString

Repl >> runLoop
    [ running ] whileTrue: [
        | source |
        source := inputQueue next.     "BLOCKS here — UI (40) is highest runnable"
        source ifNotNil: [
            | pair |
            pair := self evaluate: source.   "blocks on resultSem; UI runs during work"
            self printOutcome: (pair at: 1) output: (pair at: 2) ] ]

"Compile + run at priority 30, capture output, catch errors, support cancel"
Repl >> evaluate: aSourceString
    | outStream |
    resultSem := Semaphore new.
    outcome   := #canceled.            "default if terminated before completion"
    outStream := WriteStream on: (String new: 256).

    worker := [
        [ transcriptProxy redirectProcess: Processor activeProcess to: outStream.
          [ outcome := [ Smalltalk compiler evaluate: aSourceString ]
                on: Error, Halt
                do: [ :e | e ] ]
            ensure: [ transcriptProxy stopRedirecting: Processor activeProcess ] ]
        ensure: [ resultSem signal ]
    ] newProcess.
    worker name: 'REPL worker'; priority: 30; resume.

    resultSem wait.
    worker := nil.
    ^ { outcome. outStream contents }

"Call from a process other than the worker (e.g. a 'cancel' command). Safe post-completion."
Repl >> cancel
    worker ifNotNil: [ :w | w terminate ]

Repl >> printOutcome: anOutcome output: aString
    anOutcome == #canceled
        ifTrue:  [ Transcript showln: '*** canceled ***' ]
        ifFalse: [ Transcript showln: 'output: ', aString; showln: 'result: ', anOutcome printString ]
```

> The `printOutcome:output:` writes run on the REPL Process (priority 60, no
> redirect registered for it), so they go to the **real** Transcript via the proxy's
> `default` path — REPL output is not swallowed by the capture buffer.
