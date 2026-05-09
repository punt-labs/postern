# Postern Announcement Plan

This is a working draft for announcing Postern to the Pharo community.
It is intentionally kept in `docs/` for editing and review before any
public posting.

## Goal

Announce Postern as a practical tool for driving a live Pharo image from
Claude Code, Codex, or any HTTP client, with an emphasis on:

- agent-driven development against a live image
- no-GUI-required workflows
- safe local-first positioning
- concrete developer value: compile, test, inspect, and commit from the
  running image

## Positioning

Short version:

> Postern lets coding agents and scripts work directly against a live
> Pharo image over HTTP.

Longer version:

> Postern is a small HTTP bridge for live Pharo development. It lets
> Claude Code, Codex, or any other client compile code, run tests,
> inspect objects, browse the image, and drive the development loop
> without going through the GUI.

Things to emphasize:

- it is designed for trusted local development
- it works with the live image model instead of hiding it
- it includes help routes for agents and humans
- it now has working macOS and Linux smoke-tested setup/start flows

Things to avoid overclaiming:

- do not present it as sandboxed or production-hardened remote access
- do not imply it has a deep security model beyond local binding and
  optional token auth
- do not sell it as replacing normal Pharo tools; present it as a new
  control surface

## Rollout Order

1. Post a short announcement on Discord.
2. Send a fuller announcement to `Pharo-users`.
3. Send a more technical note to `Pharo-dev`.
4. Submit a short item for official Pharo news/social amplification.
5. Offer a live demo at a sprint or community call.

## Pre-Post Checklist

- verify the GitHub repo description and topics are current
- verify the GitHub social preview is set
- verify the README screenshot and setup instructions are current
- verify `make setup`, `make start-headless`, `make test`, and
  `make lint` still pass on current `main`
- decide whether to lead with “agent-driven coding” or “HTTP bridge for
  a live image”
- have one short demo clip or screenshot ready

## Core Links

Fill these in before posting:

- Repo: `https://github.com/punt-labs/postern`
- README: `https://github.com/punt-labs/postern#readme`
- Screenshot: `docs/images/postern-dashboard.png`

## Discord Draft

Short version:

> I’ve open-sourced **Postern**, a small HTTP bridge for working against
> a live Pharo image from Claude Code, Codex, or any other client.
>
> It lets a client compile code, run tests, inspect objects, browse help,
> and drive the development loop without going through the GUI.
>
> It’s aimed at trusted local development, not exposed public access.
>
> Repo: <https://github.com/punt-labs/postern>

Longer version:

> I’ve open-sourced **Postern**.
>
> It exposes a live Pharo image over HTTP so a client can:
>
> - evaluate Smalltalk
> - run project tests
> - browse the image
> - inspect help and workflow docs from the image itself
> - drive a full edit/test loop from Claude Code, Codex, or any other
>   HTTP client
>
> The goal is not to replace normal Pharo tools, but to make the live
> image accessible as a control surface for agent-driven development.
>
> It’s intended for trusted local use. By design, if a client can hit
> `/repl`, it can do what normal Smalltalk in that image can do.
>
> Repo: <https://github.com/punt-labs/postern>

## Pharo-users Draft

Subject:

`[ANN] Postern — drive a live Pharo image over HTTP`

Body:

> Hi all,
>
> I’ve released **Postern**, a small open-source tool for driving a live
> Pharo image over HTTP.
>
> The idea is simple: a client can talk to a running image and use it to
> compile code, run tests, inspect objects, browse the image, and drive a
> development loop without going through the GUI. In practice, that makes
> it useful for Claude Code, Codex, scripts, and other external tools that
> want to work with the image directly.
>
> A few things Postern supports:
>
> - evaluate Smalltalk over HTTP
> - run project-scoped tests
> - inspect live image state
> - serve built-in help from the image itself
> - support both GUI and headless startup paths
>
> I’m thinking of it as a new control surface for the live image rather
> than a replacement for standard Pharo tools.
>
> It is intended for trusted local development. It is not a sandboxed
> execution environment, and the README/help make that explicit.
>
> Repository:
> <https://github.com/punt-labs/postern>
>
> I’d be glad to hear feedback, especially from people interested in live
> development workflows, automation, and agent-assisted programming in
> Pharo.
>
> Best,
> James

## Pharo-dev Draft

Subject:

`[ANN] Postern — HTTP control surface for a live Pharo image`

Body:

> Hi all,
>
> I’ve released **Postern**:
>
> <https://github.com/punt-labs/postern>
>
> Postern exposes a live Pharo image over HTTP so an external client can
> interact with it directly. The main use case is agent-driven or scripted
> development against a live image: compile, test, inspect, browse, and
> iterate from outside the IDE while still using the image as the source of
> truth.
>
> The current shape is intentionally small:
>
> - `/repl` for evaluation
> - `/help` routes served from the running image
> - support for read-oriented browsing/introspection workflows
> - local GUI and headless startup via `make`
>
> I tried to keep the model honest: this is not a constrained API layer,
> and it is not a sandbox. If a client can evaluate code in the image, it
> has the same practical power as Smalltalk running in that image.
>
> Areas I’d especially welcome feedback on:
>
> - how this fits with the live image model philosophically
> - whether the current help/browse split is the right one
> - package boundaries between the runtime and dashboard pieces
> - how much of this should stay Postern-specific versus general Pharo
>   tooling
>
> Thanks,
> James

## Official News / Social Draft

Short version:

> **Postern** is a new open-source tool for driving a live Pharo image over
> HTTP. It supports agent-driven and scripted development workflows by
> letting external clients evaluate code, run tests, inspect the image, and
> use help served directly from the running system.
>
> <https://github.com/punt-labs/postern>

Shorter social copy:

> New: **Postern** — drive a live Pharo image over HTTP from Claude Code,
> Codex, or any other client.
>
> Compile, test, inspect, and browse the live image without going through
> the GUI.
>
> <https://github.com/punt-labs/postern>

## Demo Talking Points

- “Pharo already has a live image. Postern makes that image accessible to
  external tools.”
- “This is not a fake REST API over a static codebase. The live image is
  the thing being driven.”
- “The interesting part is not just eval. It’s the full loop: browse,
  compile, test, inspect, and commit.”
- “The safety model is simple and explicit: trusted local use first.”

## Follow-Up Ideas

- short screencast of Claude Code or Codex driving a fix through Postern
- sprint demo with live Q&A
- write-up comparing normal IDE workflow vs agent-assisted workflow
- possible future post: “What it means to expose a live image to a coding
  agent”
