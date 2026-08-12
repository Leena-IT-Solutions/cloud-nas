#!/usr/bin/env bash
# macOS 1-Click Cloud NAS Purge & Uninstall Script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

CONFIG_FILE="$PROJECT_ROOT/drive_config.json"
USERS_FILE="$PROJECT_ROOT/users_permissions.json"
ACTIVE_USER_FILE="$PROJECT_ROOT/active_user_mount.json"
RCLONE_BIN="$SCRIPT_DIR/rclone"

VOL_NAME="Cloud NAS"
if [ -f "$CONFIG_FILE" ]; then
    PARSED_NAME="$(grep -o '"volname": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
    if [ -n "$PARSED_NAME" ]; then
        VOL_NAME="$PARSED_NAME"
    fi
fi

MOUNT_POINT="$HOME/$VOL_NAME"
APP_DIR="$HOME/Applications/Cloud NAS.app"
AUTOMOUNT_PLIST="$HOME/Library/LaunchAgents/com.cloudnas.automount.plist"
GUI_PLIST="$HOME/Library/LaunchAgents/com.cloudnas.controlcenter.plist"

echo "============================================================"
echo "      🗑️ macOS 1-Click Cloud NAS Purge & Uninstall 🗑️"
echo "============================================================"

# Unmount Drive Point
echo "[INFO] Unmounting Cloud NAS drive ($VOL_NAME)..."
pkill -9 -f "rclone mount" >/dev/null 2>&1
diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1 || true
umount -f "$MOUNT_POINT" >/dev/null 2>&1 || true
sleep 1
rm -rf "$MOUNT_POINT" >/dev/null 2>&1 || true

# Terminate Background GUI & Rclone Processes
echo "[INFO] Terminating rclone background processes and Control Center..."
pkill -9 -f "cloud_nas_gui.py" >/dev/null 2>&1 || true

# Remove LaunchAgent Auto-Start Plists
echo "[INFO] Removing auto-mount LaunchAgents..."
if [ -f "$AUTOMOUNT_PLIST" ]; then
    launchctl unload -w "$AUTOMOUNT_PLIST" >/dev/null 2>&1 || true
    rm -f "$AUTOMOUNT_PLIST" >/dev/null 2>&1 || true
fi
if [ -f "$GUI_PLIST" ]; then
    launchctl unload -w "$GUI_PLIST" >/dev/null 2>&1 || true
    rm -f "$GUI_PLIST" >/dev/null 2>&1 || true
fi

# Remove macOS Application Bundle
if [ -d "$APP_DIR" ]; then
    echo "[INFO] Removing Cloud NAS from macOS Applications & Launchpad..."
    rm -rf "$APP_DIR" >/dev/null 2>&1 || true
fi

# Remove Rclone Remote Config
if [ -f "$RCLONE_BIN" ]; then
    echo "[INFO] Removing GCS remote configuration..."
    "$RCLONE_BIN" config delete gcsnas >/dev/null 2>&1 || true
fi

# Remove Local Configuration Files
rm -rf "$HOME/.config/rclone" >/dev/null 2>&1 || true
rm -f "$ACTIVE_USER_FILE" >/dev/null 2>&1 || true
rm -f "$CONFIG_FILE" >/dev/null 2>&1 || true

echo "============================================================"
echo "[SUCCESS] Cloud NAS has been completely purged from this Mac!"
echo "============================================================"
