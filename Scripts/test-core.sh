#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"
test_binary="$project_root/.direct-build/StemPlayerCoreTests"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"

xcrun swiftc \
  -parse-as-library \
  -swift-version 5 \
  -target arm64-apple-macosx14.0 \
  -sdk "$sdk_path" \
  -module-cache-path "$project_root/.direct-build/ExplicitModuleCache" \
  -explicit-module-build \
  -Xcc -ivfsoverlay \
  -Xcc "$project_root/Support/ToolchainOverlay.yaml" \
  -j 8 \
  -Onone \
  Sources/StemPlayer/Model/StemProject.swift \
  Sources/StemPlayer/Utilities/Extensions.swift \
  Sources/StemPlayer/Services/ProjectStore.swift \
  Sources/StemPlayer/Services/AudioImportService.swift \
  Sources/StemPlayer/Services/MixExporter.swift \
  Sources/StemPlayer/Audio/WaveformAnalyzer.swift \
  Sources/StemPlayer/Audio/DrumSoundFactory.swift \
  Sources/StemPlayer/Audio/AudioEngineController.swift \
  Tests/DirectIntegrationTests.swift \
  -o "$test_binary" \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework Accelerate \
  -framework AudioToolbox

"$test_binary"
