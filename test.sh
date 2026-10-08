#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"
mkdir -p .build/ModuleCache
swiftc -swift-version 5 -module-cache-path "$PROJECT_DIR/.build/ModuleCache" \
    Sources/CompletionCore.swift Tests/CoreTests.swift -o .build/CoreTests
.build/CoreTests
