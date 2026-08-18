#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"
build_root="$project_root/.direct-build"
module_cache="$build_root/ExplicitModuleCache"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
toolchain_overlay="$project_root/Support/ToolchainOverlay.yaml"
output_directory="${1:-$project_root/docs/images}"

mkdir -p "$build_root" "$module_cache" "$output_directory"

source_files=("${(@f)$(find "$project_root/Sources/StemPlayer" -name '*.swift' -type f ! -path '*/App/StemPlayerApp.swift' | sort)}")

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
  "$project_root/Scripts/render-previews.swift" \
  -o "$build_root/render-previews" \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework Accelerate \
  -framework UniformTypeIdentifiers \
  -framework AudioToolbox

env SP4_RENDERING_PREVIEW=1 "$build_root/render-previews" "$output_directory"
