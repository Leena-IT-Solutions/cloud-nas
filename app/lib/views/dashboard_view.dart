import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/gcs_service.dart';
import '../services/storage_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _auth = AuthService();
  final _gcs = GCSService();
  final _storage = StorageService();

  int _totalFiles = 0;
  int _totalSize = 0;
  bool _isLoading = true;
  List<String> _savedDisks = [];

  @override
  void initState() {
    super.initState();
    _loadStatsAndDisks();
  }

  void _loadStatsAndDisks() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final disks = await _storage.getSavedDiskNames();
    final files = await _gcs.listFiles(user.isAdmin ? "" : user.folderPath);
    int size = 0;
    for (var f in files) {
      size += f.size;
    }

    if (mounted) {
      setState(() {
        _savedDisks = disks;
        _totalFiles = files.length;
        _totalSize = size;
        _isLoading = false;
      });
    }
  }

  void _switchDisk(String bucketName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Switching disk to '$bucketName'...")),
    );

    final success = await _gcs.switchDisk(bucketName);
    if (success && mounted) {
      _loadStatsAndDisks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Switched to disk '$bucketName'")),
      );
    }
  }

  void _deleteDisk(String bucketName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text("Delete Disk Profile", style: GoogleFonts.outfit(color: const Color(0xFFCDD6F4))),
        content: Text("Are you sure you want to remove disk '$bucketName' from saved list?", style: GoogleFonts.inter(color: const Color(0xFFA6ADC8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.inter(color: const Color(0xFFA6ADC8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF38BA8)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: GoogleFonts.inter(color: const Color(0xFF11111B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.removeDiskProfile(bucketName);
      if (_gcs.bucketName == bucketName) {
        await _gcs.restoreSavedSettings();
      }
      _loadStatsAndDisks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Removed disk profile '$bucketName'")),
        );
      }
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
              // Welcome Banner Card
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
                        Expanded(child: _buildStatCard("Active Disk", _gcs.bucketName.isNotEmpty ? _gcs.bucketName : "None", Icons.cloud_queue_rounded, const Color(0xFFCBA6F7))),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildStatCard("Total Files", _isLoading ? "..." : "$_totalFiles", Icons.insert_drive_file_outlined, const Color(0xFF89B4FA)),
                        const SizedBox(height: 12),
                        _buildStatCard("Storage Used", _isLoading ? "..." : _formatSize(_totalSize), Icons.sd_storage_outlined, const Color(0xFFA6E3A1)),
                        const SizedBox(height: 12),
                        _buildStatCard("Active Disk", _gcs.bucketName.isNotEmpty ? _gcs.bucketName : "None", Icons.cloud_queue_rounded, const Color(0xFFCBA6F7)),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 20),

              // SAVED STORAGE DISKS MANAGER CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sd_storage_rounded, color: Color(0xFF89B4FA), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "CONFIGURED STORAGE DISKS",
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFCDD6F4),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "${_savedDisks.length} Disks",
                          style: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_savedDisks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          "No storage disks configured yet.",
                          style: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 13),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _savedDisks.length,
                        separatorBuilder: (ctx, i) => const Divider(color: Color(0xFF313244), height: 1),
                        itemBuilder: (ctx, i) {
                          final disk = _savedDisks[i];
                          final isActive = disk == _gcs.bucketName;

                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: CircleAvatar(
                                backgroundColor: isActive
                                    ? const Color(0xFFA6E3A1).withValues(alpha: 0.15)
                                    : const Color(0xFF89B4FA).withValues(alpha: 0.15),
                                child: Icon(
                                  Icons.sd_card_rounded,
                                  color: isActive ? const Color(0xFFA6E3A1) : const Color(0xFF89B4FA),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                disk,
                                style: GoogleFonts.inter(
                                  color: isActive ? const Color(0xFFA6E3A1) : const Color(0xFFCDD6F4),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                isActive ? "🟢 Active Storage Disk" : "Click to switch to this disk",
                                style: GoogleFonts.inter(
                                  color: isActive ? const Color(0xFFA6E3A1) : const Color(0xFFA6ADC8),
                                  fontSize: 11,
                                ),
                              ),
                              onTap: isActive ? null : () => _switchDisk(disk),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isActive)
                                    TextButton(
                                      onPressed: () => _switchDisk(disk),
                                      child: Text("Use Disk", style: GoogleFonts.inter(color: const Color(0xFF89B4FA), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF38BA8), size: 20),
                                    onPressed: () => _deleteDisk(disk),
                                    tooltip: "Delete Disk Entry",
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
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
                  fontSize: 18,
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
