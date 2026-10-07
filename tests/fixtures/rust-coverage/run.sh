#!/usr/bin/env bash
# Run in a writable copy. Keep test status while rendering coverage after failure.
set -euo pipefail

export CARGO_NET_OFFLINE=true
export CARGO_LLVM_COV_SETUP=no
status=0
cargo llvm-cov clean --workspace
cargo llvm-cov --no-report nextest --profile ci "$@" || status=$?
mkdir -p reports
cp target/nextest/ci/junit.xml reports/junit.xml
cargo llvm-cov report --cobertura --output-path reports/cobertura.xml
cargo llvm-cov report --lcov --output-path reports/lcov.info
cargo llvm-cov report --json --summary-only --output-path reports/summary.json
exit "$status"
