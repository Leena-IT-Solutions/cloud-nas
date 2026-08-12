import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'services/auth_service.dart';
import 'services/gcs_service.dart';
import 'services/storage_service.dart';
import 'views/login_view.dart';
import 'views/dashboard_view.dart';
import 'views/explorer_view.dart';
import 'views/chat_view.dart';
import 'views/users_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CloudNASApp());
}

class CloudNASApp extends StatelessWidget {
  const CloudNASApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CLOUD NAS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181825),
        primaryColor: const Color(0xFF89B4FA),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _auth = AuthService();
  final _gcs = GCSService();
  final _storage = StorageService();

  int _activeTabIndex = 0;
  bool _isInitializing = true;
  List<String> _savedDisks = [];

  @override
  void initState() {
    super.initState();
    _initSavedSession();
  }

  void _initSavedSession() async {
    final gcsConnected = await _gcs.restoreSavedSettings();
    final disks = await _storage.getSavedDiskNames();
    setState(() => _savedDisks = disks);

    if (gcsConnected) {
      await _auth.loadUsersDatabase();
      final userSession = await _auth.restoreSavedSession();
      if (userSession == null) {
        final creds = await _storage.getUserCredentials();
        if (creds != null) {
          await _auth.login(creds['username']!, creds['password']!);
        }
      }
    }
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _switchActiveDisk(String bucketName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Switching disk to '$bucketName'...")),
    );

    final success = await _gcs.switchDisk(bucketName);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Switched to disk '$bucketName'")),
      );
      setState(() {});
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to connect to disk '$bucketName'")),
      );
    }
  }

  void _showAddNewDiskDialog() {
    final bucketCtrl = TextEditingController();
    final jsonTextCtrl = TextEditingController();
    Map<String, dynamic>? keyJson;
    String? keyFileName;
    bool isConnecting = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_to_photos_rounded, color: Color(0xFF89B4FA), size: 22),
                const SizedBox(width: 8),
                Text("Connect New Storage Disk", style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFFCDD6F4))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMsg != null) ...[
                    Text(errorMsg!, style: GoogleFonts.inter(color: const Color(0xFFF38BA8), fontSize: 12)),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: bucketCtrl,
                    style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 13),
                    decoration: InputDecoration(
                      labelText: "Disk / Bucket Name",
                      labelStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF181825),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("GCP SERVICE ACCOUNT KEY", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFA6ADC8))),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        if (file.bytes != null) {
                          try {
                            final parsed = jsonDecode(utf8.decode(file.bytes!));
                            setDialogState(() {
                              keyJson = parsed;
                              keyFileName = file.name;
                            });
                          } catch (e) {
                            setDialogState(() => errorMsg = "Invalid JSON file.");
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.key_rounded, size: 16),
                    label: Text(keyFileName ?? "Select .json Key File", style: GoogleFonts.inter(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF89B4FA),
                      side: const BorderSide(color: Color(0xFF313244)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: jsonTextCtrl,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "Or paste Service Account JSON text here...",
                      hintStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF181825),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        try {
                          final parsed = jsonDecode(val.trim());
                          setDialogState(() {
                            keyJson = parsed;
                            keyFileName = "Pasted JSON Key";
                          });
                        } catch (_) {}
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancel", style: GoogleFonts.inter(color: const Color(0xFFA6ADC8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF89B4FA), foregroundColor: const Color(0xFF11111B)),
                onPressed: isConnecting
                    ? null
                    : () async {
                        final bucket = bucketCtrl.text.trim();
                        if (bucket.isEmpty || keyJson == null) {
                          setDialogState(() => errorMsg = "Please enter bucket name & GCP key.");
                          return;
                        }

                        setDialogState(() => isConnecting = true);
                        _gcs.configure(bucket: bucket, keyJson: keyJson);
                        final success = await _gcs.testConnection();

                        if (success) {
                          final disks = await _storage.getSavedDiskNames();
                          if (mounted) {
                            setState(() => _savedDisks = disks);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Connected & switched to disk '$bucket'")),
                            );
                          }
                        } else {
                          setDialogState(() {
                            isConnecting = false;
                            errorMsg = "Connection failed. Check bucket name & key.";
                          });
                        }
                      },
                child: isConnecting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11111B)))
                    : Text("Connect Disk", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF181825),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF89B4FA)),
        ),
      );
    }

    if (_auth.currentUser == null) {
      return LoginView(
        onLoginSuccess: () => setState(() => _activeTabIndex = 0),
      );
    }

    final user = _auth.currentUser!;

    final List<Widget> tabs = [
      const ExplorerView(),
      const DashboardView(),
      const ChatView(),
      if (user.isAdmin) const UsersView(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/app_logo.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "CLOUD NAS",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFCDD6F4),
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        actions: [
          // DISK SWITCHER TOP BAR BUTTON
          PopupMenuButton<String>(
            tooltip: "Switch Storage Disk",
            color: const Color(0xFF1E1E2E),
            onSelected: (val) {
              if (val == '__ADD_NEW__') {
                _showAddNewDiskDialog();
              } else {
                _switchActiveDisk(val);
              }
            },
            itemBuilder: (ctx) => [
              ..._savedDisks.map(
                (disk) => PopupMenuItem(
                  value: disk,
                  child: Row(
                    children: [
                      Icon(
                        Icons.sd_storage_rounded,
                        color: disk == _gcs.bucketName ? const Color(0xFFA6E3A1) : const Color(0xFFA6ADC8),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        disk,
                        style: GoogleFonts.inter(
                          color: disk == _gcs.bucketName ? const Color(0xFFA6E3A1) : const Color(0xFFCDD6F4),
                          fontWeight: disk == _gcs.bucketName ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: '__ADD_NEW__',
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF89B4FA), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Connect New Disk",
                      style: GoogleFonts.inter(color: const Color(0xFF89B4FA), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF89B4FA).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF89B4FA).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sd_storage_rounded, color: Color(0xFF89B4FA), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _gcs.bucketName.isNotEmpty ? _gcs.bucketName : "No Disk",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF89B4FA),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF89B4FA), size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF313244),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_rounded, color: Color(0xFFA6E3A1), size: 14),
                const SizedBox(width: 4),
                Text(
                  user.username,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFCDD6F4),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFCDD6F4)),
            color: const Color(0xFF1E1E2E),
            onSelected: (val) async {
              if (val == 'logout') {
                await _auth.logout();
                setState(() => _activeTabIndex = 0);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: Color(0xFFF38BA8), size: 18),
                    const SizedBox(width: 8),
                    Text("Logout", style: GoogleFonts.inter(color: const Color(0xFFF38BA8), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _activeTabIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _activeTabIndex,
        onTap: (index) => setState(() => _activeTabIndex = index),
        backgroundColor: const Color(0xFF1E1E2E),
        selectedItemColor: const Color(0xFF89B4FA),
        unselectedItemColor: const Color(0xFFA6ADC8),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: "Files",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: "Dashboard",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded),
            label: "Chat",
          ),
          if (user.isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded),
              label: "Users",
            ),
        ],
      ),
    );
  }
}
