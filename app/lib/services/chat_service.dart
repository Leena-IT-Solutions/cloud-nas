import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import 'gcs_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final GCSService _gcs = GCSService();

  String getChatFilename(String user1, String user2) {
    List<String> pair = [user1.toLowerCase(), user2.toLowerCase()]..sort();
    return "${pair[0]}_${pair[1]}.json";
  }

  Future<List<ChatMessage>> fetchChatHistory(String user1, String user2) async {
    final filename = getChatFilename(user1, user2);
    final remotePath = ".sys/chats/$filename";

    try {
      final jsonStr = await _gcs.readTextFile(remotePath);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final data = jsonDecode(jsonStr);
        if (data['messages'] != null) {
          final List list = data['messages'];
          return list.map((m) => ChatMessage.fromJson(m)).toList();
        }
      }
    } catch (e) {
      print("Error fetching chat history: $e");
    }
    return [];
  }

  Future<bool> sendMessage(String sender, String recipient, String text) async {
    if (text.trim().isEmpty) return false;

    final history = await fetchChatHistory(sender, recipient);
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final newMsg = ChatMessage(
      sender: sender,
      recipient: recipient,
      text: text.trim(),
      timestamp: timestamp,
    );

    history.add(newMsg);

    final filename = getChatFilename(sender, recipient);
    final remotePath = ".sys/chats/$filename";
    final jsonStr = JsonEncoder.withIndent('  ').convert({
      'messages': history.map((m) => m.toJson()).toList(),
    });

    return await _gcs.writeTextFile(remotePath, jsonStr);
  }
}
