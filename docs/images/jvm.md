# :jvm

Eclipse Temurin JDK 17 for CI. Inherits all `:core` tools. **Debian only** —
this image shares the glibc base used by the Android images.

## Base

| Variant | Base                                       |
| ------- | ------------------------------------------ |
| Debian  | `ghcr.io/driftsys/dock:core-debian` (build |
|         | context)                                   |

> **No Alpine variant.** Use `:jvm-debian` exclusively.

## Installed tools

| Tool    | Install method       | Purpose                   |
| ------- | -------------------- | ------------------------- |
| java    | apt (temurin-17-jdk) | JDK 17 runtime + compiler |
| javac   | apt (temurin-17-jdk) | Java compiler             |
| keytool | included in JDK      | Certificate management    |

Debian trixie does not provide OpenJDK 17. The image uses Adoptium's signed apt
repository to preserve Java 17 for JVM and Android builds. The Temurin package
also installs its system certificate update hook.

The Java platform library source archive (`JAVA_HOME/lib/src.zip`) is omitted to
reduce the image size. CI compilation and execution use the installed compiler
and runtime binaries. Android images inherit this reduction.

## Environment variables

| Variable    | Value                          |
| ----------- | ------------------------------ |
| `JAVA_HOME` | `/usr/lib/jvm/java-17-openjdk` |

`JAVA_HOME` uses an arch-neutral symlink that works on both `amd64` and `arm64`.

## Corporate CA support

`dock-bootstrap` automatically updates the JKS truststore when corporate
certificates are detected. On read-only Kubernetes runners, it builds a private
truststore at `/etc/dock/cacerts` and sets
`JAVA_TOOL_OPTIONS=-Djavax.net.ssl.trustStore=/etc/dock/cacerts` via
`/etc/dock/ca.env`.

## Usage in CI

### GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:jvm-debian
    steps:
      - uses: actions/checkout@v4
      - run: javac -version
      - run: java -version
```

### GitLab CI

```yaml
build:
  image: ghcr.io/driftsys/dock:jvm-debian
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
  script:
    - javac -version
    - java -version
```

## Approximate size

Compressed download size for `linux/amd64`.

| Variant | Size    |
| ------- | ------- |
| Alpine  | —       |
| Debian  | ~241 MB |
