import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/gcs_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _auth = AuthService();
  final _gcs = GCSService();
  int _totalFiles = 0;
  int _totalSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final files = await _gcs.listFiles(user.isAdmin ? "" : user.folderPath);
    int size = 0;
    for (var f in files) {
      size += f.size;
    }

    if (mounted) {
      setState(() {
        _totalFiles = files.length;
        _totalSize = size;
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1E2E), Color(0xFF313244)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF45475A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF89B4FA).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF89B4FA), size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back, ${user?.username ?? 'User'}!",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFCDD6F4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Scope: ${user?.folderPath} (${user?.permission})",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFA6ADC8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Responsive Stat Cards
              LayoutBuilder(
                builder: (ctx, constraints) {
                  bool isWide = constraints.maxWidth >= 600;
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: _buildStatCard("Total Files", _isLoading ? "..." : "$_totalFiles", Icons.insert_drive_file_outlined, const Color(0xFF89B4FA))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard("Storage Used", _isLoading ? "..." : _formatSize(_totalSize), Icons.sd_storage_outlined, const Color(0xFFA6E3A1))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard("Cloud Engine", "Google Cloud", Icons.cloud_queue_rounded, const Color(0xFFCBA6F7))),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildStatCard("Total Files", _isLoading ? "..." : "$_totalFiles", Icons.insert_drive_file_outlined, const Color(0xFF89B4FA)),
                        const SizedBox(height: 12),
                        _buildStatCard("Storage Used", _isLoading ? "..." : _formatSize(_totalSize), Icons.sd_storage_outlined, const Color(0xFFA6E3A1)),
                        const SizedBox(height: 12),
                        _buildStatCard("Cloud Engine", "Google Cloud (gcsnas)", Icons.cloud_queue_rounded, const Color(0xFFCBA6F7)),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFA6ADC8),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFCDD6F4),
                ),
              ),
            ],
          ),
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }
}
