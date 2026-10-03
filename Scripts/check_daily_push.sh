#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"

swiftc "$root_dir/QIAN_YU/Models/CourseTimeRules.swift" -module-cache-path "$check_dir/modules" -o "$check_dir/check" "$root_dir/QIAN_YU/Services/DailyPushPlanner.swift" "$root_dir/Scripts/check_daily_push.swift"
"$check_dir/check"
