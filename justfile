# Build all images via docker-bake.hcl
build:
    docker buildx bake

# Run the bash_unit test suite against local images
test:
    @bash tests/run.sh

# Run tests for a single image (e.g. just test-image core)
test-image image:
    @bash tests/run.sh {{image}}

# Shorthand: run tests for the core image only
test-core:
    @bash tests/run.sh core

# Check scheduled images and release tag inputs without Docker (requires yq v4)
test-health:
    @bash tests/bash_unit tests/test_health_workflow.sh
    @bash tests/bash_unit tests/test_ci_workflow.sh
    @bash tests/bash_unit tests/test_release_workflow.sh

# Lint: hadolint + shellcheck + prim fmt --check + prim lint
lint:
    @find images -name 'Dockerfile*' | xargs -r hadolint
    @find scripts tests -name '*.sh' | xargs -r shellcheck
    prim fmt --check
    prim lint

# Format repository files
fmt:
    prim fmt

# Remove local build artefacts
clean:
    docker buildx bake --set '*.output=type=cacheonly' --no-cache 2>/dev/null || true

# Test the npx adapter with a controlled child process
test-npx:
    deno test --allow-all tests/test_npx.ts

# Test the npm adapter with a controlled child process
test-npm:
    deno test --allow-all tests/test_npm.ts
