# Build all images via docker-bake.hcl
build:
    docker buildx bake

# Run the bash_unit test suite against local images
test:
    @bash tests/run.sh

# Lint: hadolint + shellcheck + dprint check
lint:
    @find images -name 'Dockerfile*' | xargs -r hadolint
    @find scripts -name '*.sh' | xargs -r shellcheck
    dprint check

# Format Markdown
fmt:
    dprint fmt

# Remove local build artefacts
clean:
    docker buildx bake --set '*.output=type=cacheonly' --no-cache 2>/dev/null || true
