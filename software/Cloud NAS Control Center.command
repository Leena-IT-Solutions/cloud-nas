#!/usr/bin/env bash
# Double-click this file anytime to open the Cloud NAS Control Center window

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PYTHON_BIN="$(which python3)"
if [ -z "$PYTHON_BIN" ]; then PYTHON_BIN="/usr/bin/python3"; fi
exec "$PYTHON_BIN" "$SCRIPT_DIR/cloud_nas_gui.py" &
