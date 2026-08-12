import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyBucketName = "gcs_bucket_name";
  static const String _keyBucketList = "gcs_bucket_list";
  static const String _keyCustomKeyJson = "gcs_custom_key_json";
  static const String _keySavedUsername = "saved_username";
  static const String _keySavedPassword = "saved_password";
  static const String _keyUserSession = "active_user_session";

  // --- GCS SETTINGS PERSISTENCE ---

  Future<void> saveGcsSettings({required String bucketName, Map<String, dynamic>? keyJson}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBucketName, bucketName.trim());
    
    // Maintain list of saved buckets
    List<String> list = prefs.getStringList(_keyBucketList) ?? [];
    if (bucketName.trim().isNotEmpty && !list.contains(bucketName.trim())) {
      list.add(bucketName.trim());
      await prefs.setStringList(_keyBucketList, list);
    }

    if (keyJson != null) {
      await prefs.setString(_keyCustomKeyJson, jsonEncode(keyJson));
    }
  }

  Future<String?> getGcsBucketName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBucketName);
  }

  Future<List<String>> getGcsBucketList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyBucketList) ?? [];
  }

  Future<Map<String, dynamic>?> getGcsCustomKeyJson() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyCustomKeyJson);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return jsonDecode(jsonStr);
      } catch (e) {
        print("Error decoding saved GCS key JSON: $e");
      }
    }
    return null;
  }

  // --- USER CREDENTIALS & SESSION PERSISTENCE ---

  Future<void> saveUserCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedUsername, username);
    await prefs.setString(_keySavedPassword, password);
  }

  Future<Map<String, String>?> getUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString(_keySavedUsername);
    final p = prefs.getString(_keySavedPassword);
    if (u != null && p != null && u.isNotEmpty && p.isNotEmpty) {
      return {'username': u, 'password': p};
    }
    return null;
  }

  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(user.toJson());
    await prefs.setString(_keyUserSession, jsonStr);
  }

  Future<UserModel?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyUserSession);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final data = jsonDecode(jsonStr);
        return UserModel.fromJson(data);
      } catch (e) {
        print("Error decoding saved user session: $e");
      }
    }
    return null;
  }

  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserSession);
    await prefs.remove(_keySavedUsername);
    await prefs.remove(_keySavedPassword);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
