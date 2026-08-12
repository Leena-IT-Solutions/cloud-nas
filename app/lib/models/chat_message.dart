class ChatMessage {
  final String sender;
  final String recipient;
  final String text;
  final String timestamp;

  ChatMessage({
    required this.sender,
    required this.recipient,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] ?? '',
      recipient: json['recipient'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'recipient': recipient,
      'text': text,
      'timestamp': timestamp,
    };
  }
}
