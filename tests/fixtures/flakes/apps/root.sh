#!/bin/sh
# Succeeds from the root of the checkout of this repository, with GH_TOKEN and
# GITHUB_TOKEN set to the same token.
set -eu
[ -f tests/fixtures/flakes/apps/flake.nix ] || {
  echo "root: not run from the root of the checkout: ${PWD}" >&2
  exit 1
}
[ -n "${GITHUB_TOKEN:-}" ] && [ "${GH_TOKEN:-}" = "${GITHUB_TOKEN}" ] || {
  echo "root: no GH_TOKEN and GITHUB_TOKEN of the job" >&2
  exit 1
}
echo "root: ran from the root of the checkout with the token"
