#!/bin/bash
# Build a universal, locally signed Mac package without a paid certificate.
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-"$root_dir/build/distribution"}
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/qianyu-package.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT
cd "$root_dir"
if ! xcodebuild -project 'QIAN YU.xcodeproj' -scheme 'QIAN YU' \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$output_dir/DerivedData" CODE_SIGNING_ALLOWED=NO \
    'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) QIANYU_LOCAL_DISTRIBUTION' \
    build > "$output_dir/build-macos.log" 2>&1; then
    tail -n 35 "$output_dir/build-macos.log" >&2
    echo "Build failed. Log: $output_dir/build-macos.log" >&2
    exit 1
fi
app="$output_dir/DerivedData/Build/Products/Release/QIAN YU.app"
icon_file=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$app/Contents/Info.plist")
case "$icon_file" in *.icns) ;; *) icon_file="$icon_file.icns" ;; esac
[ -s "$app/Contents/Resources/$icon_file" ] || { echo "Missing packaged notification app icon: $icon_file" >&2; exit 1; }
codesign --force --sign - --entitlements QIAN_YU/Widgets/QianYuWidgets.entitlements \
    "$app/Contents/PlugIns/QianYuWidgets.appex"
codesign --force --sign - --entitlements QIAN_YU/QIAN_YU.entitlements "$app"
codesign --verify --deep --strict --verbose=2 "$app"
for arch in arm64 x86_64; do
    lipo "$app/Contents/MacOS/QIAN YU" -verify_arch "$arch"
done
mkdir -p "$work_dir/package"
ditto "$app" "$work_dir/package/QIAN YU.app"
cp Docs/安装与分发.md "$work_dir/package/安装说明.md"
cp Docs/素材与权利说明.md "$work_dir/package/素材与权利说明.md"
archive="$output_dir/QIAN-YU-macOS-universal-local.zip"
ditto -c -k --sequesterRsrc --keepParent "$work_dir/package" "$archive"
(cd "$output_dir" && shasum -a 256 "$(basename "$archive")" > SHA256SUMS.txt)
echo "Package: $archive"
echo 'Locally signed, not notarized. Validate installation, Keychain and widgets on another Mac before publication.'
