#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"

cp "$root_dir/QIAN_YU/Resources/EditorialContent.json" "$check_dir/EditorialContent.json"
swiftc "$root_dir/QIAN_YU/Models/CourseTimeRules.swift" -module-cache-path "$check_dir/modules" -o "$check_dir/check" \
    "$root_dir/QIAN_YU/Engine/EditorialCopy.swift" \
    "$root_dir/QIAN_YU/Services/DailyPushPlanner.swift" \
    "$root_dir/QIAN_YU/Services/DailyPushContent.swift" \
    "$root_dir/QIAN_YU/Services/DailyPushContentService.swift" \
    "$root_dir/Scripts/check_daily_content.swift"
"$check_dir/check"
