# :jvm

JDK 17 headless runtime. Inherits all `:core` tools. **Debian only** —
this image has no Alpine variant because OpenJDK packaging on Alpine
lacks long-term vendor support.

## Base

| Variant | Base                                       |
| ------- | ------------------------------------------ |
| Debian  | `ghcr.io/driftsys/dock:core-debian` (build |
|         | context)                                   |

> **No Alpine variant.** Use `:jvm-debian` exclusively.

## Installed tools

| Tool    | Install method                | Purpose                   |
| ------- | ----------------------------- | ------------------------- |
| java    | apt (openjdk-17-jdk-headless) | JDK 17 runtime + compiler |
| javac   | apt (openjdk-17-jdk-headless) | Java compiler             |
| keytool | included in JDK               | Certificate management    |

## Environment variables

| Variable    | Value                          |
| ----------- | ------------------------------ |
| `JAVA_HOME` | `/usr/lib/jvm/java-17-openjdk` |

`JAVA_HOME` uses an arch-neutral symlink that works on both
`amd64` and `arm64`.

## Corporate CA support

`dock-bootstrap` automatically updates the JKS truststore when
corporate certificates are detected. On read-only Kubernetes
runners, it builds a private truststore at `/etc/dock/cacerts`
and sets `JAVA_TOOL_OPTIONS=-Djavax.net.ssl.trustStore=/etc/dock/cacerts`
via `/etc/dock/ca.env`.

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

| Variant | Size    |
| ------- | ------- |
| Alpine  | —       |
| Debian  | ~290 MB |
