#!/usr/bin/env bash
# macOS 1-Click Zero-Dependency Cloud NAS Installer

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
KEY_FILE="$SCRIPT_DIR/leena-it-solutions-412315-f63f3bd287c1.json"
BUCKET_NAME="sv-school"
REMOTE_NAME="gcsnas"
MOUNT_POINT="$HOME/CloudNAS"
RCLONE_BIN="$SCRIPT_DIR/rclone"

echo "============================================================"
echo "      🚀 macOS 1-Click Cloud NAS Installer 🚀"
echo "============================================================"

# Check Key File
if [ ! -f "$KEY_FILE" ]; then
    echo "[ERROR] GCP Key file leena-it-solutions-412315-f63f3bd287c1.json not found in $SCRIPT_DIR!"
    exit 1
fi
echo "[OK] Found GCP Key: $KEY_FILE"

# Check / Download Rclone
if [ ! -f "$RCLONE_BIN" ]; then
    echo "[INFO] Downloading official Rclone binary..."
    ARCH="amd64"
    if [ "$(uname -m)" = "arm64" ]; then ARCH="arm64"; fi
    curl -sL "https://downloads.rclone.org/v1.70.0/rclone-v1.70.0-osx-${ARCH}.zip" -o /tmp/rclone.zip
    unzip -o /tmp/rclone.zip -d /tmp/rclone_out >/dev/null 2>&1
    cp /tmp/rclone_out/rclone-v1.70.0-osx-${ARCH}/rclone "$RCLONE_BIN"
    chmod +x "$RCLONE_BIN"
    rm -rf /tmp/rclone.zip /tmp/rclone_out
fi
echo "[OK] Rclone Binary Ready: $RCLONE_BIN"

# Configure Rclone
echo "[INFO] Configuring Rclone..."
"$RCLONE_BIN" config create "$REMOTE_NAME" googlecloudstorage service_account_file "$KEY_FILE" bucket_policy_only true >/dev/null 2>&1

# Mount Drive
echo "[INFO] Mounting Cloud NAS to $MOUNT_POINT..."
if [ -d "$MOUNT_POINT" ]; then
    diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1
    umount -f "$MOUNT_POINT" >/dev/null 2>&1
fi
mkdir -p "$MOUNT_POINT"

"$RCLONE_BIN" mount "$REMOTE_NAME:$BUCKET_NAME" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --vfs-write-back 1s \
    --allow-non-empty \
    --gcs-bucket-policy-only \
    --volname "Cloud NAS" \
    --no-modtime \
    --daemon

echo "============================================================"
echo "[SUCCESS] Cloud NAS mounted in macOS Finder -> Locations -> CloudNAS!"
echo "============================================================"
