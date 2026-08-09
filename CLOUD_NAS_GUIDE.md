# Google Cloud Storage (GCS) Cloud NAS Setup Guide

This guide explains how to set up **Google Cloud Storage** as a native Network Drive on **Windows File Explorer** (as `Z:\` Drive) and **macOS Finder** (as a mounted volume in sidebar).

---

## Phase 1: Google Cloud Platform (GCP) Setup

### Step 1: Create a Google Cloud Storage Bucket
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Select or create a GCP Project.
3. In the navigation menu, go to **Cloud Storage** > **Buckets**.
4. Click **Create Bucket**:
   - **Name**: `cloud-nas-storage` (Must be globally unique, e.g., `sandeep-cloud-nas`).
   - **Location type**: Choose **Region** (select the region closest to you, e.g. `asia-south1` for Mumbai).
   - **Storage Class**: Select **Standard**.
   - **Access control**: Select **Uniform**.
5. Click **Create**.

### Step 2: Create Service Account & JSON Key File
1. Go to **IAM & Admin** > **Service Accounts**.
2. Click **Create Service Account**:
   - **Name**: `cloud-nas-admin`
   - Click **Create and Continue**.
3. **Grant this service account access to project**:
   - Select Role: **Cloud Storage** > **Storage Object Admin**.
   - Click **Continue** and then **Done**.
4. Click on the newly created service account (`cloud-nas-admin@...`).
5. Go to the **Keys** tab > **Add Key** > **Create new key**.
6. Select **JSON** and click **Create**.
7. Save the downloaded file to your computer and rename it to `gcp-key.json`.
   - On Mac: `/Users/sandeep/gcp-key.json`
   - On Windows: `C:\CloudNAS\gcp-key.json`

---

## Phase 2: Setup on macOS (Finder Integration)

### Method 1: GUI Application (Easiest - RaiDrive or Mountain Duck)
If you prefer a 1-click GUI tool:
1. Download **Mountain Duck** or **Cyberduck**.
2. Add a new bookmark > Select **Google Cloud Storage**.
3. Upload `gcp-key.json` and select your bucket name `sandeep-cloud-nas`.
4. Click **Connect**. It will instantly appear under **Locations** in Finder!

### Method 2: Rclone + macFUSE (Free & Powerful)

#### Step 1: Install Tools via Homebrew
Open Terminal on your Mac and run:
```bash
brew install macfuse rclone
```
*(If macFUSE prompts for System Extension permissions in macOS Settings > Privacy & Security, grant permission and restart Mac).*

#### Step 2: Configure Rclone
Run the following command in Terminal:
```bash
rclone config
```
1. Type `n` for **New remote**.
2. Name: `gcsnas`
3. Storage Type: Type `google cloud storage` (or type the number for it, usually `18`).
4. `service_account_file`: Enter full path to your key, e.g., `/Users/sandeep/gcp-key.json`.
5. Press Enter to accept defaults for remaining prompts until saved.

#### Step 3: Test Mounting
Create a mount directory:
```bash
mkdir -p ~/CloudNAS
```
Run the mount command:
```bash
rclone mount gcsnas:sandeep-cloud-nas ~/CloudNAS --vfs-cache-mode full &
```
👉 Open **Finder** — you will now see **`CloudNAS`** in your home folder and under **Locations** in the sidebar!

---

## Phase 3: Setup on Windows (File Explorer `Z:\` Drive Integration)

### Method 1: RaiDrive (Easiest GUI Tool)
1. Download & Install [RaiDrive](https://www.raidrive.com/).
2. Click **+ Add** button at the top right.
3. Select **Storage** > **Google Cloud Storage**.
4. Select Drive Letter: **`Z:`**.
5. Upload your `gcp-key.json` file and select your bucket.
6. Click **OK**.
👉 Open **Windows File Explorer** — **`Z:\`** drive will appear under **This PC**!

### Method 2: Rclone + WinFSP (Free & Powerful)

#### Step 1: Install Dependencies
1. Download and install **WinFSP**: [https://winfsp.dev/](https://winfsp.dev/)
2. Download **Rclone for Windows**: [https://rclone.org/downloads/](https://rclone.org/downloads/)
3. Extract `rclone.exe` to `C:\rclone\rclone.exe`.

#### Step 2: Configure Rclone on Windows
Open Command Prompt (`cmd`) or PowerShell:
```cmd
C:\rclone\rclone.exe config
```
1. Type `n` for **New remote**.
2. Name: `gcsnas`
3. Storage Type: Choose `google cloud storage`.
4. `service_account_file`: `C:\CloudNAS\gcp-key.json`
5. Save and exit.

#### Step 3: Mount as `Z:` Drive
Run:
```cmd
C:\rclone\rclone.exe mount gcsnas:sandeep-cloud-nas Z: --vfs-cache-mode full
```
👉 Open **This PC** in Windows File Explorer — **`Z:\` Drive** is live!

---

## Phase 4: Auto-Mounting on Boot

### On macOS (LaunchAgent)
Copy `com.cloudnas.automount.plist` to `~/Library/LaunchAgents/` and load it:
```bash
cp com.cloudnas.automount.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.cloudnas.automount.plist
```

### On Windows (Task Scheduler)
1. Open **Task Scheduler** in Windows.
2. Create Task > Name: `Mount Cloud NAS`.
3. Trigger: **At log on**.
4. Action: **Start a program** -> `C:\rclone\windows-mount.bat`.
5. Check **Run with highest privileges**.
