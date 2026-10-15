#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
python3 ./script/check_xcode_project.py
./script/test.sh
./script/build_and_run.sh --build-only
git diff --check
echo "Tests, Build und Signaturprüfung erfolgreich. Sichtbare Fensterfunktion separat prüfen."
