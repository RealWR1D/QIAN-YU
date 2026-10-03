#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"
swiftc -o "$check_dir/check" "$root_dir/QIAN_YU/Services/NotificationScheduler.swift" "$root_dir/Scripts/check_notification_scheduler.swift"
"$check_dir/check"
