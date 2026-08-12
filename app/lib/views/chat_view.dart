import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _auth = AuthService();
  final _chat = ChatService();
  final _msgController = TextEditingController();

  UserModel? _activeContact;
  List<ChatMessage> _messages = [];
  Timer? _pollerTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final contacts = _otherContacts;
    if (contacts.isNotEmpty) {
      _activeContact = contacts.first;
      _loadHistory();
    }
    _pollerTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (_activeContact != null) {
        _loadHistory(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollerTimer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  List<UserModel> get _otherContacts {
    final cur = _auth.currentUser;
    if (cur == null) return [];
    return _auth.usersList.where((u) => u.username.toLowerCase() != cur.username.toLowerCase()).toList();
  }

  void _loadHistory({bool silent = false}) async {
    if (_activeContact == null || _auth.currentUser == null) return;
    if (!silent) setState(() => _isLoading = true);

    final history = await _chat.fetchChatHistory(
      _auth.currentUser!.username,
      _activeContact!.username,
    );

    if (mounted) {
      setState(() {
        _messages = history;
        _isLoading = false;
      });
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _activeContact == null || _auth.currentUser == null) return;

    _msgController.clear();
    final sender = _auth.currentUser!.username;
    final recipient = _activeContact!.username;

    await _chat.sendMessage(sender, recipient, text);
    _loadHistory(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _otherContacts;

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            bool isWide = constraints.maxWidth >= 600;

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    SizedBox(width: 220, child: _buildContactsList(contacts)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildChatThreadWindow()),
                  ],
                ),
              );
            } else {
              if (_activeContact != null && MediaQuery.of(context).size.width < 600) {
                return _buildMobileChatThreadWindow();
              }
              return _buildContactsList(contacts);
            }
          },
        ),
      ),
    );
  }

  Widget _buildContactsList(List<UserModel> contacts) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "👥 CONTACTS",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFA6ADC8),
                letterSpacing: 1,
              ),
            ),
          ),
          const Divider(color: Color(0xFF313244), height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (ctx, i) {
                final u = contacts[i];
                final isSelected = _activeContact?.username.toLowerCase() == u.username.toLowerCase();

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF313244),
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? const Color(0xFFA6E3A1) : const Color(0xFF45475A),
                    child: Text(
                      u.username[0].toUpperCase(),
                      style: GoogleFonts.inter(
                        color: isSelected ? const Color(0xFF11111B) : const Color(0xFFCDD6F4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    u.username,
                    style: GoogleFonts.inter(
                      color: isSelected ? const Color(0xFFA6E3A1) : const Color(0xFFCDD6F4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    u.role,
                    style: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 11),
                  ),
                  onTap: () {
                    setState(() => _activeContact = u);
                    _loadHistory();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileChatThreadWindow() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF1E1E2E),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFCDD6F4)),
                onPressed: () => setState(() => _activeContact = null),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF89B4FA),
                child: Text(
                  _activeContact!.username[0].toUpperCase(),
                  style: GoogleFonts.inter(color: const Color(0xFF11111B), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _activeContact!.username,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFCDD6F4)),
              ),
            ],
          ),
        ),
        Expanded(child: _buildChatThreadWindow()),
      ],
    );
  }

  Widget _buildChatThreadWindow() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      child: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF89B4FA)))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          "No messages yet. Send a message!",
                          style: GoogleFonts.inter(color: const Color(0xFFA6ADC8)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isMe = msg.sender.toLowerCase() == _auth.currentUser?.username.toLowerCase();

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              constraints: const BoxConstraints(maxWidth: 280),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF89B4FA).withValues(alpha: 0.2) : const Color(0xFF313244),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isMe ? const Color(0xFF89B4FA) : const Color(0xFF45475A),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "[${msg.timestamp}] ${isMe ? 'You' : msg.sender}",
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isMe ? const Color(0xFFA6E3A1) : const Color(0xFF89B4FA),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg.text,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFFCDD6F4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Input Bar
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF313244))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF181825),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF89B4FA)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
