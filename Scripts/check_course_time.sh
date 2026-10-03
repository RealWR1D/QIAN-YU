#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"
swiftc -o "$check_dir/check" "$root_dir/QIAN_YU/Models/CourseTimeRules.swift" "$root_dir/Scripts/check_course_time.swift"
"$check_dir/check"
