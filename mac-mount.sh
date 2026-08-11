#!/usr/bin/env bash

# macOS 100% Zero-Dependency Driverless Cloud NAS Auto-Mount Script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RCLONE_BIN="$SCRIPT_DIR/rclone"

if [ ! -f "$RCLONE_BIN" ]; then
    RCLONE_BIN="rclone"
fi

CONFIG_FILE="$SCRIPT_DIR/drive_config.json"
ACTIVE_USER_FILE="$SCRIPT_DIR/active_user_mount.json"

VOL_NAME="Cloud NAS"
if [ -f "$CONFIG_FILE" ]; then
    PARSED_NAME="$(grep -o '"volname": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
    if [ -n "$PARSED_NAME" ]; then
        VOL_NAME="$PARSED_NAME"
    fi
fi

BUCKET_NAME="sv-school"
REMOTE_NAME="gcsnas"
REMOTE_PATH="$REMOTE_NAME:$BUCKET_NAME"
READ_ONLY_FLAG=""

# Check Active User Folder Scope & Permission Level
if [ -f "$ACTIVE_USER_FILE" ]; then
    SUBPATH="$(grep -o '"folder_path": "[^"]*"' "$ACTIVE_USER_FILE" | cut -d'"' -f4 | sed 's/^\///')"
    PERM="$(grep -o '"permission": "[^"]*"' "$ACTIVE_USER_FILE" | cut -d'"' -f4)"

    if [ -n "$SUBPATH" ] && [ "$SUBPATH" != "/" ]; then
        "$RCLONE_BIN" touch "$REMOTE_NAME:$BUCKET_NAME/$SUBPATH/.keep" >/dev/null 2>&1
        REMOTE_PATH="$REMOTE_NAME:$BUCKET_NAME/$SUBPATH"
    fi
    if [ "$PERM" = "Read-Only" ]; then
        READ_ONLY_FLAG="--read-only"
    fi
fi

MOUNT_POINT="$HOME/$VOL_NAME"

# Unmount existing instance if running
pkill -9 -f "rclone serve webdav" >/dev/null 2>&1
pkill -9 -f "rclone mount" >/dev/null 2>&1
if [ -d "$MOUNT_POINT" ]; then
    umount -f "$MOUNT_POINT" >/dev/null 2>&1
    diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1
fi

mkdir -p "$MOUNT_POINT"

echo "Starting WebDAV Cloud Engine for '$REMOTE_PATH'..."

# Launch Rclone Native WebDAV Engine on port 8080
nohup "$RCLONE_BIN" serve webdav "$REMOTE_PATH" \
    --addr 127.0.0.1:8080 \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --vfs-write-back 1s \
    --dir-cache-time 10s \
    --attr-timeout 1s \
    --gcs-bucket-policy-only \
    --rc \
    --rc-no-auth \
    --rc-addr 127.0.0.1:5572 \
    --no-modtime \
    $READ_ONLY_FLAG >/dev/null 2>&1 &

sleep 2

# Mount natively in macOS Finder using built-in WebDAV client (ZERO macFUSE required!)
mount_webdav http://127.0.0.1:8080 "$MOUNT_POINT" >/dev/null 2>&1

echo "Cloud NAS mounted driverlessly at '$MOUNT_POINT'!"
