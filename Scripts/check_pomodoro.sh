#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"

swiftc -module-cache-path "$check_dir/modules" -o "$check_dir/check" \
    "$root_dir/QIAN_YU/Models/PomodoroActivityAttributes.swift" \
    "$root_dir/QIAN_YU/ViewModels/PomodoroTimerViewModel.swift" \
    "$root_dir/Scripts/check_pomodoro.swift"
"$check_dir/check"
