#!/usr/bin/env bash
# Execute the coverage contract against an explicit image without networking.
set -euo pipefail
image="${1:?image reference required}"
tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
timeout "${TEST_TIMEOUT:-300}" docker run --rm --network none \
  -v "$tests_dir:/tests:ro" \
  -v "$tests_dir/fixtures:/fixtures:ro" \
  "$image" bash /tests/bash_unit \
  -p 'test_coverage|test_llvm_tools|test_cargo_nextest|test_cargo_llvm_cov|test_rust_image_omits' \
  /tests/test_rust.sh
