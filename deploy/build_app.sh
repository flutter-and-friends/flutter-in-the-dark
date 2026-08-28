#!/bin/sh
# Build the app image with the build-version marker baked in.
#
# The Docker build stage has no .git (see deploy/Dockerfile.app), so the git
# short hash + build timestamp are computed HERE on the host and passed in as
# build args. `docker compose build app` without this script still works, but
# the app then renders its `dev` fallback marker instead of the real hash.
#
# Usage (from the repo root):
#   sh deploy/build_app.sh            # build only
#   sh deploy/build_app.sh --up       # build, then `docker compose up -d app`
set -eu

export GIT_HASH="$(git rev-parse --short HEAD)"
export BUILD_TIME="$(date -u +%Y-%m-%dT%H:%MZ)"

echo "app image marker: GIT_HASH=$GIT_HASH BUILD_TIME=$BUILD_TIME"
docker compose build app

if [ "${1:-}" = "--up" ]; then
  docker compose up -d app
fi
