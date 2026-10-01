#!/bin/sh
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d /private/tmp/qianyu-ics-check.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
cp "$root_dir/QIAN_YU/Resources/EditorialContent.json" "$check_dir/EditorialContent.json"
swiftc -parse-as-library -o "$check_dir/check" \
    "$root_dir/QIAN_YU/Engine/EditorialCopy.swift" \
    "$root_dir/QIAN_YU/Models/AppSettings.swift" \
    "$root_dir/QIAN_YU/Models/CourseItem.swift" \
    "$root_dir/QIAN_YU/Widgets/QianYuCourseWidget.swift" \
    "$root_dir/QIAN_YU/Services/ICSParserService.swift" \
    "$root_dir/QIAN_YU/ViewModels/CourseScheduleViewModel.swift" \
    "$root_dir/Scripts/check_ics_import.swift"
"$check_dir/check"
