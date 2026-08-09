#!/usr/bin/env python3
"""
Cloud NAS Automated 1-Click Installer & Configurator
Supports macOS & Windows out of the box.
"""

import os
import sys
import platform
import subprocess
import urllib.request
import zipfile
import shutil
from pathlib import Path

# --- Configurations ---
DEFAULT_BUCKET = "sv-school"
DEFAULT_REMOTE = "gcsnas"
SCRIPT_DIR = Path(__file__).parent.resolve()
KEY_FILENAME = "leena-it-solutions-412315-f63f3bd287c1.json"

IS_MAC = platform.system() == "Darwin"
IS_WIN = platform.system() == "Windows"

def log(msg, status="INFO"):
    prefix = "[\033[94mINFO\033[0m]" if status == "INFO" else "[\033[92mSUCCESS\033[0m]" if status == "OK" else "[\033[91mERROR\033[0m]"
    print(f"{prefix} {msg}")

def run_cmd(cmd, check=True):
    try:
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if check and res.returncode != 0:
            log(f"Command failed: {cmd}\nError: {res.stderr}", "ERR")
            return False, res.stderr
        return True, res.stdout
    except Exception as e:
        log(f"Execution error: {e}", "ERR")
        return False, str(e)

def find_key_file():
    """Locate GCP service account JSON key."""
    candidates = [
        SCRIPT_DIR / KEY_FILENAME,
        Path.home() / KEY_FILENAME,
        Path("C:/CloudNAS") / KEY_FILENAME if IS_WIN else Path.home() / "CloudNAS" / KEY_FILENAME
    ]
    for c in candidates:
        if c.exists():
            return c
    return None

def install_rclone():
    """Download official standalone rclone binary if not present."""
    log("Checking Rclone installation...")
    rclone_bin = SCRIPT_DIR / ("rclone.exe" if IS_WIN else "rclone")
    if rclone_bin.exists():
        log(f"Rclone binary found at: {rclone_bin}", "OK")
        return rclone_bin

    log("Downloading official Rclone standalone binary...")
    if IS_MAC:
        arch = "arm64" if platform.machine() in ["arm64", "aarch64"] else "amd64"
        url = f"https://downloads.rclone.org/v1.70.0/rclone-v1.70.0-osx-{arch}.zip"
    else:
        url = "https://downloads.rclone.org/v1.70.0/rclone-v1.70.0-windows-amd64.zip"

    zip_path = SCRIPT_DIR / "rclone_download.zip"
    try:
        urllib.request.urlretrieve(url, zip_path)
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(SCRIPT_DIR / "rclone_temp")
        
        # Find extracted rclone executable
        for root, dirs, files in os.walk(SCRIPT_DIR / "rclone_temp"):
            for file in files:
                if file in ["rclone", "rclone.exe"]:
                    shutil.move(os.path.join(root, file), rclone_bin)
                    break
        
        # Clean up temp
        os.remove(zip_path)
        shutil.rmtree(SCRIPT_DIR / "rclone_temp", ignore_errors=True)
        
        if IS_MAC:
            os.chmod(rclone_bin, 0o755)
            
        log(f"Rclone installed successfully at {rclone_bin}", "OK")
        return rclone_bin
    except Exception as e:
        log(f"Failed to download rclone: {e}", "ERR")
        return None

def configure_rclone(rclone_bin, key_file, bucket_name):
    """Generate rclone.conf with bucket_policy_only=true."""
    log("Configuring Rclone connection for Google Cloud Storage...")
    cmd = (
        f'"{rclone_bin}" config create {DEFAULT_REMOTE} googlecloudstorage '
        f'service_account_file "{key_file}" bucket_policy_only true'
    )
    ok, out = run_cmd(cmd)
    if ok:
        log("Rclone GCS remote configured successfully!", "OK")
    else:
        log("Failed to configure Rclone remote", "ERR")
    return ok

def mount_drive_mac(rclone_bin, bucket_name):
    """Mount GCS drive on macOS Finder."""
    log("Setting up Cloud NAS on macOS Finder...")
    mount_point = Path.home() / "CloudNAS"
    mount_point.mkdir(parents=True, exist_ok=True)

    # Clean stale mounts
    run_cmd(f'diskutil unmount force "{mount_point}"', check=False)
    run_cmd(f'umount -f "{mount_point}"', check=False)

    mount_cmd = (
        f'"{rclone_bin}" mount {DEFAULT_REMOTE}:{bucket_name} "{mount_point}" '
        f'--vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h '
        f'--vfs-write-back 1s --allow-non-empty --gcs-bucket-policy-only '
        f'--volname "Cloud NAS" --no-modtime --daemon'
    )
    ok, out = run_cmd(mount_cmd)
    if ok:
        log(f"Cloud NAS successfully mounted at {mount_point} in Finder!", "OK")
    else:
        log("Mount command executed with warnings. Check Finder -> Locations -> CloudNAS.", "INFO")

def mount_drive_windows(rclone_bin, bucket_name):
    """Mount GCS drive on Windows File Explorer as Y: Drive."""
    log("Setting up Cloud NAS on Windows File Explorer (Y: Drive)...")
    
    # Create hidden VBS launcher
    vbs_content = f'''Set WshShell = CreateObject("WScript.Shell")
rcloneCmd = """{rclone_bin}"" mount {DEFAULT_REMOTE}:{bucket_name} Y: --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h --vfs-write-back 1s --gcs-bucket-policy-only --no-modtime"
WshShell.Run rcloneCmd, 0, False
'''
    vbs_file = SCRIPT_DIR / "windows-mount-hidden.vbs"
    with open(vbs_file, "w") as f:
        f.write(vbs_content)

    # Execute VBS launcher
    ok, out = run_cmd(f'cscript //nologo "{vbs_file}"', check=False)
    log("Cloud NAS background mount triggered! Check This PC -> Local Disk (Y:)", "OK")

def main():
    print("=" * 60)
    print("      🚀 Cloud NAS Automated 1-Click Setup Tool 🚀")
    print("=" * 60)
    print(f"Operating System: {platform.system()} ({platform.machine()})")
    
    key_file = find_key_file()
    if not key_file:
        log("GCP Service Account JSON key file not found!", "ERR")
        log(f"Please place '{KEY_FILENAME}' inside: {SCRIPT_DIR}", "INFO")
        sys.exit(1)
    
    log(f"Found GCP credentials at: {key_file}", "OK")

    rclone_bin = install_rclone()
    if not rclone_bin:
        sys.exit(1)

    if not configure_rclone(rclone_bin, key_file, DEFAULT_BUCKET):
        sys.exit(1)

    if IS_MAC:
        mount_drive_mac(rclone_bin, DEFAULT_BUCKET)
    elif IS_WIN:
        mount_drive_windows(rclone_bin, DEFAULT_BUCKET)
    else:
        log("Unsupported OS", "ERR")
        sys.exit(1)

    print("\n" + "=" * 60)
    log("Automated setup completed flawlessly!", "OK")
    print("=" * 60)

if __name__ == "__main__":
    main()
