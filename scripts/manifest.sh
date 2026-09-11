#!/usr/bin/env bash
# scripts/manifest.sh — generate/update /etc/dock/manifest.json in an image layer.
#
# Usage (from a Dockerfile RUN instruction):
#   RUN manifest.sh <image> <version> [name:cmd ... | name=value ...]
#
# Writes: /etc/dock/manifest.json
#
# Each extra argument is one of:
#   name:cmd [args...]   resolve the tool's version by running `cmd args...`
#   name=value           record `value` literally — for a version already
#                         known exactly (e.g. an Android SDK/NDK component
#                         pinned by a Dockerfile ARG, which has no `--version`
#                         command of its own to probe)
#
# Every image ultimately inherits from :core or :core-debian, so if
# /etc/dock/manifest.json already exists (written by an ancestor layer)
# with a usable "tools" object, its tools are merged into — not replaced
# by — this layer's own. Otherwise (no manifest yet, or an unusable one)
# this layer seeds the fixed baseline below first.
set -euo pipefail

IMAGE="${1:?image name required (e.g. core)}"
VERSION="${2:?image version required (e.g. 1.0.0)}"
shift 2

MANIFEST=/etc/dock/manifest.json

BASELINE=(
  "git:git --version"
  "git-lfs:git-lfs version"
  "bash:bash --version"
  "curl:curl --version"
  "jq:jq --version"
  "yq:yq --version"
  "gpg:gpg --version"
  "ssh:ssh -V"
)

resolve_version() {
  local cmd="$1"
  shift
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "n/a"
    return
  fi
  # Never let a tool's own exit status, or a --version banner with no
  # digit run for grep to match, escape as this function's exit status:
  # under `set -o pipefail` either one would otherwise abort the whole
  # script (a bare `version="$(resolve_version ...)"` at the call site
  # is a plain assignment, so its failure trips `set -e`).
  local output version
  output="$("$cmd" "$@" 2>&1)" || true
  version="$(printf '%s' "$output" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
  if [ -z "$version" ]; then
    echo "n/a"
  else
    echo "$version"
  fi
}

mkdir -p /etc/dock

# Trust an inherited manifest.json only if it actually has a "tools" object;
# anything else (no file, unparseable file, unexpected shape) reseeds the
# baseline instead of silently merging into an empty/foreign one.
tools_json='{}'
if [ -f "$MANIFEST" ] &&
  tools_type="$(jq -r '.tools | type' "$MANIFEST" 2>/dev/null)" &&
  [ "$tools_type" = "object" ]; then
  tools_json="$(jq -c '.tools' "$MANIFEST")"
else
  set -- "${BASELINE[@]}" "$@"
fi

pairs=""
for spec in "$@"; do
  # Whichever of ':' or '=' appears first decides the form — not whichever
  # case arm happens to be checked first — so a literal value containing a
  # colon (e.g. a URL) isn't misparsed as a resolve-form command.
  colon_idx=-1
  equals_idx=-1
  case "$spec" in *:*) tmp="${spec%%:*}"; colon_idx=${#tmp} ;; esac
  case "$spec" in *=*) tmp="${spec%%=*}"; equals_idx=${#tmp} ;; esac

  if [ "$colon_idx" -ge 0 ] && { [ "$equals_idx" -lt 0 ] || [ "$colon_idx" -lt "$equals_idx" ]; }; then
    name="${spec%%:*}"
    read -r -a parts <<< "${spec#*:}"
    if [ "${#parts[@]}" -eq 0 ]; then
      echo "manifest.sh: malformed tool spec (empty command after ':'): $spec" >&2
      exit 1
    fi
    value="$(resolve_version "${parts[@]}")"
  elif [ "$equals_idx" -ge 0 ]; then
    name="${spec%%=*}"
    value="${spec#*=}"
  else
    echo "manifest.sh: malformed tool spec (want name:cmd or name=value): $spec" >&2
    exit 1
  fi
  pairs="${pairs}${name}	${value}
"
done

if [ -n "$pairs" ]; then
  tools_json="$(printf '%s' "$pairs" | jq -R -s -c --argjson base "$tools_json" '
    [splits("\n") | select(length > 0) | split("\t")] as $pairs
    | reduce $pairs[] as $p ($base; .[$p[0]] = $p[1])
  ')"
fi

jq -n \
  --arg image "$IMAGE" \
  --arg version "$VERSION" \
  --arg built_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson tools "$tools_json" \
  '{image: $image, version: $version, built_at: $built_at, tools: $tools}' \
  > "$MANIFEST"
