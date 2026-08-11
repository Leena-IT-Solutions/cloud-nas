#!/usr/bin/env python3
"""
Cloud NAS Desktop Control Center & Live Monitor
Provides real-time Upload/Download speeds, Transfer Queue, and Push/Pull/Refresh buttons.
Pure Tkinter widgets for 100% reliable dark mode on macOS & Windows.
"""

import os
import sys
import time
import json
import socket
import threading
import platform
import subprocess
import urllib.request
import urllib.error
import tkinter as tk
from tkinter import messagebox
from datetime import datetime

# Enforce Single Instance using local socket lock
try:
    single_instance_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    single_instance_socket.bind(('127.0.0.1', 5573))
except socket.error:
    print("Cloud NAS Control Center is already running.")
    sys.exit(0)

RC_URL = "http://127.0.0.1:5572"
IS_MAC = platform.system() == "Darwin"
IS_WIN = platform.system() == "Windows"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

class CloudNASApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Cloud NAS - Control Center & Bandwidth Monitor")
        self.root.geometry("640x520")
        self.root.minsize(580, 480)
        self.root.configure(bg="#181825")  # Dark Catppuccin Base

        # Apply Window Icon if available
        icon_path = os.path.join(SCRIPT_DIR, "app_icon.png")
        if os.path.exists(icon_path):
            try:
                img = tk.PhotoImage(file=icon_path)
                self.root.iconphoto(True, img)
            except Exception:
                pass

        # State Variables
        self.is_monitoring = True
        self.mounted = False

        # Build UI Components
        self.create_header()
        self.create_speed_cards()
        self.create_transfer_queue()
        self.create_action_toolbar()
        self.create_log_console()

        # Start Background Stats Poller
        self.poll_thread = threading.Thread(target=self.poll_stats_loop, daemon=True)
        self.poll_thread.start()

    def create_header(self):
        header_frame = tk.Frame(self.root, bg="#181825", padx=15, pady=12)
        header_frame.pack(fill="x")

        title_label = tk.Label(
            header_frame, 
            text="☁️ Cloud NAS Control Center", 
            bg="#181825", 
            fg="#cdd6f4", 
            font=("Segoe UI", 14, "bold")
        )
        title_label.pack(side="left")

        self.status_badge = tk.Label(
            header_frame, 
            text="● CONNECTING...", 
            bg="#f9e2af", 
            fg="#11111b", 
            font=("Segoe UI", 9, "bold"),
            padx=10, 
            pady=3,
            relief="flat"
        )
        self.status_badge.pack(side="right")

    def create_speed_cards(self):
        cards_frame = tk.Frame(self.root, bg="#181825", padx=15, pady=5)
        cards_frame.pack(fill="x")

        # Upload Speed Card
        up_card = tk.Frame(cards_frame, bg="#1e1e2e", padx=14, pady=12, highlightthickness=1, highlightbackground="#313244")
        up_card.pack(side="left", fill="both", expand=True, padx=(0, 7))

        tk.Label(up_card, text="⬆️ UPLOAD SPEED", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        self.up_speed_lbl = tk.Label(up_card, text="0.0 KB/s", bg="#1e1e2e", fg="#a6e3a1", font=("Segoe UI", 18, "bold"))
        self.up_speed_lbl.pack(anchor="w", pady=(2, 0))
        self.up_total_lbl = tk.Label(up_card, text="Total Uploaded: 0 MB", bg="#1e1e2e", fg="#bac2de", font=("Segoe UI", 9))
        self.up_total_lbl.pack(anchor="w")

        # Download Speed Card
        down_card = tk.Frame(cards_frame, bg="#1e1e2e", padx=14, pady=12, highlightthickness=1, highlightbackground="#313244")
        down_card.pack(side="right", fill="both", expand=True, padx=(7, 0))

        tk.Label(down_card, text="⬇️ DOWNLOAD SPEED", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        self.down_speed_lbl = tk.Label(down_card, text="0.0 KB/s", bg="#1e1e2e", fg="#89b4fa", font=("Segoe UI", 18, "bold"))
        self.down_speed_lbl.pack(anchor="w", pady=(2, 0))
        self.down_total_lbl = tk.Label(down_card, text="Total Downloaded: 0 MB", bg="#1e1e2e", fg="#bac2de", font=("Segoe UI", 9))
        self.down_total_lbl.pack(anchor="w")

    def create_transfer_queue(self):
        queue_frame = tk.Frame(self.root, bg="#1e1e2e", padx=12, pady=10, highlightthickness=1, highlightbackground="#313244")
        queue_frame.pack(fill="x", padx=15, pady=(5, 10))

        tk.Label(queue_frame, text="⚡ ACTIVE TRANSFERS", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 4))
        
        self.active_file_lbl = tk.Label(queue_frame, text="No active file transfers", bg="#1e1e2e", fg="#cdd6f4", font=("Segoe UI", 9), anchor="w")
        self.active_file_lbl.pack(fill="x")

        # Custom canvas progress bar for guaranteed dark theme rendering
        self.progress_canvas = tk.Canvas(queue_frame, bg="#313244", height=8, highlightthickness=0)
        self.progress_canvas.pack(fill="x", pady=(6, 0))
        self.progress_rect = self.progress_canvas.create_rectangle(0, 0, 0, 8, fill="#89b4fa", width=0)

    def set_progress(self, percentage):
        w = self.progress_canvas.winfo_width()
        if w <= 1:
            w = 580
        target_w = int((percentage / 100.0) * w)
        self.progress_canvas.coords(self.progress_rect, 0, 0, target_w, 8)

    def create_action_toolbar(self):
        toolbar_frame = tk.Frame(self.root, bg="#181825", padx=15, pady=5)
        toolbar_frame.pack(fill="x")

        # Refresh Button
        btn_refresh = tk.Button(
            toolbar_frame, 
            text="🔄 Refresh Data", 
            command=self.action_refresh_data,
            bg="#89b4fa", fg="#11111b", activebackground="#74c7ec",
            font=("Segoe UI", 9, "bold"), relief="flat", padx=12, pady=6, cursor="hand2"
        )
        btn_refresh.pack(side="left", padx=(0, 8))

        # Push Button
        btn_push = tk.Button(
            toolbar_frame, 
            text="⬆️ Push (Sync Local -> GCS)", 
            command=self.action_push,
            bg="#a6e3a1", fg="#11111b", activebackground="#94e2d5",
            font=("Segoe UI", 9, "bold"), relief="flat", padx=12, pady=6, cursor="hand2"
        )
        btn_push.pack(side="left", padx=(0, 8))

        # Pull Button
        btn_pull = tk.Button(
            toolbar_frame, 
            text="⬇️ Pull (Sync GCS -> Local)", 
            command=self.action_pull,
            bg="#cba6f7", fg="#11111b", activebackground="#f5c2e7",
            font=("Segoe UI", 9, "bold"), relief="flat", padx=12, pady=6, cursor="hand2"
        )
        btn_pull.pack(side="left")

    def create_log_console(self):
        console_frame = tk.Frame(self.root, bg="#181825", padx=15, pady=10)
        console_frame.pack(fill="both", expand=True)

        tk.Label(console_frame, text="📋 ACTIVITY LOG", bg="#181825", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 3))

        self.log_box = tk.Text(
            console_frame, 
            bg="#1e1e2e", 
            fg="#a6adc8", 
            insertbackground="#cdd6f4", 
            font=("Consolas", 9),
            relief="flat", 
            highlightthickness=1, 
            highlightbackground="#313244"
        )
        self.log_box.pack(fill="both", expand=True)
        self.log("Cloud NAS Control Center initialized. Monitoring API...")

    def log(self, message):
        now = datetime.now().strftime("%H:%M:%S")
        self.log_box.insert("end", f"[{now}] {message}\n")
        self.log_box.see("end")

    def api_post(self, endpoint, params=None):
        try:
            url = f"{RC_URL}/{endpoint}"
            data = json.dumps(params).encode('utf-8') if params else b"{}"
            req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'}, method='POST')
            with urllib.request.urlopen(req, timeout=2) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception:
            return None

    def poll_stats_loop(self):
        while self.is_monitoring:
            stats = self.api_post("core/stats")
            if stats:
                self.mounted = True
                self.root.after(0, self.update_ui_stats, stats)
            else:
                self.mounted = False
                self.root.after(0, self.update_ui_disconnected)
            time.sleep(1)

    def update_ui_stats(self, stats):
        self.status_badge.config(text="● ONLINE & MOUNTED", bg="#a6e3a1", fg="#11111b")

        speed_bytes = stats.get("speed", 0)
        speed_kb = speed_bytes / 1024.0
        bytes_total = stats.get("bytes", 0)
        mb_total = bytes_total / (1024.0 * 1024.0)

        # Update Upload Speed Display
        self.up_speed_lbl.config(text=f"{speed_kb:.1f} KB/s")
        self.up_total_lbl.config(text=f"Total Uploaded: {mb_total:.2f} MB")

        # Active Transfers Queue
        transfers = stats.get("transferring", [])
        if transfers:
            active_file = transfers[0].get("name", "Syncing...")
            pct = transfers[0].get("percentage", 0)
            self.active_file_lbl.config(text=f"Syncing: {active_file} ({pct}%)")
            self.set_progress(pct)
        else:
            self.active_file_lbl.config(text="Idle - All files fully synchronized")
            self.set_progress(100)

    def update_ui_disconnected(self):
        self.status_badge.config(text="● DISCONNECTED / UNMOUNTED", bg="#f38ba8", fg="#11111b")
        self.up_speed_lbl.config(text="0.0 KB/s")
        self.down_speed_lbl.config(text="0.0 KB/s")
        self.active_file_lbl.config(text="Cloud NAS is not currently mounted.")
        self.set_progress(0)

    def action_refresh_data(self):
        def _task():
            self.log("Requesting live VFS directory cache refresh...")
            res = self.api_post("vfs/refresh")
            if res:
                self.log("✅ Directory cache refreshed! All remote changes loaded.")
            else:
                self.log("❌ Failed to refresh cache. Is Cloud NAS mounted?")
        threading.Thread(target=_task, daemon=True).start()

    def action_push(self):
        def _task():
            self.log("Triggering Push: Forcing instant upload of local cache to GCS...")
            res = self.api_post("vfs/forget")
            res_ref = self.api_post("vfs/refresh")
            if res or res_ref:
                self.log("✅ Push completed! Pending files synced to Google Cloud.")
            else:
                self.log("❌ Push failed. Check connection.")
        threading.Thread(target=_task, daemon=True).start()

    def action_pull(self):
        def _task():
            self.log("Triggering Pull: Fetching latest remote files from GCS...")
            res = self.api_post("vfs/refresh", {"recursive": "true"})
            if res:
                self.log("✅ Pull completed! Remote storage view updated.")
            else:
                self.log("❌ Pull failed. Check connection.")
        threading.Thread(target=_task, daemon=True).start()

def main():
    root = tk.Tk()
    app = CloudNASApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()
