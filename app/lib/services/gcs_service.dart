import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../models/file_item.dart';
import 'storage_service.dart';

class GCSService {
  static final GCSService _instance = GCSService._internal();
  factory GCSService() => _instance;
  GCSService._internal();

  final StorageService _storage = StorageService();

  String bucketName = "";
  Map<String, dynamic>? customKeyJson;
  String? _accessToken;
  DateTime? _tokenExpiry;
  bool isConnected = false;

  Future<bool> restoreSavedSettings() async {
    final activeDisk = await _storage.getActiveDiskName();
    if (activeDisk != null && activeDisk.isNotEmpty) {
      final profile = await _storage.getDiskProfile(activeDisk);
      if (profile != null && profile['key'] != null) {
        bucketName = activeDisk;
        customKeyJson = profile['key'];
        return await testConnection();
      }
    }
    return false;
  }

  Future<bool> switchDisk(String targetBucketName) async {
    final profile = await _storage.getDiskProfile(targetBucketName);
    if (profile != null && profile['key'] != null) {
      bucketName = targetBucketName;
      customKeyJson = profile['key'];
      _accessToken = null;
      _tokenExpiry = null;
      isConnected = false;
      await _storage.setActiveDiskName(targetBucketName);
      return await testConnection();
    }
    return false;
  }

  void configure({required String bucket, Map<String, dynamic>? keyJson}) {
    bucketName = bucket.trim();
    if (keyJson != null) {
      customKeyJson = keyJson;
    }
    _accessToken = null;
    _tokenExpiry = null;
    isConnected = false;
    if (bucketName.isNotEmpty && customKeyJson != null) {
      _storage.saveDiskProfile(bucketName: bucketName, keyJson: customKeyJson!);
    }
  }

  Future<String?> getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    if (customKeyJson == null) return null;

    final clientEmail = customKeyJson!['client_email'];
    final privateKeyPem = customKeyJson!['private_key'];
    final tokenUri = customKeyJson!['token_uri'] ?? 'https://oauth2.googleapis.com/token';

    if (clientEmail == null || privateKeyPem == null) return null;

    final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = iat + 3600;

    final jwt = JWT(
      {
        'iss': clientEmail,
        'scope': 'https://www.googleapis.com/auth/devstorage.full_control',
        'aud': tokenUri,
        'exp': exp,
        'iat': iat,
      },
    );

    final key = RSAPrivateKey(privateKeyPem);
    final token = jwt.sign(key, algorithm: JWTAlgorithm.RS256);

    try {
      final response = await http.post(
        Uri.parse(tokenUri),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        isConnected = true;
        return _accessToken;
      } else {
        print("Failed to fetch access token: ${response.body}");
      }
    } catch (e) {
      print("OAuth Token Exception: $e");
    }
    return null;
  }

  Future<bool> testConnection() async {
    if (bucketName.isEmpty || customKeyJson == null) return false;
    final token = await getAccessToken();
    if (token == null) return false;

    final url = Uri.parse(
      'https://storage.googleapis.com/storage/v1/b/$bucketName/o?maxResults=1'
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        isConnected = true;
        return true;
      }
    } catch (e) {
      print("GCS Test Connection Error: $e");
    }
    return false;
  }

  Future<List<FileItem>> listFiles(String prefix) async {
    final token = await getAccessToken();
    if (token == null) return [];

    String cleanPrefix = prefix.startsWith('/') ? prefix.substring(1) : prefix;
    if (cleanPrefix.isNotEmpty && !cleanPrefix.endsWith('/')) {
      cleanPrefix += '/';
    }

    final url = Uri.parse(
      'https://storage.googleapis.com/storage/v1/b/$bucketName/o?prefix=${Uri.encodeComponent(cleanPrefix)}&delimiter=/&gcs-bucket-policy-only=true'
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<FileItem> items = [];

        if (data['prefixes'] != null) {
          for (var p in data['prefixes']) {
            String folderPath = p.toString();
            String name = folderPath;
            if (name.endsWith('/')) name = name.substring(0, name.length - 1);
            name = name.split('/').last;

            if (name.isNotEmpty && !name.startsWith('.')) {
              items.add(FileItem(
                name: name,
                path: folderPath,
                size: 0,
                updated: DateTime.now(),
                isDirectory: true,
              ));
            }
          }
        }

        if (data['items'] != null) {
          for (var item in data['items']) {
            String path = item['name'] ?? '';
            if (path == cleanPrefix || path.endsWith('.keep') || path.contains('/.sys/')) {
              continue;
            }

            String name = path.split('/').last;
            if (name.isNotEmpty && !name.startsWith('.')) {
              int size = int.tryParse(item['size']?.toString() ?? '0') ?? 0;
              DateTime updated = DateTime.tryParse(item['updated']?.toString() ?? '') ?? DateTime.now();

              items.add(FileItem(
                name: name,
                path: path,
                size: size,
                updated: updated,
                isDirectory: false,
              ));
            }
          }
        }

        return items;
      }
    } catch (e) {
      print("GCS List Error: $e");
    }
    return [];
  }

  Future<String?> readTextFile(String remotePath) async {
    final token = await getAccessToken();
    if (token == null) return null;

    final url = Uri.parse(
      'https://storage.googleapis.com/storage/v1/b/$bucketName/o/${Uri.encodeComponent(remotePath)}?alt=media'
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      print("GCS Read Error: $e");
    }
    return null;
  }

  Future<bool> writeTextFile(String remotePath, String content) async {
    final token = await getAccessToken();
    if (token == null) return false;

    final url = Uri.parse(
      'https://storage.googleapis.com/upload/storage/v1/b/$bucketName/o?uploadType=media&name=${Uri.encodeComponent(remotePath)}'
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: content,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("GCS Write Error: $e");
    }
    return false;
  }

  Future<bool> uploadBytes(String remotePath, Uint8List bytes, String mimeType) async {
    final token = await getAccessToken();
    if (token == null) return false;

    final url = Uri.parse(
      'https://storage.googleapis.com/upload/storage/v1/b/$bucketName/o?uploadType=media&name=${Uri.encodeComponent(remotePath)}'
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': mimeType.isNotEmpty ? mimeType : 'application/octet-stream',
        },
        body: bytes,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("GCS Upload Error: $e");
    }
    return false;
  }

  Future<Uint8List?> downloadBytes(String remotePath) async {
    final token = await getAccessToken();
    if (token == null) return null;

    final url = Uri.parse(
      'https://storage.googleapis.com/storage/v1/b/$bucketName/o/${Uri.encodeComponent(remotePath)}?alt=media'
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print("GCS Download Error: $e");
    }
    return null;
  }

  Future<bool> deleteObject(String remotePath) async {
    final token = await getAccessToken();
    if (token == null) return false;

    final url = Uri.parse(
      'https://storage.googleapis.com/storage/v1/b/$bucketName/o/${Uri.encodeComponent(remotePath)}'
    );

    try {
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print("GCS Delete Error: $e");
    }
    return false;
  }
}
