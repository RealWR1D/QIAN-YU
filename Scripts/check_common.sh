#!/bin/sh
# Shared setup for isolated Swift regression checks. Source from check_*.sh.
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/qianyu-check.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
export SWIFT_MODULECACHE_PATH="$check_dir/modules"
export CLANG_MODULE_CACHE_PATH="$check_dir/clang-modules"
