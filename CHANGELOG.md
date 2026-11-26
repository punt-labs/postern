# Changelog

## [Unreleased]

### Changed

- **Breaking:** Authenticated Postern starts write a new token to
  `.punt-labs/local/postern/eval-token` for checkout-launched images (see
  `make eval-token-path`) or `~/.punt-labs/postern/eval-token` for standalone
  images. Update clients that read `.tmp/eval-token`; do not copy the old token.
- The checkout's fallback Pharo home moved from `.tmp/pharo-home` to
  `.punt-labs/local/postern/pharo-home`. Nothing moves automatically.
  If you need settings from the old fallback home, copy them manually with
  Pharo stopped.

### Removed

- Ethos is removed from this repository for now: `.punt-labs/ethos.yaml`, the
  `postern` check set under `.punt-labs/ethos/checks/`, the 27 generated
  `.claude/agents/` files, and the "Ethos & Delegation" sections of `CLAUDE.md`
  and `AGENTS.md` (the live-image guidance stays under "Live Image Workflow").
