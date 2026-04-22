#!/bin/sh
# dock-bootstrap — prepare a dock container for the corporate environment.
#
# Detects CA certificates from three sources and imports them into the
# system trust store so all tools (curl, git, cargo, npm, pip, deno, …)
# trust internal TLS endpoints.
#
# Sources (checked in order):
#   1. Environment variables containing PEM-encoded certificates
#   2. .crt/.pem files in a drop directory (default: /etc/dock/ca.d)
#   3. CI_SERVER_TLS_CA_FILE (GitLab runner-provided CA file)
#
# Usage:
#   dock-bootstrap              # scan env + /etc/dock/ca.d
#   dock-bootstrap /path/to/dir # scan env + custom directory
#   DOCK_SKIP_CA=1 dock-bootstrap  # skip CA detection entirely
#
# Shebang: #!/bin/sh (not bash) — intentionally POSIX-compatible so it
# works in downstream images that may not install bash.
set -eu

CERT_DIR="${1:-/etc/dock/ca.d}"
DEST="/usr/local/share/ca-certificates"
COUNT=0

# -------------------------------------------------------------------------
# 0. Early exit
# -------------------------------------------------------------------------
if [ "${DOCK_SKIP_CA:-0}" = "1" ]; then
  echo "dock-bootstrap: DOCK_SKIP_CA=1, skipping" >&2
  exit 0
fi

# -------------------------------------------------------------------------
# 1. Scan environment variables for PEM-encoded certificates
# -------------------------------------------------------------------------
env_import() {
  env | while IFS='=' read -r name rest; do
    # Skip variables that are unlikely to contain certs
    case "$name" in
      DOCKER_AUTH_CONFIG|GITLAB_FEATURES|CI_*_TOKEN|*PASSWORD*|*SECRET*) continue ;;
    esac
    val=$(printenv "$name" 2>/dev/null) || continue
    case "$val" in
      *"-----BEGIN CERTIFICATE-----"*)
        # Extract each PEM cert block (a variable may contain multiple)
        echo "$val" | awk '
          /-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/ {
            print
            if (/-----END CERTIFICATE-----/) {
              printf "\n"
            }
          }
        ' | csplit -sz -f "$DEST/env-${name}-" -b '%02d.crt' - \
              '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null || true
        ;;
    esac
  done
}

env_import

# Count env-var certs (the pipe subshell cannot update COUNT directly).
for f in "$DEST"/env-*.crt; do
  [ -f "$f" ] && COUNT=$((COUNT + 1))
done

# -------------------------------------------------------------------------
# 2. Import .crt/.pem files from the drop directory
# -------------------------------------------------------------------------
if [ -d "$CERT_DIR" ]; then
  for cert in "$CERT_DIR"/*.crt "$CERT_DIR"/*.pem; do
    [ -f "$cert" ] || continue
    base=$(basename "$cert")
    case "$base" in
      *.crt) cp -f "$cert" "$DEST/$base" ;;
      *.pem) cp -f "$cert" "$DEST/${base%.pem}.crt" ;;
    esac
    COUNT=$((COUNT + 1))
  done
fi

# -------------------------------------------------------------------------
# 3. Import CI_SERVER_TLS_CA_FILE (GitLab-specific)
# -------------------------------------------------------------------------
if [ -n "${CI_SERVER_TLS_CA_FILE:-}" ] && [ -f "$CI_SERVER_TLS_CA_FILE" ]; then
  cp -f "$CI_SERVER_TLS_CA_FILE" "$DEST/ci-server-tls-ca.crt"
  COUNT=$((COUNT + 1))
fi

# -------------------------------------------------------------------------
# 4. Update the system trust store
# -------------------------------------------------------------------------
if [ "$COUNT" -gt 0 ]; then
  update-ca-certificates 2>/dev/null
  echo "dock-bootstrap: imported $COUNT certificate source(s) into trust store"
else
  echo "dock-bootstrap: no certificates found, trust store unchanged"
fi
