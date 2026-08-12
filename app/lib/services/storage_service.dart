import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyBucketName = "gcs_bucket_name";
  static const String _keyCustomKeyJson = "gcs_custom_key_json";
  static const String _keyUserSession = "active_user_session";

  // --- GCS SETTINGS ---

  Future<void> saveGcsSettings({required String bucketName, Map<String, dynamic>? keyJson}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBucketName, bucketName.trim());
    if (keyJson != null) {
      await prefs.setString(_keyCustomKeyJson, jsonEncode(keyJson));
    } else {
      await prefs.remove(_keyCustomKeyJson);
    }
  }

  Future<String> getGcsBucketName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBucketName) ?? "sv-school";
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

  // --- USER SESSION PERSISTENCE ---

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
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
