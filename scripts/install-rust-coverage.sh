#!/usr/bin/env bash
# Install checksum-pinned upstream binaries matching the active Rust host.
set -euo pipefail

nextest_version="${1:?nextest version required}"
llvm_cov_version="${2:?cargo-llvm-cov version required}"
checksums="${3:?checksum file required}"
host="$(rustc -vV | sed -n 's/^host: //p')"
case "$host" in
  x86_64-unknown-linux-gnu|x86_64-unknown-linux-musl|aarch64-unknown-linux-gnu|aarch64-unknown-linux-musl) ;;
  *) echo "Unsupported Rust coverage host: $host" >&2; exit 1 ;;
esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"
nextest_archive="cargo-nextest-${nextest_version}-${host}.tar.gz"
llvm_cov_archive="cargo-llvm-cov-${llvm_cov_version}-${host}.tar.gz"
curl -fsSL --retry 3 \
  "https://github.com/nextest-rs/nextest/releases/download/cargo-nextest-${nextest_version}/${nextest_archive}" \
  -o "$nextest_archive"
curl -fsSL --retry 3 \
  "https://github.com/taiki-e/cargo-llvm-cov/releases/download/v${llvm_cov_version}/cargo-llvm-cov-${host}.tar.gz" \
  -o "$llvm_cov_archive"
for archive in "$nextest_archive" "$llvm_cov_archive"; do
  # Missing hashes and changed artifacts both abort the build before extraction.
  awk -v archive="$archive" '$2 == archive {print; found = 1} END {if (!found) exit 1}' \
    "$checksums" | sha256sum --check --strict
done
tar -xzf "$nextest_archive" -C "$CARGO_HOME/bin" cargo-nextest
tar -xzf "$llvm_cov_archive" -C "$CARGO_HOME/bin" cargo-llvm-cov
cargo nextest --version
cargo llvm-cov --version
