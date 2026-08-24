#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Runs the Persian Tuner plugin tests.
#
# The tests need a QML engine. This script creates a throw-away Python venv
# with PySide6 (which ships Qt 6 + qmllint) the first time it runs; set
# PERSIAN_TUNER_VENV to put it somewhere else.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="${PERSIAN_TUNER_VENV:-$HOME/.venv-qt}"

if [ ! -x "$VENV/bin/python" ]; then
    echo "Creating a Python venv with PySide6 in $VENV ..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet PySide6-Essentials
fi

exec "$VENV/bin/python" "$HERE/run_tests.py" "$@"
