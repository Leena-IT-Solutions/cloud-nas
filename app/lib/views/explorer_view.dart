import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/file_item.dart';
import '../services/auth_service.dart';
import '../services/gcs_service.dart';

class ExplorerView extends StatefulWidget {
  const ExplorerView({Key? key}) : super(key: key);

  @override
  State<ExplorerView> createState() => _ExplorerViewState();
}

class _ExplorerViewState extends State<ExplorerView> {
  final _auth = AuthService();
  final _gcs = GCSService();

  String _currentPath = "";
  List<FileItem> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null && !user.isAdmin) {
      String p = user.folderPath;
      if (p.startsWith('/')) p = p.substring(1);
      _currentPath = p;
    }
    _refreshFiles();
  }

  Future<void> _refreshFiles() async {
    setState(() => _isLoading = true);
    final list = await _gcs.listFiles(_currentPath);
    if (mounted) {
      setState(() {
        _files = list;
        _isLoading = false;
      });
    }
  }

  void _uploadFile() async {
    final user = _auth.currentUser;
    if (user != null && user.isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Read-Only Permission: Upload disabled.")),
      );
      return;
    }

    final result = await FilePicker.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes != null) {
        String uploadPath = _currentPath;
        if (uploadPath.isNotEmpty && !uploadPath.endsWith('/')) {
          uploadPath += '/';
        }
        uploadPath += file.name;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Uploading ${file.name} to Cloud NAS...")),
        );

        final success = await _gcs.uploadBytes(uploadPath, bytes, "");
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Uploaded ${file.name} successfully!")),
          );
          _refreshFiles();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to upload file.")),
          );
        }
      }
    }
  }

  void _deleteFile(FileItem item) async {
    final user = _auth.currentUser;
    if (user != null && user.isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Read-Only Permission: Delete disabled.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text("Delete File", style: GoogleFonts.outfit(color: const Color(0xFFCDD6F4))),
        content: Text("Are you sure you want to delete '${item.name}'?", style: GoogleFonts.inter(color: const Color(0xFFA6ADC8))),
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
      final success = await _gcs.deleteObject(item.path);
      if (success) {
        _refreshFiles();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Path & Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "📁 /$_currentPath",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFCDD6F4),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF89B4FA)),
                    onPressed: _refreshFiles,
                    tooltip: "Refresh",
                  ),
                  if (user != null && !user.isReadOnly) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _uploadFile,
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text("Upload File", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA6E3A1),
                        foregroundColor: const Color(0xFF11111B),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // File List Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF89B4FA)))
                  : _files.isEmpty
                      ? Center(
                          child: Text(
                            "No files in this folder.",
                            style: GoogleFonts.inter(color: const Color(0xFFA6ADC8)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _files.length,
                          separatorBuilder: (ctx, i) => const Divider(color: Color(0xFF313244), height: 1),
                          itemBuilder: (ctx, i) {
                            final item = _files[i];
                            return ListTile(
                              leading: Icon(
                                item.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                                color: item.isDirectory ? const Color(0xFFF9E2AF) : const Color(0xFF89B4FA),
                              ),
                              title: Text(
                                item.name,
                                style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                item.formattedSize,
                                style: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!user!.isReadOnly)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF38BA8), size: 20),
                                      onPressed: () => _deleteFile(item),
                                      tooltip: "Delete",
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
