# Changelog

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

## [Unreleased]

### Bug Fixes

- **core:** preserve cluster-injected CA certs in fallback bundle —
  fixes TLS failures for proxy-intercepted domains (e.g. deno.land)

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

## [Unreleased]

### Bug Fixes

- **core:** ensure newline separators between PEM certs in fallback
  CA bundle — fixes curl error 77 when `CI_SERVER_TLS_CA_FILE` lacks
  a trailing newline

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
