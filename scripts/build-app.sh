#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
configuration=${1:-release}
app_dir="$project_dir/dist/CSV Viewer.app"
contents_dir="$app_dir/Contents"
binary_dir="$contents_dir/MacOS"

cd "$project_dir"
module_cache="$project_dir/.build/ModuleCache"
env CLANG_MODULE_CACHE_PATH="$module_cache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
    swift build --disable-sandbox -c "$configuration"

mkdir -p "$binary_dir"
cp ".build/$configuration/CSVViewer" "$binary_dir/CSVViewer"
cp "Info.plist" "$contents_dir/Info.plist"
codesign --force --sign - "$app_dir"

print "Built: $app_dir"
