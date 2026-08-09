#!/usr/bin/env bash

# macOS Cloud NAS Auto-Mount Script
# Ensure rclone and macfuse are installed via `brew install macfuse rclone`

BUCKET_NAME="sandeep-cloud-nas"   # Replace with your GCP Bucket Name
REMOTE_NAME="gcsnas"              # Rclone remote name configured in `rclone config`
MOUNT_POINT="$HOME/CloudNAS"      # Local mount directory in macOS Finder

# Create mount directory if it doesn't exist
mkdir -p "$MOUNT_POINT"

# Check if already mounted
if mount | grep -q "$MOUNT_POINT"; then
    echo "Cloud NAS is already mounted at $MOUNT_POINT"
    exit 0
fi

echo "Mounting Google Cloud Storage Bucket '$BUCKET_NAME' to '$MOUNT_POINT'..."

rclone mount "$REMOTE_NAME:$BUCKET_NAME" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --no-modtime \
    --daemon

echo "Cloud NAS mounted successfully! Check macOS Finder -> Locations -> CloudNAS"
