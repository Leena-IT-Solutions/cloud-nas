#!/usr/bin/env bash

# macOS Cloud NAS Auto-Mount Script with Persistent Local Pointer Index & Smart Chunk Streaming
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

RCLONE_BIN="$SCRIPT_DIR/rclone"

# Fallback to system rclone if local binary not found
if [ ! -f "$RCLONE_BIN" ]; then
    RCLONE_BIN="rclone"
fi

CONFIG_FILE="$PROJECT_ROOT/drive_config.json"
ACTIVE_USER_FILE="$PROJECT_ROOT/active_user_mount.json"

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
        "$RCLONE_BIN" touch "$REMOTE_NAME:$BUCKET_NAME/.sys/chats/.keep" >/dev/null 2>&1
        REMOTE_PATH="$REMOTE_NAME:$BUCKET_NAME/$SUBPATH"
    fi
    if [ "$PERM" = "Read-Only" ]; then
        READ_ONLY_FLAG="--read-only"
    fi
fi

MOUNT_POINT="$HOME/$VOL_NAME"

# Wait for active internet connection before mounting (up to 45 seconds on system reboot)
MAX_WAIT=45
WAIT_COUNT=0
while ! ping -c 1 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 oauth2.googleapis.com >/dev/null 2>&1; do
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        break
    fi
done

# Unmount existing instance if running
pkill -9 -f "rclone mount" >/dev/null 2>&1
diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1 || true
umount -f "$MOUNT_POINT" >/dev/null 2>&1 || true
sleep 1

rm -rf "$MOUNT_POINT" >/dev/null 2>&1 || true
mkdir -p "$MOUNT_POINT"

echo "Mounting Cloud NAS ($VOL_NAME) to '$MOUNT_POINT'..."

nohup "$RCLONE_BIN" mount "$REMOTE_PATH" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 25G \
    --vfs-cache-max-age 72h \
    --vfs-write-back 1s \
    --dir-cache-time 9999h \
    --poll-interval 10s \
    --vfs-read-chunk-size 64M \
    --vfs-read-chunk-size-limit 1G \
    --vfs-fast-fingerprint \
    --attr-timeout 9999h \
    --contimeout 60s \
    --timeout 60s \
    --low-level-retries 10 \
    --retries 10 \
    --allow-non-empty \
    --gcs-bucket-policy-only \
    --volname "$VOL_NAME" \
    -o nobrowse \
    --rc \
    --rc-no-auth \
    --rc-addr 127.0.0.1:5572 \
    --no-modtime \
    $READ_ONLY_FLAG >/dev/null 2>&1 &

disown %1 >/dev/null 2>&1 || true

echo "Cloud NAS mounted successfully at '$MOUNT_POINT'!"
