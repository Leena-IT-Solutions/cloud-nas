#!/usr/bin/env bash
# macOS 1-Click Cloud NAS Purge & Uninstall Script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/drive_config.json"
PLIST_PATH="$HOME/Library/LaunchAgents/com.cloudnas.controlcenter.plist"
APP_DIR="$HOME/Applications/Cloud NAS.app"
RCLONE_BIN="$SCRIPT_DIR/rclone"

if [ ! -f "$RCLONE_BIN" ]; then
    RCLONE_BIN="rclone"
fi

VOL_NAME="Cloud NAS"
if [ -f "$CONFIG_FILE" ]; then
    PARSED_NAME="$(grep -o '"volname": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
    if [ -n "$PARSED_NAME" ]; then
        VOL_NAME="$PARSED_NAME"
    fi
fi

echo "============================================================"
echo "      🗑️ macOS 1-Click Cloud NAS Purge & Uninstall 🗑️"
echo "============================================================"

# 1. Unmount Drive & Clean All Possible Mount Points
echo "[INFO] Unmounting Cloud NAS drive ($VOL_NAME)..."
diskutil unmount force "$HOME/$VOL_NAME" >/dev/null 2>&1
umount -f "$HOME/$VOL_NAME" >/dev/null 2>&1

diskutil unmount force "$HOME/CloudNAS" >/dev/null 2>&1
umount -f "$HOME/CloudNAS" >/dev/null 2>&1

diskutil unmount force "$HOME/Cloud NAS" >/dev/null 2>&1
umount -f "$HOME/Cloud NAS" >/dev/null 2>&1

diskutil unmount force "$HOME/NAS" >/dev/null 2>&1
umount -f "$HOME/NAS" >/dev/null 2>&1

# 2. Stop Rclone Processes & GUI
echo "[INFO] Terminating rclone background processes and Control Center..."
pkill -9 -f "rclone mount" >/dev/null 2>&1
pkill -9 -f "cloud_nas_gui.py" >/dev/null 2>&1

# 3. Remove LaunchAgent
if [ -f "$PLIST_PATH" ]; then
    echo "[INFO] Removing auto-mount LaunchAgent..."
    launchctl unload "$PLIST_PATH" >/dev/null 2>&1
    rm -f "$PLIST_PATH"
fi

# 4. Remove macOS Applications Bundle
if [ -d "$APP_DIR" ]; then
    echo "[INFO] Removing Cloud NAS from macOS Applications & Launchpad..."
    rm -rf "$APP_DIR"
fi

# 5. Remove Rclone Remote Config
echo "[INFO] Removing GCS remote configuration..."
"$RCLONE_BIN" config delete gcsnas >/dev/null 2>&1

# 6. Remove Mount Directories & Config
rm -rf "$HOME/$VOL_NAME" "$HOME/CloudNAS" "$HOME/Cloud NAS" "$HOME/NAS" >/dev/null 2>&1
rm -f "$CONFIG_FILE" >/dev/null 2>&1

echo "============================================================"
echo "[SUCCESS] Cloud NAS has been completely purged from this Mac!"
echo "============================================================"
