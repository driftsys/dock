# Changelog

## [Unreleased]

### Added

- `dock-bootstrap` — auto-detects CA certificates from environment
  variables, drop directory (`/etc/dock/ca.d/`), and
  `CI_SERVER_TLS_CA_FILE`; imports into the system trust store
- Pre-configured CA bundle paths for cargo, npm, deno, pip, git,
  curl across all images
- Documentation for corporate environments: CA injection, proxy
  pass-through, registry mirrors, connectivity verification

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
