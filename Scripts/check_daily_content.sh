#!/bin/sh
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d /private/tmp/qianyu-content-check.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
cp "$root_dir/QIAN_YU/Resources/EditorialContent.json" "$check_dir/EditorialContent.json"
swiftc -module-cache-path "$check_dir/modules" -o "$check_dir/check" \
    "$root_dir/QIAN_YU/Engine/EditorialCopy.swift" \
    "$root_dir/QIAN_YU/Services/DailyPushPlanner.swift" \
    "$root_dir/QIAN_YU/Services/DailyPushContent.swift" \
    "$root_dir/QIAN_YU/Services/DailyPushContentService.swift" \
    "$root_dir/Scripts/check_daily_content.swift"
"$check_dir/check"
