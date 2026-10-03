#!/bin/sh
# Exercise the real schema under an ad hoc signature with App Group entitlements.
. "$(dirname -- "$0")/check_common.sh"
swiftc -D QIANYU_LOCAL_DISTRIBUTION -o "$check_dir/check" \
    "$root_dir/QIAN_YU/Models/CourseTimeRules.swift" \
    "$root_dir/QIAN_YU/Engine/EditorialCopy.swift" \
    "$root_dir/QIAN_YU/Models/AppSettings.swift" \
    "$root_dir/QIAN_YU/Models/ChatMessage.swift" \
    "$root_dir/QIAN_YU/Models/CourseItem.swift" \
    "$root_dir/Scripts/check_distribution_storage.swift"
codesign --force --sign - --entitlements "$root_dir/QIAN_YU/QIAN_YU.entitlements" "$check_dir/check"
"$check_dir/check" write "$check_dir/distribution.store"
"$check_dir/check" read "$check_dir/distribution.store"
