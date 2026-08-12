# 📱 Cloud NAS Android Setup Guide

Connect your Android phone or tablet directly to **Cloud NAS** (Google Cloud Storage) with native file browsing, background syncing, and media streaming.

---

## 🚀 Method 1: 1-Click Setup via Termux (Recommended for Power Users)

If you have [Termux](https://f-droid.org/en/packages/com.termux/) installed on your Android device:

1. Open **Termux** and run:
   ```bash
   pkg update && pkg install rclone curl python -y
   ```
2. Copy `leena-it-solutions-412315-f63f3bd287c1.json` to your device storage.
3. Run the Cloud NAS Android installer script:
   ```bash
   curl -sSL https://raw.githubusercontent.com/your-repo/CloudNAS/main/android/setup.sh | bash
   ```

---

## 📂 Method 2: Native Android File Manager via WebDAV (Solid Explorer / CX File Explorer)

You can mount Cloud NAS as a native network drive in popular Android File Managers (**Solid Explorer**, **CX File Explorer**, **MiXplorer**, **Total Commander**):

1. **Host WebDAV Server from Control Center** (or run Rclone WebDAV):
   ```bash
   rclone serve webdav gcsnas:sv-school --addr :8080 --user admin --pass password
   ```
2. Open **Solid Explorer** or **CX File Explorer** on Android.
3. Tap **+ (Add Storage)** $\rightarrow$ Select **WebDAV**.
4. Enter Server Details:
   - **Host/IP**: `http://<your-computer-ip>` (e.g. `http://192.168.1.50`)
   - **Port**: `8080`
   - **User**: `admin` (or `philip` / `sandeep` / `leena`)
   - **Password**: `password`
5. Tap **Connect**! Your Cloud NAS files will now appear natively inside your Android File Manager!

---

## 📱 Method 3: RCX App (Rclone for Android)

[RCX - Rclone for Android](https://github.com/x0b/RCX) is an open-source Android app that mounts Rclone remotes directly on Android.

1. Download **RCX** from F-Droid or Play Store.
2. Tap **+ (Add Remote)** $\rightarrow$ Select **Google Cloud Storage**.
3. Select Service Account JSON: Choose `leena-it-solutions-412315-f63f3bd287c1.json`.
4. Bucket Name: `sv-school`.
5. Tap **Save & Mount**.
