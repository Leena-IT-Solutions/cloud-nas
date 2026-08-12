import 'dart:convert';
import '../models/user_model.dart';
import 'gcs_service.dart';
import 'storage_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GCSService _gcs = GCSService();
  final StorageService _storage = StorageService();

  UserModel? currentUser;
  List<UserModel> usersList = [];
  bool isLoading = false;

  static final List<UserModel> defaultUsers = [
    UserModel(
      username: "admin",
      password: "password",
      role: "Admin",
      folderScope: "Full Access (All Folders)",
      folderPath: "/",
      permission: "Read-Write",
      createdAt: "2026-08-12 04:28",
    ),
    UserModel(
      username: "philip",
      password: "password",
      role: "User",
      folderScope: "Specific Folder",
      folderPath: "/Philip",
      permission: "Read-Write",
      createdAt: "2026-08-12 04:28",
    ),
    UserModel(
      username: "sandeep",
      password: "password",
      role: "User",
      folderScope: "Specific Folder",
      folderPath: "/Sandeep",
      permission: "Read-Write",
      createdAt: "2026-08-12 04:34",
    ),
    UserModel(
      username: "leena",
      password: "password",
      role: "User",
      folderScope: "Specific Folder",
      folderPath: "/Leena",
      permission: "Read-Only",
      createdAt: "2026-08-12 04:35",
    ),
  ];

  Future<UserModel?> restoreSavedSession() async {
    final savedUser = await _storage.getUserSession();
    if (savedUser != null) {
      currentUser = savedUser;
      return savedUser;
    }
    return null;
  }

  Future<void> loadUsersDatabase() async {
    isLoading = true;
    try {
      final jsonStr = await _gcs.readTextFile(".sys/users_permissions.json");
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final data = jsonDecode(jsonStr);
        if (data['users'] != null) {
          final List list = data['users'];
          usersList = list.map((u) => UserModel.fromJson(u)).toList();
          isLoading = false;
          return;
        }
      }
    } catch (e) {
      print("Could not load remote users database: $e");
    }

    usersList = List.from(defaultUsers);
    await saveUsersDatabase();
    isLoading = false;
  }

  Future<bool> saveUsersDatabase() async {
    final data = {
      'users': usersList.map((u) => u.toJson()).toList(),
    };
    final jsonStr = JsonEncoder.withIndent('  ').convert(data);
    return await _gcs.writeTextFile(".sys/users_permissions.json", jsonStr);
  }

  Future<UserModel?> login(String username, String password) async {
    String cleanUser = username.trim().toLowerCase();
    String cleanPass = password.trim();

    for (var u in usersList) {
      if (u.username.toLowerCase() == cleanUser && u.password == cleanPass) {
        currentUser = u;
        await _storage.saveUserSession(u);
        return u;
      }
    }
    return null;
  }

  Future<void> logout() async {
    currentUser = null;
    await _storage.clearUserSession();
  }

  Future<bool> addUser(UserModel newUser) async {
    usersList.removeWhere((u) => u.username.toLowerCase() == newUser.username.toLowerCase());
    usersList.add(newUser);
    return await saveUsersDatabase();
  }

  Future<bool> deleteUser(String username) async {
    usersList.removeWhere((u) => u.username.toLowerCase() == username.toLowerCase());
    return await saveUsersDatabase();
  }
}
