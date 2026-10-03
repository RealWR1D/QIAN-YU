#!/bin/bash
# A single entry point for local checks and CI. Preserve failures and their logs.
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mode=all
output_dir=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --checks-only) mode=checks ;;
        --build-only) mode=build ;;
        --output-dir)
            [ "$#" -ge 2 ] || { echo 'Missing --output-dir value' >&2; exit 2; }
            output_dir=$2
            shift ;;
        --help)
            echo 'Usage: bash Scripts/check_project.sh [--checks-only | --build-only] [--output-dir DIRECTORY]'
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
if [ -z "$output_dir" ]; then
    output_dir=$(mktemp -d "${TMPDIR:-/tmp}/qianyu-validation.XXXXXX")
fi
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
cd "$root_dir"
failed=0
passed=0
summary="$output_dir/summary.txt"
: > "$summary"
echo "Logs: $output_dir"
run_check() {
    local name=$1
    shift
    echo "Running: $name"
    if "$@" > "$output_dir/$name.log" 2>&1; then
        echo "PASS $name" | tee -a "$summary"
        passed=$((passed + 1))
    else
        echo "FAIL $name" | tee -a "$summary"
        tail -n 35 "$output_dir/$name.log"
        failed=$((failed + 1))
    fi
}
if [ "$mode" != build ]; then
    run_check copy python3 Scripts/check_copy.py
    for name in course_time notification_scheduler daily_push daily_content pomodoro api_configuration ics_import distribution_storage; do
        run_check "$name" sh "Scripts/check_$name.sh"
    done
fi
if [ "$mode" != checks ]; then
    for platform in macOS iOS; do
        if [ "$platform" = iOS ]; then
            destination='generic/platform=iOS'
        else
            destination='platform=macOS'
        fi
        run_check "build-$platform" xcodebuild -project 'QIAN YU.xcodeproj' \
            -scheme 'QIAN YU' -configuration Release -destination "$destination" \
            -derivedDataPath "$output_dir/DerivedData-$platform" CODE_SIGNING_ALLOWED=NO build
    done
fi
echo "Result: $passed passed, $failed failed. Logs: $output_dir" | tee -a "$summary"
[ "$failed" -eq 0 ]
