#!/usr/bin/env bash
# macOS 1-Click Zero-Dependency Cloud NAS Installer

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

KEY_FILE="$PROJECT_ROOT/leena-it-solutions-412315-f63f3bd287c1.json"
BUCKET_NAME="sv-school"
REMOTE_NAME="gcsnas"
RCLONE_BIN="$SCRIPT_DIR/rclone"
GUI_SCRIPT="$PROJECT_ROOT/cloud_nas_gui.py"
MOUNT_SCRIPT="$SCRIPT_DIR/mac-mount.sh"

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

# Make Mount Script Executable
chmod +x "$MOUNT_SCRIPT"

# 1. Register & Load Auto-mount LaunchAgent daemon directly in system launchd (PID 1)
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENT_DIR"

AUTOMOUNT_PLIST="$LAUNCH_AGENT_DIR/com.cloudnas.automount.plist"
cat << EOF > "$AUTOMOUNT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cloudnas.automount</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$MOUNT_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

echo "[INFO] Loading Cloud NAS persistent launchd daemon..."
launchctl unload "$AUTOMOUNT_PLIST" >/dev/null 2>&1 || true
launchctl load -w "$AUTOMOUNT_PLIST" >/dev/null 2>&1

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

# 2. Auto-start GUI Control Center on macOS login
GUI_PLIST="$LAUNCH_AGENT_DIR/com.cloudnas.controlcenter.plist"
cat << EOF > "$GUI_PLIST"
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
launchctl unload "$GUI_PLIST" >/dev/null 2>&1 || true
launchctl load -w "$GUI_PLIST" >/dev/null 2>&1

echo "============================================================"
echo "[SUCCESS] Cloud NAS mounted ($VOL_NAME) & installed to Applications / Launchpad!"
echo "============================================================"

# Launch Control Center GUI immediately
open "$APP_DIR" >/dev/null 2>&1 || nohup "$PYTHON_BIN" "$GUI_SCRIPT" >/dev/null 2>&1 &
