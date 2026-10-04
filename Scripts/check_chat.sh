#!/bin/sh
. "$(dirname -- "$0")/check_common.sh"
cp "$root_dir/QIAN_YU/Resources/EditorialContent.json" "$check_dir/EditorialContent.json"
swiftc -parse-as-library -o "$check_dir/check" \
 "$root_dir/QIAN_YU/Models/CourseTimeRules.swift" \
 "$root_dir/QIAN_YU/Models/AppSettings.swift" \
 "$root_dir/QIAN_YU/Models/ChatMessage.swift" \
 "$root_dir/QIAN_YU/Engine/EditorialCopy.swift" \
 "$root_dir/QIAN_YU/Engine/PersonaEngine.swift" \
 "$root_dir/QIAN_YU/Engine/QianYuDialogueCorpus.swift" \
 "$root_dir/QIAN_YU/Services/LLMService.swift" \
 "$root_dir/QIAN_YU/ViewModels/ChatViewModel.swift" \
 "$root_dir/Scripts/check_chat.swift"
"$check_dir/check"
