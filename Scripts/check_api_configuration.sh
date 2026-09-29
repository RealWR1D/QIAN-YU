#!/bin/sh
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_file=$(mktemp /private/tmp/qianyu-api-check.XXXXXX)
trap 'rm -f "$output_file"' EXIT
swiftc -o "$output_file" \
    "$root_dir/QIAN_YU/Models/AppSettings.swift" \
    "$root_dir/QIAN_YU/Services/LLMService.swift" \
    "$root_dir/QIAN_YU/ViewModels/SettingsViewModel.swift" \
    "$root_dir/QIAN_YU/Engine/PersonaEngine.swift" \
    "$root_dir/Scripts/check_api_configuration.swift"
"$output_file"
