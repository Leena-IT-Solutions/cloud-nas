#!/usr/bin/env bash
# ============================================================
#       🚀 Android 1-Click Cloud NAS Installer (Termux) 🚀
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEY_FILE="$PARENT_DIR/leena-it-solutions-412315-f63f3bd287c1.json"

if [ ! -f "$KEY_FILE" ]; then
  KEY_FILE="$SCRIPT_DIR/leena-it-solutions-412315-f63f3bd287c1.json"
fi

echo "============================================================"
echo "      🚀 Android 1-Click Cloud NAS Installer 🚀"
echo "============================================================"

# Ensure rclone is installed
if ! command -v rclone &> /dev/null; then
    echo "[INFO] Installing Rclone in Termux..."
    pkg update -y && pkg install rclone -y
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "[ERROR] GCP Service Account Key file not found!"
    echo "Please place 'leena-it-solutions-412315-f63f3bd287c1.json' in the repo directory."
    exit 1
fi

echo "[OK] Found GCP Key: $KEY_FILE"
echo "[INFO] Configuring Rclone remote 'gcsnas'..."

rclone config create gcsnas google cloud storage \
  service_account_file "$KEY_FILE" \
  project_number "412315" \
  bucket_policy_only true \
  object_acl "private" \
  bucket_acl "private" --non-interactive > /dev/null 2>&1

echo "[SUCCESS] Rclone configured for Android!"
echo "To serve files over WebDAV for Solid Explorer / CX File Explorer, run:"
echo "  rclone serve webdav gcsnas:sv-school --addr :8080"
echo "============================================================"
