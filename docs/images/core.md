# :core

Foundation image for all `dock` images. Contains the scripting and data
tools every CI pipeline needs.

## Base images

| Variant          | Base                 |
| ---------------- | -------------------- |
| Alpine (default) | `alpine:3.24`        |
| Debian           | `debian:trixie-slim` |

## Installed packages

| Tool            | Alpine package      | Debian package  | Purpose                                |
| --------------- | ------------------- | --------------- | -------------------------------------- |
| bash            | bash                | bash            | Shell                                  |
| curl            | curl                | curl            | HTTP client                            |
| git             | git                 | git             | Version control                        |
| git-lfs         | git-lfs             | git-lfs         | Large file storage                     |
| gpg             | gnupg               | gnupg           | Signature verification                 |
| jq              | jq                  | jq              | JSON processor                         |
| yq              | yq-go               | binary install  | YAML/TOML/JSON processor               |
| envsubst        | gettext             | gettext-base    | Environment variable substitution      |
| dotenv          | shell script        | shell script    | .env file loader                       |
| ssh             | openssh-client      | openssh-client  | SSH client                             |
| patch           | patch               | patch           | File patching                          |
| rsync           | rsync (tagged edge) | rsync           | Workspace and artifact synchronization |
| rg              | ripgrep             | ripgrep         | Source, configuration, and log search  |
| find            | findutils           | findutils       | File search                            |
| tree            | tree                | tree            | Directory listing                      |
| diff            | diffutils           | diffutils       | File comparison                        |
| zip / unzip     | zip, unzip          | zip, unzip      | Archive tools                          |
| tzdata          | tzdata              | tzdata          | Timezone data                          |
| coreutils       | coreutils           | coreutils       | GNU core utilities                     |
| ca-certificates | ca-certificates     | ca-certificates | TLS root certificates                  |

## Runtime manifest

The shared manifest records `rsync` and `ripgrep` versions alongside the
other core tools. Both variants use Alpine or Debian packages.

```bash
docker run --rm ghcr.io/driftsys/dock:core jq . /etc/dock/manifest.json
```

## Rsync compatibility

Core tests verify that rsync copies retained files and excludes files when
`--exclude-from` receives a Bash process-substitution path:

```bash
rsync -a --exclude-from=<(printf '%s\n' drop.txt) source/ target/
```

This guards against the [rsync 3.5.0 regression][rsync-process-substitution]
that prevents tools such as `gitlab-ci-local` from reading exclusion lists.
Compatibility is determined by this behavior test; rsync 3.5.1 is not a
minimum version requirement.

Alpine 3.24 currently packages the affected rsync 3.5.0. The Alpine core
image selects rsync from the official edge main repository using the
`@rsync` tag. Other core packages use Alpine 3.24; the tested edge package
works with its libraries. Debian uses the standard trixie package.
The tagged repository remains available for package operations in derived
images. Recheck the stable package with the regression test before removing
this exception.

[rsync-process-substitution]: https://github.com/RsyncProject/rsync/issues/1053

## Approximate size

Compressed download size for `linux/amd64`.

| Variant | Size   |
| ------- | ------ |
| Alpine  | ~38 MB |
| Debian  | ~89 MB |
