import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/file_item.dart';
import '../services/auth_service.dart';
import '../services/gcs_service.dart';

class ExplorerView extends StatefulWidget {
  const ExplorerView({super.key});

  @override
  State<ExplorerView> createState() => _ExplorerViewState();
}

class _ExplorerViewState extends State<ExplorerView> {
  final _auth = AuthService();
  final _gcs = GCSService();

  String _currentPath = "";
  List<FileItem> _files = [];
  List<FileItem> _filteredFiles = [];
  bool _isLoading = true;
  bool _isGridView = false;
  final _searchController = TextEditingController();

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
        _filterFiles(_searchController.text);
        _isLoading = false;
      });
    }
  }

  void _filterFiles(String query) {
    if (query.trim().isEmpty) {
      _filteredFiles = List.from(_files);
    } else {
      _filteredFiles = _files.where((f) => f.name.toLowerCase().contains(query.toLowerCase())).toList();
    }
  }

  void _openFolder(FileItem item) {
    if (item.isDirectory) {
      setState(() {
        _currentPath = item.path;
      });
      _refreshFiles();
    }
  }

  void _navigateUp() {
    if (_currentPath.isEmpty) return;
    final user = _auth.currentUser;
    if (user != null && !user.isAdmin) {
      String rootPath = user.folderPath.startsWith('/') ? user.folderPath.substring(1) : user.folderPath;
      if (_currentPath == rootPath || _currentPath == "$rootPath/") return;
    }

    List<String> parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) parts.removeLast();
    setState(() {
      _currentPath = parts.isEmpty ? "" : "${parts.join('/')}/";
    });
    _refreshFiles();
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Uploading ${file.name} to Cloud NAS...")),
          );
        }

        final success = await _gcs.uploadBytes(uploadPath, bytes, "");
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Uploaded ${file.name} successfully!")),
          );
          _refreshFiles();
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
      if (success) _refreshFiles();
    }
  }

  void _showFileDetails(FileItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.isDirectory ? Icons.folder_rounded : _getFileIcon(item.name),
                  size: 36,
                  color: item.isDirectory ? const Color(0xFFF9E2AF) : const Color(0xFF89B4FA),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFCDD6F4)),
                      ),
                      Text(
                        item.formattedSize,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFA6ADC8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF89B4FA)),
              title: Text("Path: /${item.path}", style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 13)),
            ),
            if (!_auth.currentUser!.isReadOnly)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF38BA8)),
                title: Text("Delete File", style: GoogleFonts.inter(color: const Color(0xFFF38BA8), fontSize: 14, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteFile(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext)) return Icons.image_rounded;
    if (['mp4', 'mov', 'mkv', 'avi'].contains(ext)) return Icons.video_library_rounded;
    if (['mp3', 'wav', 'aac', 'flac'].contains(ext)) return Icons.audio_file_rounded;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['zip', 'rar', 'tar', 'gz', '7z'].contains(ext)) return Icons.folder_zip_rounded;
    if (['txt', 'md', 'json', 'xml', 'html', 'py', 'dart'].contains(ext)) return Icons.code_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & View Mode Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1E1E2E),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.inter(color: const Color(0xFFCDD6F4)),
                          decoration: InputDecoration(
                            hintText: "Search files in /$_currentPath...",
                            hintStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF89B4FA)),
                            filled: true,
                            fillColor: const Color(0xFF181825),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => setState(() => _filterFiles(val)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, color: const Color(0xFF89B4FA)),
                        onPressed: () => setState(() => _isGridView = !_isGridView),
                        tooltip: _isGridView ? "List View" : "Grid View",
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF89B4FA)),
                        onPressed: _refreshFiles,
                        tooltip: "Refresh",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Breadcrumbs Bar
                  Row(
                    children: [
                      if (_currentPath.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFCDD6F4), size: 20),
                          onPressed: _navigateUp,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            "📂 /$_currentPath",
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFCDD6F4)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Files List / Grid View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF89B4FA)))
                  : _filteredFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 64, color: const Color(0xFFA6ADC8).withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                "Folder is empty",
                                style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFFA6ADC8)),
                              ),
                            ],
                          ),
                        )
                      : _isGridView
                          ? GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: _filteredFiles.length,
                              itemBuilder: (ctx, i) {
                                final item = _filteredFiles[i];
                                return InkWell(
                                  onTap: () => item.isDirectory ? _openFolder(item) : _showFileDetails(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E2E),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF313244)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          item.isDirectory ? Icons.folder_rounded : _getFileIcon(item.name),
                                          size: 40,
                                          color: item.isDirectory ? const Color(0xFFF9E2AF) : const Color(0xFF89B4FA),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFCDD6F4)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.formattedSize,
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFA6ADC8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _filteredFiles.length,
                              separatorBuilder: (ctx, i) => const Divider(color: Color(0xFF313244), height: 1),
                              itemBuilder: (ctx, i) {
                                final item = _filteredFiles[i];
                                return ListTile(
                                  onTap: () => item.isDirectory ? _openFolder(item) : _showFileDetails(item),
                                  leading: CircleAvatar(
                                    backgroundColor: item.isDirectory
                                        ? const Color(0xFFF9E2AF).withValues(alpha: 0.15)
                                        : const Color(0xFF89B4FA).withValues(alpha: 0.15),
                                    child: Icon(
                                      item.isDirectory ? Icons.folder_rounded : _getFileIcon(item.name),
                                      color: item.isDirectory ? const Color(0xFFF9E2AF) : const Color(0xFF89B4FA),
                                    ),
                                  ),
                                  title: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    item.formattedSize,
                                    style: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFA6ADC8)),
                                    onPressed: () => _showFileDetails(item),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: user != null && !user.isReadOnly
          ? FloatingActionButton.extended(
              onPressed: _uploadFile,
              backgroundColor: const Color(0xFF89B4FA),
              foregroundColor: const Color(0xFF11111B),
              icon: const Icon(Icons.upload_file_rounded),
              label: Text("Upload File", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
