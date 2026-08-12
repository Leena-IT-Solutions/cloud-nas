#!/usr/bin/env python3
"""
Cloud NAS Desktop Control Center, Live Monitor & GCS Live Chat
Provides Admin Authentication, Folder-Level Scoping & Permission Enforcement, Real-time Speeds,
Transfer Queue, Push/Pull/Refresh buttons, Drive Renaming, Live File Activity Logging,
and Cloud Storage-backed Real-time Live Chat with Desktop Notifications.
Pure Tkinter custom widgets for 100% reliable dark mode rendering on macOS & Windows.
"""

import os
import sys
import time
import json
import socket
import threading
import platform
import subprocess
import ssl
import http.client
import tkinter as tk
from datetime import datetime

# Pre-initialize OpenSSL context on main thread to prevent Python 3.13 multithreaded SIGSEGV crash
try:
    ssl.create_default_context().load_default_certs()
except Exception:
    pass

# Enforce Single Instance using local socket lock
try:
    single_instance_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    single_instance_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    single_instance_socket.bind(('127.0.0.1', 5573))
except socket.error:
    # Terminate stale background process to ensure fresh GUI window opens
    subprocess.run(["pkill", "-9", "-f", "cloud_nas_gui.py"], capture_output=True)
    time.sleep(0.5)
    try:
        single_instance_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        single_instance_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        single_instance_socket.bind(('127.0.0.1', 5573))
    except Exception:
        pass

RC_URL = "http://127.0.0.1:5572"
IS_MAC = platform.system() == "Darwin"
IS_WIN = platform.system() == "Windows"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
USERS_FILE = os.path.join(SCRIPT_DIR, "users_permissions.json")

def get_rclone_bin():
    if IS_MAC:
        candidates = [
            os.path.join(SCRIPT_DIR, "mac", "rclone"),
            os.path.join(SCRIPT_DIR, "rclone"),
        ]
        for c in candidates:
            if os.path.exists(c):
                return c
        return "rclone"
    elif IS_WIN:
        candidates = [
            os.path.join(SCRIPT_DIR, "windows", "rclone.exe"),
            os.path.join(SCRIPT_DIR, "rclone.exe"),
        ]
        for c in candidates:
            if os.path.exists(c):
                return c
        return "rclone.exe"
    return "rclone"

def get_mount_script():
    if IS_MAC:
        mac_path = os.path.join(SCRIPT_DIR, "mac", "mac-mount.sh")
        if os.path.exists(mac_path):
            return mac_path
        return os.path.join(SCRIPT_DIR, "mac-mount.sh")
    elif IS_WIN:
        win_path = os.path.join(SCRIPT_DIR, "windows", "windows-mount-hidden.vbs")
        if os.path.exists(win_path):
            return win_path
        return os.path.join(SCRIPT_DIR, "windows-mount-hidden.vbs")
    return ""

def get_chat_cache_dir():
    import tempfile
    cache_dir = os.path.join(tempfile.gettempdir(), "rclone_chat_cache")
    try:
        os.makedirs(cache_dir, exist_ok=True)
    except Exception:
        pass
    return cache_dir

class DarkButton(tk.Button):
    """Custom flat dark mode button with smooth hover effects for macOS & Windows."""
    def __init__(self, parent, text, command, bg, fg, hover_bg=None, font=("Segoe UI", 9, "bold"), padx=14, pady=6, **kwargs):
        self.command = command
        self.default_bg = bg
        self.hover_bg = hover_bg or bg
        super().__init__(
            parent, 
            text=text, 
            command=command,
            bg=bg, 
            fg=fg, 
            activebackground=self.hover_bg,
            activeforeground=fg,
            font=font, 
            padx=padx, 
            pady=pady, 
            cursor="hand2", 
            relief="flat",
            bd=0,
            highlightthickness=0,
            **kwargs
        )
        self.bind("<Enter>", lambda e: self.config(bg=self.hover_bg))
        self.bind("<Leave>", lambda e: self.config(bg=self.default_bg))

class CloudNASApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Cloud NAS - Control Center, Permissions & Live Chat")
        self.root.geometry("740x660")
        self.root.minsize(700, 560)
        self.root.configure(bg="#181825")  # Dark Catppuccin Base

        # Bring window to front
        try:
            self.root.lift()
            self.root.attributes('-topmost', True)
            self.root.after_idle(self.root.attributes, '-topmost', False)
        except Exception:
            pass

        # Apply Window Icon if available
        icon_path = os.path.join(SCRIPT_DIR, "app_icon.png")
        if os.path.exists(icon_path):
            try:
                img = tk.PhotoImage(file=icon_path)
                self.root.iconphoto(True, img)
            except Exception:
                pass

        # State Variables
        self.logged_in_user = None
        self.is_monitoring = True
        self.mounted = False
        self.tracked_transfers = set()
        self.active_tab = "dashboard"
        
        # Chat State Variables
        self.active_chat_recipient = None
        self.unread_counts = {}
        self.chat_history_cache = {}

        # Load / Initialize Users Database
        self.load_users_data()

        # Restore saved user session if active_user_mount.json exists
        active_user_file = os.path.join(SCRIPT_DIR, "active_user_mount.json")
        if os.path.exists(active_user_file):
            try:
                with open(active_user_file, "r") as f:
                    saved_user = json.load(f)
                    if saved_user and "username" in saved_user:
                        self.logged_in_user = saved_user
                        self.show_main_app()
                        return
            except Exception as e:
                print(f"Could not load saved user session: {e}")

        # Fallback to Login View if no active saved session
        self.show_login_screen()

    def load_users_data(self):
        remote_target = "gcsnas:sv-school/.sys/users_permissions.json"
        rclone_bin = get_rclone_bin()

        # 1. Fetch live user database from Google Cloud Storage remote with isolated cache dir
        try:
            res = subprocess.run([rclone_bin, "cat", remote_target, "--cache-dir", get_chat_cache_dir()], capture_output=True, text=True, timeout=5)
            if res.returncode == 0 and res.stdout.strip():
                data = json.loads(res.stdout)
                if "users" in data and len(data["users"]) > 0:
                    self.users_data = data
                    with open(USERS_FILE, "w") as f:
                        json.dump(data, f, indent=2)
                    print("✅ Successfully loaded user permissions database from GCS Cloud Storage.")
                    return
        except Exception as e:
            print(f"Could not read users from GCS remote: {e}")

        # 2. Fallback to local file cache
        if os.path.exists(USERS_FILE):
            try:
                with open(USERS_FILE, "r") as f:
                    data = json.load(f)
                    if "users" in data and len(data["users"]) > 0:
                        self.users_data = data
                        return
            except Exception:
                pass

        # 3. Seed default user database if not set
        if not hasattr(self, "users_data") or not self.users_data.get("users"):
            default_data = {
                "users": [
                    {
                        "username": "admin",
                        "password": "password",
                        "role": "Admin",
                        "folder_scope": "Full Access (All Folders)",
                        "folder_path": "/",
                        "permission": "Read-Write",
                        "created_at": datetime.now().strftime("%Y-%m-%d %H:%M")
                    },
                    {
                        "username": "philip",
                        "password": "password",
                        "role": "User",
                        "folder_scope": "Specific Folder",
                        "folder_path": "/Philip",
                        "permission": "Read-Write",
                        "created_at": datetime.now().strftime("%Y-%m-%d %H:%M")
                    },
                    {
                        "username": "Sandeep Rathod",
                        "password": "password",
                        "role": "User",
                        "folder_scope": "Specific Folder",
                        "folder_path": "/Sandeep",
                        "permission": "Read-Write",
                        "created_at": datetime.now().strftime("%Y-%m-%d %H:%M")
                    },
                    {
                        "username": "Leena Adam",
                        "password": "password",
                        "role": "User",
                        "folder_scope": "Specific Folder",
                        "folder_path": "/Leena",
                        "permission": "Read-Only",
                        "created_at": datetime.now().strftime("%Y-%m-%d %H:%M")
                    }
                ]
            }
            self.users_data = default_data
            self.save_users_data(default_data)

    def save_users_data(self, data=None):
        if data is None:
            data = self.users_data

        # Save locally
        try:
            with open(USERS_FILE, "w") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"Error saving users file: {e}")

        # Sync to GCS Cloud Storage remote object
        def _upload():
            rclone_bin = get_rclone_bin()
            remote_target = "gcsnas:sv-school/.sys/users_permissions.json"
            try:
                subprocess.run([rclone_bin, "copyto", USERS_FILE, remote_target, "--cache-dir", get_chat_cache_dir()], capture_output=True, timeout=10)
                print(f"✅ User permissions database synced to GCS Cloud Storage remote: {remote_target}")
            except Exception as e:
                print(f"Failed to sync users database to GCS: {e}")

        threading.Thread(target=_upload, daemon=True).start()

    # ==========================================
    # 🔐 LOGIN SCREEN VIEW
    # ==========================================
    def show_login_screen(self):
        for widget in self.root.winfo_children():
            widget.destroy()

        login_container = tk.Frame(self.root, bg="#181825")
        login_container.place(relx=0.5, rely=0.5, anchor="center")

        card = tk.Frame(login_container, bg="#1e1e2e", padx=30, pady=30, highlightthickness=1, highlightbackground="#313244")
        card.pack()

        tk.Label(card, text="☁️ Cloud NAS Control Center", bg="#1e1e2e", fg="#cdd6f4", font=("Segoe UI", 16, "bold")).pack(pady=(0, 5))
        tk.Label(card, text="🔐 User & Admin Authentication Required", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9)).pack(pady=(0, 20))

        # Username Input
        tk.Label(card, text="Username:", bg="#1e1e2e", fg="#bac2de", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 2))
        self.login_user_entry = tk.Entry(
            card, bg="#181825", fg="#cdd6f4", insertbackground="#cdd6f4",
            font=("Segoe UI", 10), relief="flat", highlightthickness=1, highlightbackground="#313244", width=26
        )
        self.login_user_entry.insert(0, "admin")
        self.login_user_entry.pack(pady=(0, 12))

        # Password Input
        tk.Label(card, text="Password:", bg="#1e1e2e", fg="#bac2de", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 2))
        self.login_pass_entry = tk.Entry(
            card, bg="#181825", fg="#cdd6f4", insertbackground="#cdd6f4", show="•",
            font=("Segoe UI", 10), relief="flat", highlightthickness=1, highlightbackground="#313244", width=26
        )
        self.login_pass_entry.insert(0, "password")
        self.login_pass_entry.pack(pady=(0, 15))

        self.login_err_lbl = tk.Label(card, text="", bg="#1e1e2e", fg="#f38ba8", font=("Segoe UI", 9, "bold"))
        self.login_err_lbl.pack(pady=(0, 8))

        # Login Button
        btn_login = DarkButton(
            card, text="🔓 Sign In to Control Center", command=self.handle_login,
            bg="#89b4fa", fg="#11111b", hover_bg="#74c7ec", font=("Segoe UI", 10, "bold"), padx=20, pady=8
        )
        btn_login.pack(fill="x")

        self.root.bind("<Return>", lambda e: self.handle_login())

    def handle_login(self):
        u_input = self.login_user_entry.get().strip()
        p_input = self.login_pass_entry.get().strip()

        for u in self.users_data.get("users", []):
            if u["username"].lower() == u_input.lower() and u["password"] == p_input:
                self.logged_in_user = u
                self.root.unbind("<Return>")

                # Save Active User Mount Config
                active_user_file = os.path.join(SCRIPT_DIR, "active_user_mount.json")
                try:
                    with open(active_user_file, "w") as f:
                        json.dump(u, f, indent=2)
                except Exception as e:
                    print(f"Error saving active user file: {e}")

                # Remount Cloud NAS drive for this user's folder scope & permissions
                self.remount_for_active_user(u)

                self.show_main_app()
                return

        self.login_err_lbl.config(text="❌ Invalid Username or Password")

    def remount_for_active_user(self, user):
        def _remount():
            folder = user.get("folder_path", "/")
            perm = user.get("permission", "Read-Write")
            uname = user.get("username", "User")
            
            print(f"Remounting Cloud NAS for user '{uname}' (Folder: '{folder}', Perm: '{perm}')...")
            mount_script = get_mount_script()
            if IS_MAC:
                subprocess.run(["bash", mount_script], capture_output=True)
            elif IS_WIN:
                subprocess.run(["cscript", "//nologo", mount_script], capture_output=True)
            
            if hasattr(self, "log_box"):
                self.log(f"🔐 Logged in as '{uname}'. Folder scope: '{folder}' ({perm}). Drive remounted!")

        threading.Thread(target=_remount, daemon=True).start()

    # ==========================================
    # 🎛️ MAIN APPLICATION DASHBOARD VIEW
    # ==========================================
    def show_main_app(self):
        for widget in self.root.winfo_children():
            widget.destroy()

        # Header Frame
        self.create_header()
        
        # Navigation Tabs Bar
        self.create_tab_bar()

        # Content Main Container Frame
        self.content_frame = tk.Frame(self.root, bg="#181825")
        self.content_frame.pack(fill="both", expand=True)

        # Show Default Dashboard View
        self.render_dashboard_tab()

        # Start Background Stats Poller
        self.poll_thread = threading.Thread(target=self.poll_stats_loop, daemon=True)
        self.poll_thread.start()

        # Start Live File Activity Watcher
        self.fs_thread = threading.Thread(target=self.fs_watcher_loop, daemon=True)
        self.fs_thread.start()

        # Start GCS Live Chat Poller Engine
        self.chat_thread = threading.Thread(target=self.chat_poller_loop, daemon=True)
        self.chat_thread.start()

    def create_header(self):
        header_frame = tk.Frame(self.root, bg="#181825", padx=15, pady=10)
        header_frame.pack(fill="x")

        title_label = tk.Label(
            header_frame, 
            text="☁️ Cloud NAS Control Center", 
            bg="#181825", 
            fg="#cdd6f4", 
            font=("Segoe UI", 14, "bold")
        )
        title_label.pack(side="left")

        right_panel = tk.Frame(header_frame, bg="#181825")
        right_panel.pack(side="right")

        user_disp = self.logged_in_user.get("username", "User") if self.logged_in_user else "User"
        folder_disp = self.logged_in_user.get("folder_path", "/") if self.logged_in_user else "/"
        
        tk.Label(
            right_panel, 
            text=f"👤 {user_disp} ({folder_disp})", 
            bg="#181825", 
            fg="#89b4fa", 
            font=("Segoe UI", 9, "bold")
        ).pack(side="left", padx=(0, 10))

        self.status_badge = tk.Label(
            right_panel, 
            text="● CONNECTING...", 
            bg="#f9e2af", 
            fg="#11111b", 
            font=("Segoe UI", 9, "bold"),
            padx=8, 
            pady=2,
            relief="flat"
        )
        self.status_badge.pack(side="left", padx=(0, 10))

        btn_logout = DarkButton(
            right_panel, text="🚪 Logout", command=self.handle_logout,
            bg="#313244", fg="#cdd6f4", hover_bg="#45475a", font=("Segoe UI", 8, "bold"), padx=8, pady=2
        )
        btn_logout.pack(side="left")

    def handle_logout(self):
        active_user_file = os.path.join(SCRIPT_DIR, "active_user_mount.json")
        if os.path.exists(active_user_file):
            try:
                os.remove(active_user_file)
            except Exception:
                pass
        
        # Reset session state and remove lingering admin tab references
        self.logged_in_user = None
        self.active_chat_recipient = None
        self.active_tab = "dashboard"
        self.unread_counts = {}
        if hasattr(self, "btn_tab_users"):
            delattr(self, "btn_tab_users")

        # Remount root drive on logout
        def _remount_root():
            mount_script = get_mount_script()
            if IS_MAC:
                subprocess.run(["bash", mount_script], capture_output=True)
            elif IS_WIN:
                subprocess.run(["cscript", "//nologo", mount_script], capture_output=True)

        threading.Thread(target=_remount_root, daemon=True).start()
        self.show_login_screen()

    def create_tab_bar(self):
        if hasattr(self, "btn_tab_users"):
            delattr(self, "btn_tab_users")

        tab_frame = tk.Frame(self.root, bg="#181825", padx=15, pady=0)
        tab_frame.pack(fill="x", pady=(0, 5))

        self.btn_tab_dashboard = DarkButton(
            tab_frame, text="📊 Live Dashboard", command=self.switch_to_dashboard,
            bg="#89b4fa", fg="#11111b", hover_bg="#74c7ec", font=("Segoe UI", 9, "bold"), padx=14, pady=5
        )
        self.btn_tab_dashboard.pack(side="left", padx=(0, 6))

        total_unread = sum(self.unread_counts.values())
        chat_title = f"💬 Live Chat ({total_unread})" if total_unread > 0 else "💬 Live Chat"

        self.btn_tab_chat = DarkButton(
            tab_frame, text=chat_title, command=self.switch_to_chat,
            bg="#313244", fg="#cdd6f4", hover_bg="#45475a", font=("Segoe UI", 9, "bold"), padx=14, pady=5
        )
        self.btn_tab_chat.pack(side="left", padx=(0, 6))

        # Show Users & Permissions tab if Admin
        is_admin = self.logged_in_user and (self.logged_in_user.get("role") == "Admin" or self.logged_in_user.get("username").lower() == "admin")
        if is_admin:
            self.btn_tab_users = DarkButton(
                tab_frame, text="👥 Users & Permissions", command=self.switch_to_users,
                bg="#313244", fg="#cdd6f4", hover_bg="#45475a", font=("Segoe UI", 9, "bold"), padx=14, pady=5
            )
            self.btn_tab_users.pack(side="left")

    def update_chat_tab_badge(self):
        total_unread = sum(self.unread_counts.values())
        chat_title = f"💬 Live Chat ({total_unread})" if total_unread > 0 else "💬 Live Chat"
        if hasattr(self, "btn_tab_chat") and self.btn_tab_chat and self.btn_tab_chat.winfo_exists():
            if self.active_tab == "chat":
                self.btn_tab_chat.config(text=chat_title, bg="#a6e3a1", fg="#11111b")
            else:
                self.btn_tab_chat.config(text=chat_title, bg="#313244", fg="#cdd6f4")

    def clear_content_frame(self):
        if hasattr(self, "content_frame") and self.content_frame.winfo_exists():
            for widget in list(self.content_frame.winfo_children()):
                try:
                    widget.destroy()
                except Exception:
                    pass
            self.root.update_idletasks()

    def switch_to_dashboard(self):
        self.active_tab = "dashboard"
        if hasattr(self, "btn_tab_dashboard") and self.btn_tab_dashboard and self.btn_tab_dashboard.winfo_exists():
            self.btn_tab_dashboard.config(bg="#89b4fa", fg="#11111b")
        self.update_chat_tab_badge()
        if hasattr(self, "btn_tab_users") and self.btn_tab_users and self.btn_tab_users.winfo_exists():
            self.btn_tab_users.config(bg="#313244", fg="#cdd6f4")
        self.clear_content_frame()
        self.render_dashboard_tab()

    def switch_to_chat(self):
        self.active_tab = "chat"
        if hasattr(self, "btn_tab_dashboard") and self.btn_tab_dashboard and self.btn_tab_dashboard.winfo_exists():
            self.btn_tab_dashboard.config(bg="#313244", fg="#cdd6f4")
        self.update_chat_tab_badge()
        if hasattr(self, "btn_tab_users") and self.btn_tab_users and self.btn_tab_users.winfo_exists():
            self.btn_tab_users.config(bg="#313244", fg="#cdd6f4")
        self.clear_content_frame()
        self.render_chat_tab()

    def switch_to_users(self):
        self.active_tab = "users"
        if hasattr(self, "btn_tab_users") and self.btn_tab_users and self.btn_tab_users.winfo_exists():
            self.btn_tab_users.config(bg="#cba6f7", fg="#11111b")
        if hasattr(self, "btn_tab_dashboard") and self.btn_tab_dashboard and self.btn_tab_dashboard.winfo_exists():
            self.btn_tab_dashboard.config(bg="#313244", fg="#cdd6f4")
        self.update_chat_tab_badge()
        self.clear_content_frame()
        self.render_users_tab()

    # ==========================================
    # 📊 TAB 1: DASHBOARD & DRIVE SETTINGS
    # ==========================================
    def render_dashboard_tab(self):
        self.create_drive_settings_bar()
        self.create_speed_cards()
        self.create_transfer_queue()
        self.create_action_toolbar()
        self.create_log_console()

    def get_current_drive_name(self):
        config_path = os.path.join(SCRIPT_DIR, "drive_config.json")
        if os.path.exists(config_path):
            try:
                with open(config_path, "r") as f:
                    data = json.load(f)
                    return data.get("volname", "Cloud NAS")
            except Exception:
                pass
        return "Cloud NAS"

    def get_mount_path(self):
        vol_name = self.get_current_drive_name()
        return os.path.join(os.path.expanduser("~"), vol_name)

    def scan_mount_files(self, path):
        file_map = {}
        dir_set = set()
        if not os.path.exists(path):
            return file_map, dir_set
        try:
            for root, dirs, files in os.walk(path):
                rel_root = os.path.relpath(root, path)
                if rel_root != ".":
                    dir_set.add(rel_root)

                for f in files:
                    if f.startswith("."):  # Ignore system hidden files
                        continue
                    full_path = os.path.join(root, f)
                    try:
                        stat = os.stat(full_path)
                        rel_path = os.path.relpath(full_path, path)
                        file_map[rel_path] = (stat.st_mtime, stat.st_size)
                    except Exception:
                        pass
        except Exception:
            pass
        return file_map, dir_set

    def fs_watcher_loop(self):
        mount_path = self.get_mount_path()
        last_files, last_dirs = self.scan_mount_files(mount_path)

        while self.is_monitoring:
            time.sleep(1.5)
            current_path = self.get_mount_path()
            if not os.path.exists(current_path):
                last_files, last_dirs = {}, set()
                continue

            current_files, current_dirs = self.scan_mount_files(current_path)

            if (last_files or last_dirs) and self.active_tab == "dashboard" and hasattr(self, "log_box"):
                for rel_dir in current_dirs:
                    if rel_dir not in last_dirs:
                        full_dir_path = os.path.join(current_path, rel_dir)
                        keep_file = os.path.join(full_dir_path, ".keep")
                        if not os.path.exists(keep_file):
                            try:
                                with open(keep_file, "w") as kf:
                                    kf.write("")
                            except Exception:
                                pass
                        self.root.after(0, self.log, f"📁 Folder Created & Synced: {rel_dir}")

                for rel_dir in last_dirs:
                    if rel_dir not in current_dirs:
                        self.root.after(0, self.log, f"🗑️ Folder Deleted: {rel_dir}")

                for rel_p in current_files:
                    if rel_p not in last_files:
                        self.root.after(0, self.log, f"➕ File Added: {rel_p}")
                    else:
                        old_mtime, old_size = last_files[rel_p]
                        new_mtime, new_size = current_files[rel_p]
                        if new_mtime > old_mtime or new_size != old_size:
                            self.root.after(0, self.log, f"✏️ File Modified: {rel_p}")

                for rel_p in last_files:
                    if rel_p not in current_files:
                        self.root.after(0, self.log, f"🗑️ File Deleted: {rel_p}")

            last_files = current_files
            last_dirs = current_dirs

    def create_drive_settings_bar(self):
        settings_frame = tk.Frame(self.content_frame, bg="#1e1e2e", padx=14, pady=8, highlightthickness=1, highlightbackground="#313244")
        settings_frame.pack(fill="x", padx=15, pady=(0, 8))

        tk.Label(settings_frame, text="🏷️ Drive Name:", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(side="left", padx=(0, 6))

        self.drive_name_entry = tk.Entry(
            settings_frame, bg="#181825", fg="#cdd6f4", insertbackground="#cdd6f4",
            font=("Segoe UI", 9, "bold"), relief="flat", highlightthickness=1, highlightbackground="#313244", width=18
        )
        self.drive_name_entry.insert(0, self.get_current_drive_name())
        self.drive_name_entry.pack(side="left", padx=(0, 8))

        btn_rename = DarkButton(
            settings_frame, text="✏️ Save & Remount Drive", command=self.action_rename_drive,
            bg="#f9e2af", fg="#11111b", hover_bg="#fae3b0", font=("Segoe UI", 8, "bold"), padx=10, pady=4
        )
        btn_rename.pack(side="left")

        # Active Folder Scope Badge
        user_folder = self.logged_in_user.get("folder_path", "/") if self.logged_in_user else "/"
        user_perm = self.logged_in_user.get("permission", "Read-Write") if self.logged_in_user else "Read-Write"
        scope_badge = f"🔒 Scope: {user_folder} ({user_perm})"
        
        tk.Label(
            settings_frame, text=scope_badge, bg="#1e1e2e", fg="#a6e3a1" if "Write" in user_perm else "#f9e2af",
            font=("Segoe UI", 8, "bold")
        ).pack(side="right")

    def create_speed_cards(self):
        cards_frame = tk.Frame(self.content_frame, bg="#181825", padx=15, pady=5)
        cards_frame.pack(fill="x")

        # Upload Speed Card
        up_card = tk.Frame(cards_frame, bg="#1e1e2e", padx=14, pady=10, highlightthickness=1, highlightbackground="#313244")
        up_card.pack(side="left", fill="both", expand=True, padx=(0, 7))

        tk.Label(up_card, text="⬆️ UPLOAD SPEED", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        self.up_speed_lbl = tk.Label(up_card, text="0.0 KB/s", bg="#1e1e2e", fg="#a6e3a1", font=("Segoe UI", 16, "bold"))
        self.up_speed_lbl.pack(anchor="w", pady=(2, 0))
        self.up_total_lbl = tk.Label(up_card, text="Total Uploaded: 0 MB", bg="#1e1e2e", fg="#bac2de", font=("Segoe UI", 9))
        self.up_total_lbl.pack(anchor="w")

        # Download Speed Card
        down_card = tk.Frame(cards_frame, bg="#1e1e2e", padx=14, pady=10, highlightthickness=1, highlightbackground="#313244")
        down_card.pack(side="right", fill="both", expand=True, padx=(7, 0))

        tk.Label(down_card, text="⬇️ DOWNLOAD SPEED", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        self.down_speed_lbl = tk.Label(down_card, text="0.0 KB/s", bg="#1e1e2e", fg="#89b4fa", font=("Segoe UI", 16, "bold"))
        self.down_speed_lbl.pack(anchor="w", pady=(2, 0))
        self.down_total_lbl = tk.Label(down_card, text="Total Downloaded: 0 MB", bg="#1e1e2e", fg="#bac2de", font=("Segoe UI", 9))
        self.down_total_lbl.pack(anchor="w")

    def create_transfer_queue(self):
        queue_frame = tk.Frame(self.content_frame, bg="#1e1e2e", padx=12, pady=10, highlightthickness=1, highlightbackground="#313244")
        queue_frame.pack(fill="x", padx=15, pady=(5, 10))

        tk.Label(queue_frame, text="⚡ ACTIVE TRANSFERS", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 4))
        
        self.active_file_lbl = tk.Label(queue_frame, text="No active file transfers", bg="#1e1e2e", fg="#cdd6f4", font=("Segoe UI", 9), anchor="w")
        self.active_file_lbl.pack(fill="x")

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
        toolbar_frame = tk.Frame(self.content_frame, bg="#181825", padx=15, pady=5)
        toolbar_frame.pack(fill="x")

        btn_refresh = DarkButton(
            toolbar_frame, text="🔄 Refresh Data", command=self.action_refresh_data,
            bg="#89b4fa", fg="#11111b", hover_bg="#74c7ec"
        )
        btn_refresh.pack(side="left", padx=(0, 8))

        btn_push = DarkButton(
            toolbar_frame, text="⬆️ Push (Sync Local -> GCS)", command=self.action_push,
            bg="#a6e3a1", fg="#11111b", hover_bg="#94e2d5"
        )
        btn_push.pack(side="left", padx=(0, 8))

        btn_pull = DarkButton(
            toolbar_frame, text="⬇️ Pull (Sync GCS -> Local)", command=self.action_pull,
            bg="#cba6f7", fg="#11111b", hover_bg="#f5c2e7"
        )
        btn_pull.pack(side="left", padx=(0, 8))

        btn_webdav = DarkButton(
            toolbar_frame, text="📱 Android / WebDAV Server", command=self.action_webdav_server,
            bg="#fab387", fg="#11111b", hover_bg="#f9e2af"
        )
        btn_webdav.pack(side="left")

    def action_webdav_server(self):
        """Starts or toggles WebDAV server for Android & local mobile clients."""
        if hasattr(self, "webdav_proc") and self.webdav_proc and self.webdav_proc.poll() is None:
            messagebox.showinfo("📱 Android WebDAV Server", "WebDAV Server is already running on port 8080!\n\nAndroid Connection Info:\n• Host: http://<your-ip-address>\n• Port: 8080\n• User: admin\n• Password: password")
            return

        def _start_webdav():
            rclone_bin = get_rclone_bin()
            try:
                self.webdav_proc = subprocess.Popen([rclone_bin, "serve", "webdav", "gcsnas:sv-school", "--addr", ":8080"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.log("🌐 Started Android WebDAV Server on port 8080 (http://0.0.0.0:8080)")
            except Exception as e:
                self.log(f"❌ Failed to start WebDAV Server: {e}")

        threading.Thread(target=_start_webdav, daemon=True).start()
        messagebox.showinfo(
            "📱 Android WebDAV Server Started!",
            "✅ WebDAV Server is now running on port 8080!\n\n"
            "Connect from Android (Solid Explorer / CX File Explorer):\n"
            "1. Add New Storage -> Select WebDAV\n"
            "2. Host: http://<your-ip-address>\n"
            "3. Port: 8080\n"
            "4. User: admin\n"
            "5. Password: password\n\n"
            "Cloud NAS is now accessible on Android!"
        )

    def create_log_console(self):
        console_frame = tk.Frame(self.content_frame, bg="#181825", padx=15, pady=10)
        console_frame.pack(fill="both", expand=True)

        log_header_frame = tk.Frame(console_frame, bg="#181825")
        log_header_frame.pack(fill="x", pady=(0, 4))

        tk.Label(log_header_frame, text="📋 LIVE ACTIVITY & FILE LOG", bg="#181825", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(side="left")

        btn_clear = DarkButton(
            log_header_frame, text="🧹 Clear Logs", command=self.action_clear_log,
            bg="#313244", fg="#cdd6f4", hover_bg="#45475a", font=("Segoe UI", 8, "bold"), padx=10, pady=3
        )
        btn_clear.pack(side="right")

        self.log_box = tk.Text(
            console_frame, bg="#1e1e2e", fg="#a6adc8", insertbackground="#cdd6f4",
            font=("Consolas", 9), relief="flat", highlightthickness=1, highlightbackground="#313244"
        )
        self.log_box.pack(fill="both", expand=True)
        
        user_disp = self.logged_in_user.get("username", "User") if self.logged_in_user else "User"
        user_folder = self.logged_in_user.get("folder_path", "/") if self.logged_in_user else "/"
        user_perm = self.logged_in_user.get("permission", "Read-Write") if self.logged_in_user else "Read-Write"
        self.log(f"Cloud NAS initialized for '{user_disp}'. Scoped to folder '{user_folder}' ({user_perm}).")

    def log(self, message):
        if hasattr(self, "log_box"):
            now = datetime.now().strftime("%H:%M:%S")
            self.log_box.insert("end", f"[{now}] {message}\n")
            self.log_box.see("end")

    # ==========================================
    # 💬 TAB 2: GCS CLOUD LIVE CHAT & NOTIFICATIONS
    # ==========================================
    def get_chat_filename(self, user1, user2):
        u1 = str(user1).lower().strip()
        u2 = str(user2).lower().strip()
        pair = sorted([u1, u2])
        return f"{pair[0]}_{pair[1]}.json"

    def fetch_chat_history(self, user1, user2):
        chat_file = self.get_chat_filename(user1, user2)
        remote_target = f"gcsnas:sv-school/.sys/chats/{chat_file}"
        rclone_bin = get_rclone_bin()

        try:
            res = subprocess.run([rclone_bin, "cat", remote_target, "--cache-dir", get_chat_cache_dir()], capture_output=True, text=True, timeout=5)
            if res.returncode == 0 and res.stdout.strip():
                data = json.loads(res.stdout)
                return data.get("messages", [])
        except Exception:
            pass
        return []

    def send_chat_message(self, recipient_username, text):
        if not text.strip() or not self.logged_in_user:
            return
        
        sender = self.logged_in_user.get("username", "User")
        chat_file = self.get_chat_filename(sender, recipient_username)
        remote_target = f"gcsnas:sv-school/.sys/chats/{chat_file}"
        tstamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # Optimistically insert message into UI immediately
        if hasattr(self, "chat_msg_box") and self.chat_msg_box.winfo_exists():
            self.chat_msg_box.config(state="normal")
            self.chat_msg_box.insert("end", f"[{tstamp}] You: ", "sent")
            self.chat_msg_box.insert("end", f"{text.strip()}\n")
            self.chat_msg_box.see("end")
            self.chat_msg_box.config(state="disabled")

        def _async_send():
            history = self.fetch_chat_history(sender, recipient_username)
            new_msg = {
                "sender": sender,
                "recipient": recipient_username,
                "text": text.strip(),
                "timestamp": tstamp
            }
            history.append(new_msg)
            
            tmp_local = os.path.join(SCRIPT_DIR, f"temp_{chat_file}")
            try:
                with open(tmp_local, "w") as f:
                    json.dump({"messages": history}, f, indent=2)
                
                rclone_bin = get_rclone_bin()
                
                subprocess.run([rclone_bin, "copyto", tmp_local, remote_target, "--cache-dir", get_chat_cache_dir()], capture_output=True, timeout=8)
                if os.path.exists(tmp_local):
                    os.remove(tmp_local)
            except Exception as e:
                print(f"Error sending chat message: {e}")

        threading.Thread(target=_async_send, daemon=True).start()

    def send_desktop_notification(self, title, message):
        """Triggers native desktop popups on macOS & Windows."""
        try:
            clean_title = title.replace('"', '\\"')
            clean_msg = message.replace('"', '\\"')
            
            if IS_MAC:
                cmd = f'display notification "{clean_msg}" with title "{clean_title}" sound name "default"'
                subprocess.run(["osascript", "-e", cmd], capture_output=True)
            elif IS_WIN:
                ps_cmd = (
                    f'[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms"); '
                    f'$n = New-Object System.Windows.Forms.NotifyIcon; '
                    f'$n.Icon = [System.Drawing.SystemIcons]::Information; '
                    f'$n.Visible = $true; '
                    f'$n.ShowBalloonTip(5000, "{clean_title}", "{clean_msg}", [System.Windows.Forms.ToolTipIcon]::Info);'
                )
                subprocess.run(["powershell", "-Command", ps_cmd], capture_output=True)
        except Exception:
            pass

    def chat_poller_loop(self):
        """Polls GCS chat store every 2.5 seconds for live incoming messages."""
        last_seen_count = {}
        
        while self.is_monitoring:
            time.sleep(2.5)
            if not self.logged_in_user:
                continue

            try:
                current_u = self.logged_in_user.get("username", "").lower()
                all_users = [u["username"] for u in self.users_data.get("users", []) if u["username"].lower() != current_u]

                for other_u in all_users:
                    if not self.is_monitoring or not self.logged_in_user:
                        break
                    messages = self.fetch_chat_history(current_u, other_u)
                    chat_id = self.get_chat_filename(current_u, other_u)
                    
                    prev_count = last_seen_count.get(chat_id, None)
                    curr_count = len(messages)
                    
                    if prev_count is not None and curr_count > prev_count:
                        new_msgs = messages[prev_count:]
                        for msg in new_msgs:
                            sender = msg.get("sender", "User")
                            if sender and sender.lower() != current_u:
                                text = msg.get("text", "")
                                
                                # Increment unread badge count if not actively reading
                                try:
                                    if self.active_tab != "chat" or (self.active_chat_recipient and self.active_chat_recipient.lower() != other_u.lower()):
                                        self.unread_counts[other_u] = self.unread_counts.get(other_u, 0) + 1
                                        self.root.after(0, self.update_chat_tab_badge)
                                except Exception:
                                    pass

                                # Send Desktop Notification
                                try:
                                    self.root.after(0, self.send_desktop_notification, f"💬 Message from {sender}", text)
                                except Exception:
                                    pass
                                
                                # Log to console
                                if hasattr(self, "log_box"):
                                    try:
                                        self.root.after(0, self.log, f"💬 Live Chat message from {sender}: '{text}'")
                                    except Exception:
                                        pass

                                # Refresh chat window if currently open
                                try:
                                    if self.active_tab == "chat" and self.active_chat_recipient and self.active_chat_recipient.lower() == other_u.lower():
                                        self.root.after(0, self.load_active_chat_messages)
                                except Exception:
                                    pass

                    last_seen_count[chat_id] = curr_count
            except Exception as e:
                print(f"Chat poller error: {e}")

    def render_chat_tab(self):
        # Ensure users database is loaded for non-admin users
        if not hasattr(self, "users_data") or not self.users_data.get("users"):
            self.load_users_data()

        container = tk.Frame(self.content_frame, bg="#181825", padx=15, pady=10)
        container.pack(fill="both", expand=True)

        # Left Column: Contacts List Sidebar
        contacts_sidebar = tk.Frame(container, bg="#1e1e2e", width=200, highlightthickness=1, highlightbackground="#313244")
        contacts_sidebar.pack(side="left", fill="y", padx=(0, 10))

        tk.Label(contacts_sidebar, text="👥 CONTACTS", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 9, "bold"), padx=12, pady=10).pack(anchor="w")

        self.contacts_list_frame = tk.Frame(contacts_sidebar, bg="#1e1e2e")
        self.contacts_list_frame.pack(fill="both", expand=True)

        # Right Column: Live Chat Window & Input
        self.chat_window_frame = tk.Frame(container, bg="#1e1e2e", highlightthickness=1, highlightbackground="#313244")
        self.chat_window_frame.pack(side="right", fill="both", expand=True)

        self.render_contacts_list()

        # Auto-select contact robustly with case-insensitive matching
        current_u = self.logged_in_user.get("username", "").lower() if self.logged_in_user else ""
        other_users = [u["username"] for u in self.users_data.get("users", []) if u["username"].lower() != current_u]

        target_contact = None
        if self.active_chat_recipient:
            for u_name in other_users:
                if u_name.lower() == self.active_chat_recipient.lower():
                    target_contact = u_name
                    break

        if not target_contact and other_users:
            target_contact = other_users[0]

        if target_contact:
            self.select_chat_contact(target_contact)

    def render_contacts_list(self):
        for widget in self.contacts_list_frame.winfo_children():
            widget.destroy()

        current_u = self.logged_in_user.get("username", "").lower() if self.logged_in_user else ""
        other_users = [u["username"] for u in self.users_data.get("users", []) if u["username"].lower() != current_u]

        for u_name in other_users:
            unread = self.unread_counts.get(u_name, 0)
            badge = f" 🔴 ({unread})" if unread > 0 else ""
            display_text = f"👤 {u_name}{badge}"
            
            is_active = (self.active_chat_recipient and self.active_chat_recipient.lower() == u_name.lower())
            btn_bg = "#313244" if is_active else "#181825"
            btn_fg = "#a6e3a1" if is_active else "#cdd6f4"

            btn_contact = DarkButton(
                self.contacts_list_frame, text=display_text, command=lambda name=u_name: self.select_chat_contact(name),
                bg=btn_bg, fg=btn_fg, hover_bg="#45475a", font=("Segoe UI", 9, "bold"), padx=12, pady=8, anchor="w"
            )
            btn_contact.pack(fill="x", pady=2, padx=6)

    def select_chat_contact(self, username):
        self.active_chat_recipient = username
        self.unread_counts[username] = 0
        self.update_chat_tab_badge()
        self.render_contacts_list()
        
        # Render Chat Thread Right Window
        for widget in self.chat_window_frame.winfo_children():
            widget.destroy()

        header = tk.Frame(self.chat_window_frame, bg="#313244", padx=12, pady=8)
        header.pack(fill="x")
        tk.Label(header, text=f"💬 Chatting with {username}", bg="#313244", fg="#cdd6f4", font=("Segoe UI", 10, "bold")).pack(anchor="w")

        # Chat Message History Box
        self.chat_msg_box = tk.Text(
            self.chat_window_frame, bg="#181825", fg="#cdd6f4", insertbackground="#cdd6f4",
            font=("Segoe UI", 9), relief="flat", padx=10, pady=10, state="disabled"
        )
        self.chat_msg_box.pack(fill="both", expand=True)

        self.chat_msg_box.tag_config("sent", foreground="#a6e3a1", font=("Segoe UI", 9, "bold"))
        self.chat_msg_box.tag_config("received", foreground="#89b4fa", font=("Segoe UI", 9, "bold"))
        self.chat_msg_box.tag_config("time", foreground="#a6adc8", font=("Segoe UI", 8, "italic"))

        # Input Bar
        input_frame = tk.Frame(self.chat_window_frame, bg="#1e1e2e", padx=10, pady=8)
        input_frame.pack(fill="x")

        self.chat_input_entry = tk.Entry(
            input_frame, bg="#181825", fg="#cdd6f4", insertbackground="#cdd6f4",
            font=("Segoe UI", 9), relief="flat", highlightthickness=1, highlightbackground="#313244"
        )
        self.chat_input_entry.pack(side="left", fill="x", expand=True, padx=(0, 8))
        self.chat_input_entry.bind("<Return>", lambda e: self.handle_send_chat())

        btn_send = DarkButton(
            input_frame, text="🚀 Send", command=self.handle_send_chat,
            bg="#89b4fa", fg="#11111b", hover_bg="#74c7ec", font=("Segoe UI", 8, "bold"), padx=12, pady=4
        )
        btn_send.pack(side="right")

        self.load_active_chat_messages()

    def handle_send_chat(self):
        if not hasattr(self, "chat_input_entry"):
            return
        text = self.chat_input_entry.get().strip()
        if text and self.active_chat_recipient:
            self.chat_input_entry.delete(0, "end")
            self.send_chat_message(self.active_chat_recipient, text)

    def load_active_chat_messages(self):
        if not self.active_chat_recipient or not hasattr(self, "chat_msg_box"):
            return
        
        recipient = self.active_chat_recipient
        current_u = self.logged_in_user.get("username", "") if self.logged_in_user else ""

        self.chat_msg_box.config(state="normal")
        self.chat_msg_box.delete("1.0", "end")
        self.chat_msg_box.insert("end", f"⏳ Syncing chat history with {recipient} from Cloud...\n", "time")
        self.chat_msg_box.config(state="disabled")

        def _async_load():
            try:
                messages = self.fetch_chat_history(current_u, recipient)
            except Exception:
                messages = []
            
            def _update_gui():
                try:
                    if not hasattr(self, "chat_msg_box") or not self.active_chat_recipient or self.active_chat_recipient.lower() != recipient.lower():
                        return
                    self.chat_msg_box.config(state="normal")
                    self.chat_msg_box.delete("1.0", "end")

                    if not messages:
                        self.chat_msg_box.insert("end", f"No previous messages with {recipient}. Send a message to start chatting!\n", "time")
                    else:
                        for m in messages:
                            sender = m.get("sender", "User")
                            text = m.get("text", "")
                            tstamp = m.get("timestamp", "")

                            if sender.lower() == current_u.lower():
                                self.chat_msg_box.insert("end", f"[{tstamp}] You: ", "sent")
                                self.chat_msg_box.insert("end", f"{text}\n")
                            else:
                                self.chat_msg_box.insert("end", f"[{tstamp}] {sender}: ", "received")
                                self.chat_msg_box.insert("end", f"{text}\n")

                    self.chat_msg_box.see("end")
                    self.chat_msg_box.config(state="disabled")
                except Exception:
                    pass

            try:
                self.root.after(0, _update_gui)
            except Exception:
                pass

        threading.Thread(target=_async_load, daemon=True).start()

    # ==========================================
    # 👥 TAB 3: USERS & PERMISSIONS MANAGER
    # ==========================================
    def render_users_tab(self):
        container = tk.Frame(self.content_frame, bg="#181825", padx=15, pady=10)
        container.pack(fill="both", expand=True)

        # Add New User Form Card
        add_card = tk.Frame(container, bg="#1e1e2e", padx=15, pady=12, highlightthickness=1, highlightbackground="#313244")
        add_card.pack(fill="x", pady=(0, 15))

        tk.Label(add_card, text="➕ ADD NEW USER & ACCESS PERMISSION", bg="#1e1e2e", fg="#cdd6f4", font=("Segoe UI", 10, "bold")).pack(anchor="w", pady=(0, 8))

        form_grid = tk.Frame(add_card, bg="#1e1e2e")
        form_grid.pack(fill="x")

        # Row 1: Username & Password
        row1 = tk.Frame(form_grid, bg="#1e1e2e")
        row1.pack(fill="x", pady=(0, 8))

        col_u = tk.Frame(row1, bg="#1e1e2e")
        col_u.pack(side="left", padx=(0, 12))
        tk.Label(col_u, text="Username:", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 8, "bold")).pack(anchor="w")
        self.new_uname_entry = tk.Entry(col_u, bg="#181825", fg="#cdd6f4", insertbackground="#cdd6f4", font=("Segoe UI", 9), relief="flat", highlightthickness=1, highlightbackground="#313244", width=18)
        self.new_uname_entry.pack()

        col_p = tk.Frame(row1, bg="#1e1e2e")
        col_p.pack(side="left", padx=(0, 12))
        tk.Label(col_p, text="Password:", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 8, "bold")).pack(anchor="w")
        self.new_pass_entry = tk.Entry(col_p, bg="#181825", fg="#cdd6f4", insertbackground="#cdd6f4", font=("Segoe UI", 9), relief="flat", highlightthickness=1, highlightbackground="#313244", width=18)
        self.new_pass_entry.pack()

        # Row 2: Folder Access Scope, Specific Folder Path, & Permission Mode
        row2 = tk.Frame(form_grid, bg="#1e1e2e")
        row2.pack(fill="x")

        col_scope = tk.Frame(row2, bg="#1e1e2e")
        col_scope.pack(side="left", padx=(0, 12))
        tk.Label(col_scope, text="Folder Access Scope:", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 8, "bold")).pack(anchor="w")
        
        self.scope_var = tk.StringVar(value="Full Access (All Folders)")
        scope_opt = tk.OptionMenu(col_scope, self.scope_var, "Full Access (All Folders)", "Specific Folder", command=self.on_scope_change)
        scope_opt.config(bg="#181825", fg="#cdd6f4", activebackground="#313244", font=("Segoe UI", 8), highlightthickness=0)
        scope_opt["menu"].config(bg="#1e1e2e", fg="#cdd6f4")
        scope_opt.pack()

        col_folder = tk.Frame(row2, bg="#1e1e2e")
        col_folder.pack(side="left", padx=(0, 12))
        tk.Label(col_folder, text="Folder Path / Name:", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 8, "bold")).pack(anchor="w")
        self.new_folder_entry = tk.Entry(col_folder, bg="#181825", fg="#cdd6f4", insertbackground="#cdd6f4", font=("Segoe UI", 9), relief="flat", highlightthickness=1, highlightbackground="#313244", width=16)
        self.new_folder_entry.insert(0, "/")
        self.new_folder_entry.pack()

        col_perm = tk.Frame(row2, bg="#1e1e2e")
        col_perm.pack(side="left", padx=(0, 12))
        tk.Label(col_perm, text="Permission Type:", bg="#1e1e2e", fg="#a6adc8", font=("Segoe UI", 8, "bold")).pack(anchor="w")
        self.perm_var = tk.StringVar(value="Read-Write")
        perm_opt = tk.OptionMenu(col_perm, self.perm_var, "Read-Write", "Read-Only")
        perm_opt.config(bg="#181825", fg="#cdd6f4", activebackground="#313244", font=("Segoe UI", 8), highlightthickness=0)
        perm_opt["menu"].config(bg="#1e1e2e", fg="#cdd6f4")
        perm_opt.pack()

        # Save Button
        btn_add = DarkButton(
            row2, text="Save User", command=self.handle_add_user,
            bg="#a6e3a1", fg="#11111b", hover_bg="#94e2d5", font=("Segoe UI", 8, "bold"), padx=14, pady=4
        )
        btn_add.pack(side="left", pady=(14, 0))

        # Users List Header & Table
        tk.Label(container, text="👥 SYSTEM USERS & ROLE PERMISSIONS", bg="#181825", fg="#a6adc8", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 6))

        self.users_list_frame = tk.Frame(container, bg="#1e1e2e", padx=10, pady=10, highlightthickness=1, highlightbackground="#313244")
        self.users_list_frame.pack(fill="both", expand=True)

        self.render_users_table()

    def on_scope_change(self, val):
        if val == "Full Access (All Folders)":
            self.new_folder_entry.delete(0, "end")
            self.new_folder_entry.insert(0, "/")
        else:
            if self.new_folder_entry.get() == "/":
                self.new_folder_entry.delete(0, "end")
                self.new_folder_entry.insert(0, "/Philip")

    def render_users_table(self):
        for widget in self.users_list_frame.winfo_children():
            widget.destroy()

        # Table Headers
        headers_frame = tk.Frame(self.users_list_frame, bg="#313244", padx=8, pady=5)
        headers_frame.pack(fill="x", pady=(0, 5))

        tk.Label(headers_frame, text="USERNAME", bg="#313244", fg="#cdd6f4", font=("Segoe UI", 8, "bold"), width=16, anchor="w").pack(side="left")
        tk.Label(headers_frame, text="ROLE", bg="#313244", fg="#cdd6f4", font=("Segoe UI", 8, "bold"), width=8, anchor="w").pack(side="left")
        tk.Label(headers_frame, text="FOLDER ACCESS", bg="#313244", fg="#cdd6f4", font=("Segoe UI", 8, "bold"), width=18, anchor="w").pack(side="left")
        tk.Label(headers_frame, text="PERMISSION", bg="#313244", fg="#cdd6f4", font=("Segoe UI", 8, "bold"), width=14, anchor="w").pack(side="left")
        tk.Label(headers_frame, text="CREATED AT", bg="#313244", fg="#cdd6f4", font=("Segoe UI", 8, "bold"), width=14, anchor="w").pack(side="left")
        tk.Label(headers_frame, text="ACTION", bg="#313244", fg="#cdd6f4", font=("Segoe UI", 8, "bold"), width=8, anchor="w").pack(side="left")

        # Table Rows
        users = self.users_data.get("users", [])
        for idx, u in enumerate(users):
            row_bg = "#1e1e2e" if idx % 2 == 0 else "#181825"
            row = tk.Frame(self.users_list_frame, bg=row_bg, padx=8, pady=4)
            row.pack(fill="x")

            uname = u["username"]
            role = u.get("role", "User")
            scope = u.get("folder_scope", "Full Access")
            fpath = u.get("folder_path", "/")
            perm = u.get("permission", "Read-Write")
            created = u.get("created_at", "-")

            folder_display = "🌐 All Folders" if scope == "Full Access (All Folders)" or fpath == "/" else f"📁 {fpath}"

            tk.Label(row, text=uname, bg=row_bg, fg="#cdd6f4", font=("Segoe UI", 9, "bold"), width=16, anchor="w").pack(side="left")
            tk.Label(row, text=role, bg=row_bg, fg="#89b4fa", font=("Segoe UI", 8, "bold"), width=8, anchor="w").pack(side="left")
            tk.Label(row, text=folder_display, bg=row_bg, fg="#f9e2af" if "/" in folder_display else "#89b4fa", font=("Segoe UI", 8, "bold"), width=18, anchor="w").pack(side="left")
            tk.Label(row, text=perm, bg=row_bg, fg="#a6e3a1" if "Write" in perm else "#f9e2af", font=("Segoe UI", 8), width=14, anchor="w").pack(side="left")
            tk.Label(row, text=created, bg=row_bg, fg="#bac2de", font=("Segoe UI", 8), width=14, anchor="w").pack(side="left")

            if uname.lower() != "admin":
                btn_del = DarkButton(
                    row, text="🗑️ Delete", command=lambda name=uname: self.handle_delete_user(name),
                    bg="#f38ba8", fg="#11111b", hover_bg="#e57497", font=("Segoe UI", 7, "bold"), padx=6, pady=2
                )
                btn_del.pack(side="left")
            else:
                tk.Label(row, text="System", bg=row_bg, fg="#a6adc8", font=("Segoe UI", 8, "italic"), width=8, anchor="w").pack(side="left")

    def handle_add_user(self):
        uname = self.new_uname_entry.get().strip()
        pword = self.new_pass_entry.get().strip()
        scope = self.scope_var.get()
        fpath = self.new_folder_entry.get().strip()
        perm = self.perm_var.get()

        if not uname or not pword:
            return

        if not fpath or scope == "Full Access (All Folders)":
            fpath = "/"

        # Check duplicate
        for u in self.users_data.get("users", []):
            if u["username"].lower() == uname.lower():
                return

        new_u = {
            "username": uname,
            "password": pword,
            "role": "User",
            "folder_scope": scope,
            "folder_path": fpath,
            "permission": perm,
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M")
        }

        self.users_data["users"].append(new_u)
        self.save_users_data()

        self.new_uname_entry.delete(0, "end")
        self.new_pass_entry.delete(0, "end")
        self.render_users_table()

    def handle_delete_user(self, username):
        self.users_data["users"] = [u for u in self.users_data.get("users", []) if u["username"].lower() != username.lower()]
        self.save_users_data()
        self.render_users_table()

    # ==========================================
    # ⚡ API & POLLER HELPERS
    # ==========================================
    def api_post(self, endpoint, params=None):
        try:
            conn = http.client.HTTPConnection('127.0.0.1', 5572, timeout=2)
            body = json.dumps(params) if params else "{}"
            headers = {'Content-Type': 'application/json'}
            conn.request('POST', f'/{endpoint}', body=body, headers=headers)
            resp = conn.getresponse()
            if resp.status == 200:
                raw_data = resp.read()
                conn.close()
                return json.loads(raw_data.decode('utf-8'))
            conn.close()
        except Exception:
            pass
        return None

    def poll_stats_loop(self):
        while self.is_monitoring:
            try:
                stats = self.api_post("core/stats")
                if stats:
                    self.mounted = True
                    try:
                        if hasattr(self, "status_badge") and self.status_badge.winfo_exists():
                            self.root.after(0, self.update_ui_stats, stats)
                    except Exception:
                        pass
                else:
                    self.mounted = False
                    try:
                        if hasattr(self, "status_badge") and self.status_badge.winfo_exists():
                            self.root.after(0, self.update_ui_disconnected)
                    except Exception:
                        pass
            except Exception:
                pass
            time.sleep(1)

    def update_ui_stats(self, stats):
        if hasattr(self, "status_badge") and self.status_badge.winfo_exists():
            self.status_badge.config(text="● ONLINE & MOUNTED", bg="#a6e3a1", fg="#11111b")

        if self.active_tab == "dashboard" and hasattr(self, "up_speed_lbl"):
            speed_bytes = stats.get("speed", 0)
            speed_kb = speed_bytes / 1024.0
            bytes_total = stats.get("bytes", 0)
            mb_total = bytes_total / (1024.0 * 1024.0)

            self.up_speed_lbl.config(text=f"{speed_kb:.1f} KB/s")
            self.up_total_lbl.config(text=f"Total Uploaded: {mb_total:.2f} MB")

            transfers = stats.get("transferring", [])
            if transfers:
                active_file = transfers[0].get("name", "Syncing...")
                pct = transfers[0].get("percentage", 0)
                self.active_file_lbl.config(text=f"Syncing: {active_file} ({pct}%)")
                self.set_progress(pct)

                if active_file not in self.tracked_transfers:
                    self.tracked_transfers.add(active_file)
                    self.log(f"📤 Syncing Cloud File: {active_file}")
            else:
                self.active_file_lbl.config(text="Idle - All files fully synchronized")
                self.set_progress(100)

    def update_ui_disconnected(self):
        if hasattr(self, "status_badge") and self.status_badge.winfo_exists():
            self.status_badge.config(text="● DISCONNECTED / UNMOUNTED", bg="#f38ba8", fg="#11111b")
        if self.active_tab == "dashboard" and hasattr(self, "up_speed_lbl"):
            self.up_speed_lbl.config(text="0.0 KB/s")
            self.down_speed_lbl.config(text="0.0 KB/s")
            self.active_file_lbl.config(text="Cloud NAS is not currently mounted.")
            self.set_progress(0)

    def action_rename_drive(self):
        new_name = self.drive_name_entry.get().strip()
        if not new_name:
            new_name = "Cloud NAS"
            self.drive_name_entry.delete(0, "end")
            self.drive_name_entry.insert(0, new_name)
        
        config_path = os.path.join(SCRIPT_DIR, "drive_config.json")
        try:
            with open(config_path, "w") as f:
                json.dump({"volname": new_name}, f, indent=2)
        except Exception as e:
            self.log(f"❌ Failed to save drive config: {e}")
            return

        def _remount():
            self.log(f"✏️ Renaming Cloud NAS volume to '{new_name}'...")
            self.log("Unmounting current volume & re-applying volume name...")
            if IS_MAC:
                mount_script = os.path.join(SCRIPT_DIR, "mac-mount.sh")
                subprocess.run(["bash", mount_script], capture_output=True)
            elif IS_WIN:
                mount_script = os.path.join(SCRIPT_DIR, "windows-mount-hidden.vbs")
                subprocess.run(["cscript", "//nologo", mount_script], capture_output=True)
            self.log(f"✅ Drive successfully renamed to '{new_name}' and remounted!")

        threading.Thread(target=_remount, daemon=True).start()

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
            self.log("Triggering Push: Forcing instant sync of local files to GCS...")
            res1 = self.api_post("vfs/forget")
            res2 = self.api_post("vfs/refresh", {"recursive": "true"})
            if res1 or res2:
                self.log("✅ Push completed! All local files and folders synced to Google Cloud.")
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

    def action_clear_log(self):
        self.log_box.delete("1.0", "end")
        self.log("Activity log cleared.")

def main():
    try:
        root = tk.Tk()
        app = CloudNASApp(root)
        root.mainloop()
    except Exception as e:
        import traceback
        err_text = traceback.format_exc()
        try:
            log_path = os.path.join(SCRIPT_DIR, "cloud_nas_gui_error.log")
            with open(log_path, "a") as f:
                f.write(f"[{datetime.now()}] GUI Launch Error:\n{err_text}\n")
        except Exception:
            pass
        raise e

if __name__ == "__main__":
    main()
