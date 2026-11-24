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
