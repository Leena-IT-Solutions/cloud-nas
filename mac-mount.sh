#!/usr/bin/env bash

# macOS Cloud NAS Auto-Mount Script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RCLONE_BIN="$SCRIPT_DIR/rclone"

# Fallback to system rclone if local binary not found
if [ ! -f "$RCLONE_BIN" ]; then
    RCLONE_BIN="rclone"
fi

BUCKET_NAME="sv-school"            # GCP Bucket Name
REMOTE_NAME="gcsnas"              # Rclone remote name
MOUNT_POINT="$HOME/CloudNAS"      # Local mount directory in macOS Finder

# Create mount directory if it doesn't exist
mkdir -p "$MOUNT_POINT"

# Check if already mounted
if mount | grep -q "$MOUNT_POINT"; then
    echo "Cloud NAS is already mounted at $MOUNT_POINT"
    exit 0
fi

echo "Mounting Google Cloud Storage Bucket '$BUCKET_NAME' to '$MOUNT_POINT'..."

"$RCLONE_BIN" mount "$REMOTE_NAME:$BUCKET_NAME" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --vfs-write-back 1s \
    --allow-non-empty \
    --no-modtime \
    --daemon

echo "Cloud NAS mounted successfully! Check macOS Finder -> Locations -> CloudNAS"
