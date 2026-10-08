#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
if [[ ! -d "$PROJECT_DIR/日历打勾.app" ]]; then
    /bin/zsh "$PROJECT_DIR/build.sh"
fi
open "$PROJECT_DIR/日历打勾.app"
