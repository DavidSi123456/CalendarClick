#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
mkdir -p .build/iOSChecks/ModuleCache
swiftc -swift-version 5 -module-cache-path .build/iOSChecks/ModuleCache \
  Sources/CompletionCore.swift iOS/Sources/{AgendaCore,CalendarRepository,DemoData,AgendaModel}.swift \
  iOS/Tests/AgendaChecks.swift -framework EventKit -o .build/iOSChecks/Checks
.build/iOSChecks/Checks
