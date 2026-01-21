#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios/MusicStoryRenderer"

init_swiftenv() {
  if command -v swiftenv >/dev/null 2>&1; then
    export PATH="$HOME/.swiftenv/bin:$PATH"
    eval "$(swiftenv init -)"
  fi
}

case "${1:-}" in
  generate)
    (cd "$IOS_DIR" && xcodegen generate)
    ;;
  build)
    (cd "$IOS_DIR" && xcodebuild -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" build)
    ;;
  test)
    (cd "$IOS_DIR" && xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16")
    ;;
  swift-test)
    init_swiftenv
    (cd "$IOS_DIR" && swift test)
    ;;
  clean)
    (cd "$IOS_DIR" && xcodebuild clean -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer)
    ;;
  *)
    echo "Usage: $0 {generate|build|test|swift-test|clean}"
    exit 1
    ;;
esac
