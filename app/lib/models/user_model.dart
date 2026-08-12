class UserModel {
  final String username;
  final String password;
  final String role; // "Admin" or "User"
  final String folderScope; // "Full Access (All Folders)" or "Specific Folder"
  final String folderPath; // "/" or "/Philip" or "/Sandeep" or "/Leena"
  final String permission; // "Read-Write" or "Read-Only"
  final String createdAt;

  UserModel({
    required this.username,
    required this.password,
    required this.role,
    required this.folderScope,
    required this.folderPath,
    required this.permission,
    required this.createdAt,
  });

  bool get isAdmin => role.toLowerCase() == "admin" || username.toLowerCase() == "admin";
  bool get isReadOnly => permission.toLowerCase() == "read-only";

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      role: json['role'] ?? 'User',
      folderScope: json['folder_scope'] ?? 'Specific Folder',
      folderPath: json['folder_path'] ?? '/',
      permission: json['permission'] ?? 'Read-Write',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'role': role,
      'folder_scope': folderScope,
      'folder_path': folderPath,
      'permission': permission,
      'created_at': createdAt,
    };
  }
}
