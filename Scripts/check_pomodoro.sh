#!/bin/sh
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d /private/tmp/qianyu-pomodoro-check.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
swiftc -module-cache-path "$check_dir/modules" -o "$check_dir/check" \
    "$root_dir/QIAN_YU/Models/PomodoroActivityAttributes.swift" \
    "$root_dir/QIAN_YU/ViewModels/PomodoroTimerViewModel.swift" \
    "$root_dir/Scripts/check_pomodoro.swift"
"$check_dir/check"
