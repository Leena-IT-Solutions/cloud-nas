class FileItem {
  final String name;
  final String path;
  final int size;
  final DateTime updated;
  final bool isDirectory;

  FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.updated,
    this.isDirectory = false,
  });

  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
