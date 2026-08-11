#!/usr/bin/env bash
# Double-click this file anytime to open the Cloud NAS Control Center window

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
python3 "$SCRIPT_DIR/cloud_nas_gui.py" &
