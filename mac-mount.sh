#!/usr/bin/env bash

# macOS Cloud NAS Auto-Mount Script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RCLONE_BIN="$SCRIPT_DIR/rclone"

# Fallback to system rclone if local binary not found
if [ ! -f "$RCLONE_BIN" ]; then
    RCLONE_BIN="rclone"
fi

CONFIG_FILE="$SCRIPT_DIR/drive_config.json"
VOL_NAME="Cloud NAS"

# Read custom drive name from drive_config.json if present
if [ -f "$CONFIG_FILE" ]; then
    PARSED_NAME="$(grep -o '"volname": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
    if [ -n "$PARSED_NAME" ]; then
        VOL_NAME="$PARSED_NAME"
    fi
fi

BUCKET_NAME="sv-school"            # GCP Bucket Name
REMOTE_NAME="gcsnas"              # Rclone remote name
MOUNT_POINT="$HOME/$VOL_NAME"      # Local mount directory in macOS Finder

# Unmount existing instance if running
pkill -9 -f "rclone mount" >/dev/null 2>&1
if [ -d "$MOUNT_POINT" ]; then
    diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1
    umount -f "$MOUNT_POINT" >/dev/null 2>&1
fi

# Create fresh mount directory
mkdir -p "$MOUNT_POINT"

echo "Mounting Google Cloud Storage Bucket '$BUCKET_NAME' to '$MOUNT_POINT' (Volume: '$VOL_NAME')..."

nohup "$RCLONE_BIN" mount "$REMOTE_NAME:$BUCKET_NAME" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --vfs-write-back 1s \
    --vfs-dir-cache-time 10s \
    --attr-timeout 1s \
    --allow-non-empty \
    --gcs-bucket-policy-only \
    --volname "$VOL_NAME" \
    --rc \
    --rc-no-auth \
    --rc-addr 127.0.0.1:5572 \
    --no-modtime >/dev/null 2>&1 &

echo "Cloud NAS mounted successfully at '$MOUNT_POINT'!"
