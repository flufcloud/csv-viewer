#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
source_app="$project_dir/dist/CSV Viewer.app"
destination="$HOME/Applications/CSV Viewer.app"

if [[ ${1:-} == "--use-built" ]]; then
    if [[ ! -d "$source_app" ]]; then
        print -u2 "Built app not found: $source_app"
        exit 1
    fi
else
    "$project_dir/scripts/build-app.sh" release
fi
mkdir -p "$HOME/Applications"
ditto "$source_app" "$destination"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$destination"

print "Installed: $destination"
print "Finder: right-click a .csv file → Open With → CSV Viewer"
