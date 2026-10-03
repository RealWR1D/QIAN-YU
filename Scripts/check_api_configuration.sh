#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"

cp "$root_dir/QIAN_YU/Resources/EditorialContent.json" "$check_dir/EditorialContent.json"
output_file="$check_dir/check"
swiftc "$root_dir/QIAN_YU/Models/CourseTimeRules.swift" -o "$output_file" \
    "$root_dir/QIAN_YU/Engine/EditorialCopy.swift" \
    "$root_dir/QIAN_YU/Models/AppSettings.swift" \
    "$root_dir/QIAN_YU/Services/LLMService.swift" \
    "$root_dir/QIAN_YU/ViewModels/SettingsViewModel.swift" \
    "$root_dir/QIAN_YU/Engine/PersonaEngine.swift" \
    "$root_dir/Scripts/check_api_configuration.swift"
"$output_file"
