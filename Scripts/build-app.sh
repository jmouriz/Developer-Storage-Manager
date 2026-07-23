#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
configuration=${1:-debug}
build_dir="$project_dir/.build"
app_dir="$build_dir/Developer Storage Manager.app"
contents_dir="$app_dir/Contents"
resources_dir="$contents_dir/Resources"
asset_catalog_dir="$build_dir/AppAssets.xcassets"
iconset_dir="$asset_catalog_dir/AppIcon.appiconset"

cd "$project_dir"
swift build --disable-sandbox -c "$configuration"
binary_dir=$(swift build --disable-sandbox -c "$configuration" --show-bin-path)
binary_path="$binary_dir/DeveloperStorageManager"

mkdir -p "$contents_dir/MacOS" "$resources_dir" "$iconset_dir"
cp "$binary_path" "$contents_dir/MacOS/DeveloperStorageManager"

resource_bundle="$binary_dir/DeveloperStorageManager_DeveloperStorageManager.bundle"
if [[ -d "$resource_bundle" ]]; then
    cp -R "$resource_bundle" "$resources_dir/"
fi

icon_source="$project_dir/Assets/AppIcon.png"
sips -z 16 16 "$icon_source" --out "$iconset_dir/icon_16x16.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset_dir/icon_32x32.png" >/dev/null
sips -z 64 64 "$icon_source" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$icon_source" --out "$iconset_dir/icon_128x128.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset_dir/icon_256x256.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset_dir/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$icon_source" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null
cp "$project_dir/Scripts/AppIconContents.json" "$iconset_dir/Contents.json"
xcrun actool "$asset_catalog_dir" \
    --compile "$resources_dir" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$build_dir/AppIcon-Info.plist" \
    >/dev/null

sed "s/@VERSION@/0.4.6/g" "$project_dir/Scripts/Info.plist.template" > "$contents_dir/Info.plist"
printf 'APPL????' > "$contents_dir/PkgInfo"
codesign --force --deep --sign - "$app_dir"
touch "$app_dir"

echo "$app_dir"
