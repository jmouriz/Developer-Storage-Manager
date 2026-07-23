#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
volume_name="Developer Storage Manager"
output_dir="$project_dir/.build"
output_dmg="$output_dir/Developer Storage Manager.dmg"
temporary_dir=$(mktemp -d /private/tmp/developer-storage-manager-dmg.XXXXXX)
staging_dir="$temporary_dir/staging"
readwrite_dmg="$temporary_dir/Developer Storage Manager-rw.dmg"
volume_path=""
device=""

cleanup() {
    if [[ -n "$device" ]]; then
        hdiutil detach "$device" -quiet || true
    fi
    rm -rf "$temporary_dir"
}
trap cleanup EXIT

"$project_dir/Scripts/build-app.sh" release >/dev/null

mkdir -p "$staging_dir" "$output_dir"
cp -R "$output_dir/Developer Storage Manager.app" "$staging_dir/"
cp "$project_dir/Assets/DMGBackground.png" "$staging_dir/Developer Storage Manager.app/Contents/Resources/DMGBackground.png"
codesign --force --deep --sign - "$staging_dir/Developer Storage Manager.app"
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_dir" \
    -format UDRW \
    -ov \
    "$readwrite_dmg" \
    >/dev/null

attach_plist="$temporary_dir/attach.plist"
hdiutil attach "$readwrite_dmg" \
    -readwrite \
    -noverify \
    -noautoopen \
    -plist \
    > "$attach_plist"

for index in {0..7}; do
    candidate_path=$(/usr/libexec/PlistBuddy -c "Print :system-entities:$index:mount-point" "$attach_plist" 2>/dev/null || true)
    if [[ -n "$candidate_path" ]]; then
        volume_path="$candidate_path"
        device=$(/usr/libexec/PlistBuddy -c "Print :system-entities:$index:dev-entry" "$attach_plist")
        break
    fi
done

if [[ -z "$device" || -z "$volume_path" ]]; then
    echo "No se pudo determinar el volumen temporal montado." >&2
    exit 1
fi
mounted_volume_name=${volume_path:t}

osascript "$project_dir/Scripts/configure-dmg.applescript" "$mounted_volume_name"
sync

if [[ -d "$volume_path" && "$volume_path" == /Volumes/* ]]; then
    rm -rf \
        "$volume_path/.fseventsd" \
        "$volume_path/.Trashes" \
        "$volume_path/.Spotlight-V100" \
        "$volume_path/.TemporaryItems"
fi

hdiutil detach "$device" -quiet
device=""

hdiutil convert "$readwrite_dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "$output_dmg" \
    >/dev/null

codesign --force --sign - "$output_dmg"
osascript "$project_dir/Scripts/set-file-icon.applescript" \
    "$project_dir/Assets/AppIcon.png" \
    "$output_dmg"
echo "$output_dmg"
