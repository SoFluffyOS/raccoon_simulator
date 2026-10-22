#!/usr/bin/env bash
# Resolves the workspace.
set -euo pipefail
cd "$(dirname "$0")"

flutter pub get
