#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"
swiftc -parse-as-library -o "$check_dir/check" \
    "$root_dir/QIAN_YU/Models/AppInstallationIdentity.swift" \
    "$root_dir/Scripts/check_sideload.swift"
"$check_dir/check"
