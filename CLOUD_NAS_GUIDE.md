# Google Cloud Storage (GCS) Cloud NAS Setup & Purge Guide

This project provides **1-click zero-dependency Install & Purge scripts** for **macOS** and **Windows**.

---

## 🚀 1-Click Installation (Setup)

### 🍎 On macOS:
Run `setup.sh`:
```bash
./setup.sh
```
- Automatically configures GCS bucket connection (`sv-school`).
- Mounts **`CloudNAS`** directly in macOS Finder sidebar.
- Zero dependencies required.

### 🪟 On Windows:
Double-click **`setup.bat`**:
```cmd
setup.bat
```
- Automatically configures GCS bucket connection (`sv-school`).
- Mounts **`Y:\` Drive** in Windows File Explorer silently in the background.
- Zero dependencies required.

---

## 🗑️ 1-Click Uninstall (Purge)

If you ever want to completely remove the Cloud NAS drive and clear all configurations:

### 🍎 On macOS:
Run `purge.sh`:
```bash
./purge.sh
```
- Unmounts `CloudNAS` from Finder.
- Stops background mount processes.
- Deletes `gcsnas` Rclone configuration and local mount folders.

### 🪟 On Windows:
Double-click **`purge.bat`**:
```cmd
purge.bat
```
- Unmounts `Y:` Drive from Windows File Explorer.
- Stops background `rclone.exe` processes.
- Removes startup shortcuts and GCS remote configurations.
