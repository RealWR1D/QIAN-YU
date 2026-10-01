#!/bin/sh
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d /private/tmp/qianyu-api-check.XXXXXX)
output_file="$check_dir/check"
trap 'rm -rf "$check_dir"' EXIT
cp "$root_dir/QIAN_YU/Resources/EditorialContent.json" "$check_dir/EditorialContent.json"
swiftc -o "$output_file" \
    "$root_dir/QIAN_YU/Engine/EditorialCopy.swift" \
    "$root_dir/QIAN_YU/Models/AppSettings.swift" \
    "$root_dir/QIAN_YU/Services/LLMService.swift" \
    "$root_dir/QIAN_YU/ViewModels/SettingsViewModel.swift" \
    "$root_dir/QIAN_YU/Engine/PersonaEngine.swift" \
    "$root_dir/Scripts/check_api_configuration.swift"
"$output_file"
