#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"

cp "$root_dir/QIAN_YU/Resources/EditorialContent.json" "$check_dir/EditorialContent.json"
swiftc "$root_dir/QIAN_YU/Models/CourseTimeRules.swift" -parse-as-library -o "$check_dir/check" \
    "$root_dir/QIAN_YU/Engine/EditorialCopy.swift" \
    "$root_dir/QIAN_YU/Models/AppSettings.swift" \
    "$root_dir/QIAN_YU/Models/CourseItem.swift" \
    "$root_dir/QIAN_YU/Widgets/QianYuCourseWidget.swift" \
    "$root_dir/QIAN_YU/Services/ICSParserService.swift" \
    "$root_dir/QIAN_YU/Services/ICSImportModels.swift" \
    "$root_dir/QIAN_YU/Services/ICSFileDecoder.swift" \
    "$root_dir/QIAN_YU/Services/ICSRecurrenceParser.swift" \
    "$root_dir/QIAN_YU/Services/ICSSemesterDetector.swift" \
    "$root_dir/QIAN_YU/Services/ICSCourseConverter.swift" \
    "$root_dir/QIAN_YU/ViewModels/CourseScheduleViewModel.swift" \
    "$root_dir/Scripts/check_ics_import.swift"
"$check_dir/check"
