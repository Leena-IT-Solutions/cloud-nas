import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
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
  const CloudNASApp({Key? key}) : super(key: key);

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
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _auth = AuthService();
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return LoginView(
        onLoginSuccess: () => setState(() => _activeTabIndex = 0),
      );
    }

    final user = _auth.currentUser!;

    final List<Widget> tabs = [
      const DashboardView(),
      const ExplorerView(),
      const ChatView(),
      if (user.isAdmin) const UsersView(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2E),
                border: Border(bottom: BorderSide(color: Color(0xFF313244))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_queue_rounded, color: Color(0xFF89B4FA), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "CLOUD NAS",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFCDD6F4),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Navigation Tabs
                  Row(
                    children: [
                      _buildNavButton(0, "📊 Live Dashboard"),
                      const SizedBox(width: 8),
                      _buildNavButton(1, "📁 File Explorer"),
                      const SizedBox(width: 8),
                      _buildNavButton(2, "💬 Live Chat"),
                      if (user.isAdmin) ...[
                        const SizedBox(width: 8),
                        _buildNavButton(3, "👥 Users & Permissions"),
                      ],
                    ],
                  ),
                  const Spacer(),
                  // Active User Badge & Logout Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF313244),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, color: Color(0xFFA6E3A1), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          user.username,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFCDD6F4),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFF38BA8), size: 20),
                    onPressed: () {
                      _auth.logout();
                      setState(() => _activeTabIndex = 0);
                    },
                    tooltip: "Logout",
                  ),
                ],
              ),
            ),
            // Active Tab View Content
            Expanded(
              child: IndexedStack(
                index: _activeTabIndex,
                children: tabs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(int index, String label) {
    final isSelected = _activeTabIndex == index;
    return ElevatedButton(
      onPressed: () => setState(() => _activeTabIndex = index),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF89B4FA) : const Color(0xFF181825),
        foregroundColor: isSelected ? const Color(0xFF11111B) : const Color(0xFFCDD6F4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
