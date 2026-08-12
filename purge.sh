#!/usr/bin/env bash
# Root entry point wrapper for macOS Cloud NAS purge

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec "$SCRIPT_DIR/mac/purge.sh" "$@"
