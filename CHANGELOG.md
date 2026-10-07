# Changelog

## [0.6.0] (2026-10-07)

### Features

- Add pinned nextest and LLVM coverage tools to both Rust variants and Debian
  polyglot, with offline JUnit, Cobertura, LCOV, and JSON checks.
- Execute Rust and polyglot CI and scheduled checks on native amd64 and arm64.
- Reduce Rust image size with the minimal rustup profile and removal of tool
  installation caches.

[0.6.0]: https://github.com/driftsys/dock/compare/v0.5.0...v0.6.0

## [0.5.0] (2026-10-03)

### Features

- **python:** add uv and pinned Ruff binaries ([72e0c45]), refs [#91]
- **rust:** add Clippy SARIF reporting tools ([c2bd6c2]), refs [#90]
- **lint:** add ShellCheck SARIF conversion ([e5dbc77]), refs [#89]
- **glab:** add GitLab reporting images ([01decc0]), refs [#88]
- **core:** add CI tools and upgrade OS bases ([f3a684c]), closes [#65]

### Bug Fixes

- align scheduled health checks with image variants ([246ed7a]), refs [#67]

### Runtime and tooling updates

- Update both Node.js variants to 24.21.0 LTS and bundled npm.
- Update Deno to the supported 2.9.3 LTS release in Deno and polyglot images.
- Update Android SDK to API 37.2, NDK to r30 LTS, and SDK CMake to 4.1.2.
- Preserve decimal Android API levels when publishing release tags.
- Use the current Android CLI for SDK management on amd64 and arm64.
- Update yq, mdBook, Typst, tera-cli, Vale, Typos, Harper, and Vale style packs.
- Build stable mdbook-katex 0.10.0 in a separate stage; keep Java 17 support.

### BREAKING CHANGES

- all dependent images inherit Alpine 3.24 or Debian 13 package sets. JVM images
  replace Debian's headless OpenJDK 17 package with the full Eclipse Temurin 17
  JDK.

[0.5.0]: https://github.com/driftsys/dock/compare/v0.4.0...v0.5.0
[72e0c45]: https://github.com/driftsys/dock/commit/72e0c45
[#91]: https://github.com/driftsys/dock/issues/91
[c2bd6c2]: https://github.com/driftsys/dock/commit/c2bd6c2
[#90]: https://github.com/driftsys/dock/issues/90
[e5dbc77]: https://github.com/driftsys/dock/commit/e5dbc77
[#89]: https://github.com/driftsys/dock/issues/89
[01decc0]: https://github.com/driftsys/dock/commit/01decc0
[#88]: https://github.com/driftsys/dock/issues/88
[f3a684c]: https://github.com/driftsys/dock/commit/f3a684c
[#65]: https://github.com/driftsys/dock/issues/65
[246ed7a]: https://github.com/driftsys/dock/commit/246ed7a
[#67]: https://github.com/driftsys/dock/issues/67

## [0.2.7] (2026-06-02)

### Refactoring

- **images:** slim core, rationalize glibc, swap linkcheck→lychee ([#51])
  ([c942e2b])

[0.2.7]: https://github.com/driftsys/dock/compare/v0.2.6...v0.2.7
[c942e2b]: https://github.com/driftsys/dock/commit/c942e2b
[#51]: https://github.com/driftsys/dock/issues/51

## [0.2.6] (2026-05-28)

### Bug Fixes

- **githooks:** align hook scripts with current git-std subcommands ([fcc6d2c])

[0.2.6]: https://github.com/driftsys/dock/compare/v0.2.5...v0.2.6
[fcc6d2c]: https://github.com/driftsys/dock/commit/fcc6d2c

## [0.2.5] (2026-05-28)

### Refactoring

- **lint:** remove gomdlint, use npx markdownlint-cli2 instead ([ee967b5])

### Documentation

- **prose:** document :prose image ([#47]) ([35ff07c])

### Features

- **prose:** add :prose image with vale, typos, harper-cli ([#46]) ([8696955])

[0.2.5]: https://github.com/driftsys/dock/compare/v0.2.4...v0.2.5
[ee967b5]: https://github.com/driftsys/dock/commit/ee967b5
[35ff07c]: https://github.com/driftsys/dock/commit/35ff07c
[#47]: https://github.com/driftsys/dock/issues/47
[8696955]: https://github.com/driftsys/dock/commit/8696955
[#46]: https://github.com/driftsys/dock/issues/46

## [0.2.2] (2026-05-27)

### Features

- **lint:** rebase on deno, add dprint + gomdlint + lint-debian ([871308b])
- **deno:** add npm shim delegating to Deno equivalents ([#44]) ([a463410])

[0.2.2]: https://github.com/driftsys/dock/compare/v0.2.1...v0.2.2
[871308b]: https://github.com/driftsys/dock/commit/871308b
[a463410]: https://github.com/driftsys/dock/commit/a463410
[#44]: https://github.com/driftsys/dock/issues/44

## [0.2.1] (2026-05-27)

### Features

- add dock:pages image + npx shim for dock:deno ([#43]) ([b74e844])

### Bug Fixes

- **ci:** exclude pages-debian from arm64 release build ([074876c])

[0.2.1]: https://github.com/driftsys/dock/compare/v0.2.0...v0.2.1
[b74e844]: https://github.com/driftsys/dock/commit/b74e844
[#43]: https://github.com/driftsys/dock/issues/43
[074876c]: https://github.com/driftsys/dock/commit/074876c

## [0.2.1] (2026-05-27)

### Features

- add dock:pages image + npx shim for dock:deno ([#43]) ([b74e844])

[0.2.1]: https://github.com/driftsys/dock/compare/v0.2.0...v0.2.1
[b74e844]: https://github.com/driftsys/dock/commit/b74e844
[#43]: https://github.com/driftsys/dock/issues/43

## [0.2.0] (2026-04-30)

### Features

- add android-ndk-debian image with NDK 27 + Rust + cargo-ndk

[0.2.0]: https://github.com/driftsys/dock/compare/v0.1.9...v0.2.0

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
