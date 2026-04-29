# Changelog

## [0.1.9] (2026-04-29)

### Features

- add API-level-pinned tags for android image (`:android-36-debian`)

[0.1.9]: https://github.com/driftsys/dock/compare/v0.1.8...v0.1.9

## [0.1.8] (2026-04-28)

### Features

- add jvm-debian and android-debian images ([#41]) ([b9ced11])

[0.1.8]: https://github.com/driftsys/dock/compare/v0.1.7...v0.1.8
[b9ced11]: https://github.com/driftsys/dock/commit/b9ced11
[#41]: https://github.com/driftsys/dock/pull/41

## [0.1.7] (2026-04-23)

### Documentation

- document dock-bootstrap layered CA architecture and corporate usage ([#40])
  ([ccb7b3c])

[0.1.7]: https://github.com/driftsys/dock/compare/v0.1.6...v0.1.7
[ccb7b3c]: https://github.com/driftsys/dock/commit/ccb7b3c
[#40]: https://github.com/driftsys/dock/issues/40

## [0.1.6] (2026-04-23)

### Bug Fixes

- **core:** preserve cluster-injected CAs in fallback CA bundle ([#39])
  ([b8aa763])

[0.1.6]: https://github.com/driftsys/dock/compare/v0.1.5...v0.1.6
[b8aa763]: https://github.com/driftsys/dock/commit/b8aa763
[#39]: https://github.com/driftsys/dock/issues/39

## [0.1.5] (2026-04-23)

### Bug Fixes

- **core:** ensure newline separators between PEM certs in fallback CA bundle
  ([#38]) ([12275ec])

[0.1.5]: https://github.com/driftsys/dock/compare/v0.1.4...v0.1.5
[12275ec]: https://github.com/driftsys/dock/commit/12275ec
[#38]: https://github.com/driftsys/dock/issues/38

## [0.1.4] (2026-04-23)

### Bug Fixes

- **core:** handle update-ca-certificates failure on restricted K8s runners
  ([#37]) ([26736ad])

### Features

- **core:** add dock-bootstrap for corporate CA auto-detection and trust store
  setup ([#36]) ([51d0a70])

### Documentation

- **claude:** switch to @AGENTS.md import ([78c2bf0])

[0.1.4]: https://github.com/driftsys/dock/compare/v0.1.3...v0.1.4
[26736ad]: https://github.com/driftsys/dock/commit/26736ad
[#37]: https://github.com/driftsys/dock/issues/37
[51d0a70]: https://github.com/driftsys/dock/commit/51d0a70
[#36]: https://github.com/driftsys/dock/issues/36
[78c2bf0]: https://github.com/driftsys/dock/commit/78c2bf0

## [0.1.3] (2026-03-28)

### Refactoring

- **dock:** CI/CD review fixes ([368162a])

### Bug Fixes

- **lint:** bump git-std to v0.9.0 ([bf811a3])
- **dock:** CI/CD debt — bump reliability, caching, and coverage ([0deca91])
- **dock:** fetch latest mdbook version dynamically in Pages workflow
  ([8b9dba7])

[0.1.3]: https://github.com/driftsys/dock/compare/v0.1.2...v0.1.3
[368162a]: https://github.com/driftsys/dock/commit/368162a
[bf811a3]: https://github.com/driftsys/dock/commit/bf811a3
[0deca91]: https://github.com/driftsys/dock/commit/0deca91
[8b9dba7]: https://github.com/driftsys/dock/commit/8b9dba7
