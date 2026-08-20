#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"
build_root="$project_root/.direct-build"
app_root="$project_root/dist/Stem Player.app"
contents="$app_root/Contents"
module_cache="$build_root/ExplicitModuleCache"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
toolchain_overlay="$project_root/Support/ToolchainOverlay.yaml"

mkdir -p "$build_root" "$module_cache" "$contents/MacOS" "$contents/Resources"

source_files=("${(@f)$(find "$project_root/Sources/StemPlayer" -name '*.swift' -type f | sort)}")

xcrun swiftc \
  -parse-as-library \
  -swift-version 5 \
  -target arm64-apple-macosx14.0 \
  -sdk "$sdk_path" \
  -module-cache-path "$module_cache" \
  -explicit-module-build \
  -Xcc -ivfsoverlay \
  -Xcc "$toolchain_overlay" \
  -j 8 \
  -O \
  "${source_files[@]}" \
  -o "$contents/MacOS/StemPlayer" \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework Accelerate \
  -framework ScreenCaptureKit \
  -framework UniformTypeIdentifiers \
  -framework AudioToolbox

cp "$project_root/Support/Info.plist" "$contents/Info.plist"
cp "$project_root/Helpers/stem-worker/target/release/stem-worker" "$contents/Resources/stem-worker"
chmod 755 "$contents/MacOS/StemPlayer" "$contents/Resources/stem-worker"

icon_work="$build_root/AppIcon"
mkdir -p "$icon_work" "$icon_work/AppIcon.iconset"
icon_source="$icon_work/AppIcon.svg.png"
xcrun swiftc \
  -target arm64-apple-macosx14.0 \
  -sdk "$sdk_path" \
  -module-cache-path "$module_cache" \
  -explicit-module-build \
  -Xcc -ivfsoverlay \
  -Xcc "$toolchain_overlay" \
  -O \
  "$project_root/Scripts/render-icon.swift" \
  -o "$icon_work/render-icon" \
  -framework AppKit
"$icon_work/render-icon" "$icon_source"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$icon_source" --out "$icon_work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$icon_source" --out "$icon_work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
"$icon_work/render-icon" --icns "$contents/Resources/AppIcon.icns" \
  icp4 "$icon_work/AppIcon.iconset/icon_16x16.png" \
  icp5 "$icon_work/AppIcon.iconset/icon_32x32.png" \
  icp6 "$icon_work/AppIcon.iconset/icon_32x32@2x.png" \
  ic07 "$icon_work/AppIcon.iconset/icon_128x128.png" \
  ic08 "$icon_work/AppIcon.iconset/icon_256x256.png" \
  ic09 "$icon_work/AppIcon.iconset/icon_512x512.png" \
  ic10 "$icon_work/AppIcon.iconset/icon_512x512@2x.png"

codesign --force --sign - "$contents/Resources/stem-worker"
codesign --force --deep --sign - "$app_root"
echo "$app_root"
