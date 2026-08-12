import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyActiveBucket = "gcs_active_bucket";
  static const String _keyDiskProfilesMap = "gcs_disk_profiles_map";
  static const String _keySavedUsername = "saved_username";
  static const String _keySavedPassword = "saved_password";
  static const String _keyUserSession = "active_user_session";

  // --- DISKS / BUCKETS MULTI-PROFILE PERSISTENCE ---

  Future<void> saveDiskProfile({required String bucketName, required Map<String, dynamic> keyJson}) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanBucket = bucketName.trim();
    if (cleanBucket.isEmpty) return;

    final mapStr = prefs.getString(_keyDiskProfilesMap);
    Map<String, dynamic> profiles = {};
    if (mapStr != null && mapStr.isNotEmpty) {
      try {
        profiles = jsonDecode(mapStr);
      } catch (e) {
        print("Error decoding disk profiles map: $e");
      }
    }

    profiles[cleanBucket] = {
      'bucket': cleanBucket,
      'key': keyJson,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(_keyDiskProfilesMap, jsonEncode(profiles));
    await prefs.setString(_keyActiveBucket, cleanBucket);
  }

  Future<List<String>> getSavedDiskNames() async {
    final prefs = await SharedPreferences.getInstance();
    final mapStr = prefs.getString(_keyDiskProfilesMap);
    if (mapStr != null && mapStr.isNotEmpty) {
      try {
        final Map<String, dynamic> profiles = jsonDecode(mapStr);
        return profiles.keys.toList();
      } catch (e) {
        print("Error decoding saved disk names: $e");
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getDiskProfile(String bucketName) async {
    final prefs = await SharedPreferences.getInstance();
    final mapStr = prefs.getString(_keyDiskProfilesMap);
    if (mapStr != null && mapStr.isNotEmpty) {
      try {
        final Map<String, dynamic> profiles = jsonDecode(mapStr);
        if (profiles.containsKey(bucketName)) {
          return profiles[bucketName];
        }
      } catch (e) {
        print("Error reading disk profile for $bucketName: $e");
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getGcsCustomKeyJson() async {
    final activeDisk = await getActiveDiskName();
    if (activeDisk != null) {
      final profile = await getDiskProfile(activeDisk);
      if (profile != null && profile['key'] != null) {
        return profile['key'];
      }
    }
    return null;
  }

  Future<String?> getActiveDiskName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveBucket);
  }

  Future<void> setActiveDiskName(String bucketName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveBucket, bucketName.trim());
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
