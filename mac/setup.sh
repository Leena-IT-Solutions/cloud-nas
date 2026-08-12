#!/usr/bin/env bash
# macOS 1-Click Zero-Dependency Cloud NAS Installer

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

KEY_FILE="$PROJECT_ROOT/leena-it-solutions-412315-f63f3bd287c1.json"
BUCKET_NAME="sv-school"
REMOTE_NAME="gcsnas"
RCLONE_BIN="$SCRIPT_DIR/rclone"
GUI_SCRIPT="$PROJECT_ROOT/cloud_nas_gui.py"

# Resolve exact Python 3 binary path
PYTHON_BIN="$(which python3)"
if [ -z "$PYTHON_BIN" ]; then
    PYTHON_BIN="/usr/bin/python3"
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

echo "============================================================"
echo "      🚀 macOS 1-Click Cloud NAS Installer 🚀"
echo "============================================================"

# Check Key File
if [ ! -f "$KEY_FILE" ]; then
    echo "[ERROR] GCP Key file leena-it-solutions-412315-f63f3bd287c1.json not found in $PROJECT_ROOT!"
    exit 1
fi
echo "[OK] Found GCP Key: $KEY_FILE"

# Check / Download Rclone
if [ ! -f "$RCLONE_BIN" ]; then
    echo "[INFO] Downloading official Rclone binary for macOS..."
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

# Prepare Mount Point Directory
echo "[INFO] Mounting Cloud NAS ($VOL_NAME) to $MOUNT_POINT..."
pkill -9 -f "rclone mount" >/dev/null 2>&1
diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1 || true
umount -f "$MOUNT_POINT" >/dev/null 2>&1 || true
sleep 1

rm -rf "$MOUNT_POINT" >/dev/null 2>&1 || true
mkdir -p "$MOUNT_POINT"

# Launch rclone mount in background via nohup
nohup "$RCLONE_BIN" mount "$REMOTE_PATH" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --vfs-write-back 1s \
    --dir-cache-time 10s \
    --attr-timeout 1s \
    --allow-non-empty \
    --gcs-bucket-policy-only \
    --volname "$VOL_NAME" \
    --rc \
    --rc-no-auth \
    --rc-addr 127.0.0.1:5572 \
    --no-modtime \
    $READ_ONLY_FLAG >/dev/null 2>&1 &

sleep 1

# Create macOS Application Bundle in ~/Applications/Cloud NAS.app for Launchpad & Spotlight
APP_DIR="$HOME/Applications/Cloud NAS.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

if [ -f "$PROJECT_ROOT/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat << EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Cloud NAS</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.cloudnas.controlcenter</string>
    <key>CFBundleName</key>
    <string>Cloud NAS</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
EOF

cat << EOF > "$APP_DIR/Contents/MacOS/Cloud NAS"
#!/usr/bin/env bash
exec "$PYTHON_BIN" "$GUI_SCRIPT"
EOF

chmod +x "$APP_DIR/Contents/MacOS/Cloud NAS"
echo "[OK] Installed 'Cloud NAS' with Python ($PYTHON_BIN) in macOS Applications & Launchpad!"

# Auto-start GUI on macOS login
PLIST_PATH="$HOME/Library/LaunchAgents/com.cloudnas.controlcenter.plist"
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cloudnas.controlcenter</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON_BIN</string>
        <string>$GUI_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
launchctl load "$PLIST_PATH" >/dev/null 2>&1

echo "============================================================"
echo "[SUCCESS] Cloud NAS mounted ($VOL_NAME) & installed to Applications / Launchpad!"
echo "============================================================"

# Launch Control Center GUI immediately
open "$APP_DIR" >/dev/null 2>&1 || nohup "$PYTHON_BIN" "$GUI_SCRIPT" >/dev/null 2>&1 &
