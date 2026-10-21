#!/usr/bin/env bash
# Resolves the workspace. Pub rewrites raccoon_view's example
# .flutter-plugins-dependencies, which that repository tracks; put it back so
# the submodule stays clean.
set -euo pipefail
cd "$(dirname "$0")"

flutter pub get
git -C packages/raccoon_view checkout -- example/.flutter-plugins-dependencies
