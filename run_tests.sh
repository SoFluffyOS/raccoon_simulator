#!/usr/bin/env bash
# Analyzes the workspace and runs the unit and widget tests. The end-to-end
# tests need the real runtime and a display; run them with ./e2e.sh.
set -euo pipefail
cd "$(dirname "$0")"

flutter analyze
(cd modules/simulator && flutter test)
(cd apps/raccoon_simulator && flutter test)
