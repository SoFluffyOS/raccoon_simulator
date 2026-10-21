#!/usr/bin/env bash
# End to end on this machine: the runtime panel's checks and fixes (builds the
# runner when it is missing), then the simulator window running a project on
# Raccoon. Needs a display. Arguments:
#
#   ./e2e.sh [project folder] [screenshot folder]
#
# The project defaults to the runner's example/hello; it must be an app like
# it (a box in the middle that turns green on a tap).
set -euo pipefail
cd "$(dirname "$0")"

case "$(uname -s)" in
  Darwin) desktop=macos ;;
  *) desktop=linux ;;
esac

project="${1:-$PWD/native/raccoon_runner/example/hello}"
defines=(--dart-define="RACCOON_E2E_PROJECT=$project")
if [ -n "${2:-}" ]; then
  defines+=(--dart-define="RACCOON_E2E_SCREENSHOTS=$2")
fi

(cd modules/simulator && RACCOON_E2E=1 flutter test test/e2e/runtime_setup_e2e_test.dart)
(cd apps/raccoon_simulator && flutter test integration_test/hello_e2e_test.dart -d "$desktop" "${defines[@]}")
