import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'services/gcs_service.dart';
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
      title: 'Cloud NAS',
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
  int _activeTabIndex = 0;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initSavedSession();
  }

  void _initSavedSession() async {
    await _gcs.restoreSavedSettings();
    await _auth.restoreSavedSession();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
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
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "LITS in the Cloud",
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFCDD6F4),
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    fontSize: 12,
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
