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
pkill -9 -f "rclone mount" >/dev/null 2>&1
if [ -d "$MOUNT_POINT" ]; then
    diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1
    umount -f "$MOUNT_POINT" >/dev/null 2>&1
fi
mkdir -p "$MOUNT_POINT"

# Launch rclone in background via nohup
nohup "$RCLONE_BIN" mount "$REMOTE_NAME:$BUCKET_NAME" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --vfs-cache-max-age 24h \
    --vfs-write-back 1s \
    --allow-non-empty \
    --gcs-bucket-policy-only \
    --volname "Cloud NAS" \
    --rc \
    --rc-no-auth \
    --rc-addr 127.0.0.1:5572 \
    --no-modtime >/dev/null 2>&1 &

sleep 1

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
        <string>/usr/bin/python3</string>
        <string>$SCRIPT_DIR/cloud_nas_gui.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
launchctl load "$PLIST_PATH" >/dev/null 2>&1

# Create macOS Application Bundle in ~/Applications/Cloud NAS.app for Launchpad & Spotlight
APP_DIR="$HOME/Applications/Cloud NAS.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
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
exec /usr/bin/python3 "$SCRIPT_DIR/cloud_nas_gui.py"
EOF

chmod +x "$APP_DIR/Contents/MacOS/Cloud NAS"
touch "$APP_DIR"
echo "[OK] Installed 'Cloud NAS' with custom 3D glass icon in macOS Applications & Launchpad!"

# Launch Control Center GUI now
python3 "$SCRIPT_DIR/cloud_nas_gui.py" &

echo "============================================================"
echo "[SUCCESS] Cloud NAS mounted & installed to Applications / Launchpad!"
echo "============================================================"
