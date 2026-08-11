#!/usr/bin/env bash
# macOS 1-Click Cloud NAS Purge & Uninstall Script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MOUNT_POINT="$HOME/CloudNAS"
PLIST_PATH="$HOME/Library/LaunchAgents/com.cloudnas.controlcenter.plist"
APP_DIR="$HOME/Applications/Cloud NAS.app"
RCLONE_BIN="$SCRIPT_DIR/rclone"

if [ ! -f "$RCLONE_BIN" ]; then
    RCLONE_BIN="rclone"
fi

echo "============================================================"
echo "      🗑️ macOS 1-Click Cloud NAS Purge & Uninstall 🗑️"
echo "============================================================"

# 1. Unmount Drive
echo "[INFO] Unmounting Cloud NAS drive from $MOUNT_POINT..."
diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1
umount -f "$MOUNT_POINT" >/dev/null 2>&1

# 2. Stop Rclone Processes
echo "[INFO] Terminating rclone background processes..."
pkill -9 -f "rclone mount" >/dev/null 2>&1

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

# 6. Remove Mount Directory
if [ -d "$MOUNT_POINT" ]; then
    echo "[INFO] Removing mount directory $MOUNT_POINT..."
    rm -rf "$MOUNT_POINT"
fi

echo "============================================================"
echo "[SUCCESS] Cloud NAS has been completely purged from this Mac!"
echo "============================================================"
