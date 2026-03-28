# :core

Foundation image for all `dock` images. Contains the scripting and data
tools every CI pipeline needs.

## Base images

| Variant          | Base                   |
| ---------------- | ---------------------- |
| Alpine (default) | `alpine:3.21`          |
| Debian           | `debian:bookworm-slim` |

## Installed packages

| Tool            | Alpine package  | Debian package  | Purpose                           |
| --------------- | --------------- | --------------- | --------------------------------- |
| bash            | bash            | bash            | Shell                             |
| curl            | curl            | curl            | HTTP client                       |
| git             | git             | git             | Version control                   |
| git-lfs         | git-lfs         | git-lfs         | Large file storage                |
| gpg             | gnupg           | gnupg           | Signature verification            |
| jq              | jq              | jq              | JSON processor                    |
| yq              | yq-go           | binary install  | YAML/TOML/JSON processor          |
| envsubst        | gettext         | gettext-base    | Environment variable substitution |
| dotenv          | dotenv          | shell script    | .env file loader                  |
| ssh             | openssh-client  | openssh-client  | SSH client                        |
| patch           | patch           | patch           | File patching                     |
| find            | findutils       | findutils       | File search                       |
| tree            | tree            | tree            | Directory listing                 |
| diff            | diffutils       | diffutils       | File comparison                   |
| zip / unzip     | zip, unzip      | zip, unzip      | Archive tools                     |
| tzdata          | tzdata          | tzdata          | Timezone data                     |
| coreutils       | coreutils       | coreutils       | GNU core utilities                |
| ca-certificates | ca-certificates | ca-certificates | TLS root certificates             |

## Runtime manifest

```bash
docker run --rm ghcr.io/driftsys/dock:core jq . /etc/dock/manifest.json
```

## Approximate size

- Alpine: ~32 MB
- Debian: ~80 MB
