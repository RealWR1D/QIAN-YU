#!/bin/bash
# Build an arm64 Release IPA for re-signing with the user's free Apple account.
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-"$root_dir/build/ios-sideload"}
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
cd "$root_dir"
if ! xcodebuild -project 'QIAN YU.xcodeproj' -scheme 'QIAN YU' \
    -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath "$output_dir/DerivedData" CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM= ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    SWIFT_EMIT_LOC_STRINGS=NO \
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) QIANYU_SIDELOAD' \
    build > "$output_dir/build-ios.log" 2>&1; then
    tail -n 35 "$output_dir/build-ios.log" >&2
    exit 1
fi
python3 Scripts/package_ipa.py \
    "$output_dir/DerivedData/Build/Products/Release-iphoneos/QIAN YU.app" \
    "$output_dir" --build-version "$(git rev-list --count HEAD)" \
    --commit "$(git rev-parse HEAD)" \
    --repository "${GITHUB_REPOSITORY:-RealWR1D/QIAN-YU}"
