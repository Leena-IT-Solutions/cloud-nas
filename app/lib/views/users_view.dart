import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  final _auth = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _folderPathController = TextEditingController(text: "/");

  String _selectedRole = "User";
  final String _selectedScope = "Specific Folder";
  String _selectedPermission = "Read-Write";
  bool _isSaving = false;

  void _addUser() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final folderPath = _folderPathController.text.trim();

    if (username.isEmpty || password.isEmpty || folderPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final newUser = UserModel(
      username: username,
      password: password,
      role: _selectedRole,
      folderScope: _selectedScope,
      folderPath: folderPath.startsWith('/') ? folderPath : '/$folderPath',
      permission: _selectedPermission,
      createdAt: now,
    );

    final success = await _auth.addUser(newUser);
    setState(() => _isSaving = false);

    if (success && mounted) {
      _usernameController.clear();
      _passwordController.clear();
      _folderPathController.text = "/";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User '$username' saved successfully!")),
      );
    }
  }

  void _deleteUser(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text("Delete User", style: GoogleFonts.outfit(color: const Color(0xFFCDD6F4))),
        content: Text("Are you sure you want to delete user '$username'?", style: GoogleFonts.inter(color: const Color(0xFFA6ADC8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.inter(color: const Color(0xFFA6ADC8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF38BA8)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: GoogleFonts.inter(color: const Color(0xFF11111B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.deleteUser(username);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add User Form Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "➕ ADD NEW USER",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFCDD6F4),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _usernameController,
                      style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 14),
                      decoration: _inputDecoration("Username"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 14),
                      decoration: _inputDecoration("Password"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _folderPathController,
                      style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 14),
                      decoration: _inputDecoration("Folder Path (e.g. /Philip)"),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            dropdownColor: const Color(0xFF181825),
                            style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 13),
                            decoration: _inputDecoration("Role"),
                            items: const [
                              DropdownMenuItem(value: "User", child: Text("User")),
                              DropdownMenuItem(value: "Admin", child: Text("Admin")),
                            ],
                            onChanged: (v) => setState(() => _selectedRole = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedPermission,
                            dropdownColor: const Color(0xFF181825),
                            style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 13),
                            decoration: _inputDecoration("Permission"),
                            items: const [
                              DropdownMenuItem(value: "Read-Write", child: Text("Read-Write")),
                              DropdownMenuItem(value: "Read-Only", child: Text("Read-Only")),
                            ],
                            onChanged: (v) => setState(() => _selectedPermission = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _addUser,
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: Text("Save User", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF89B4FA),
                          foregroundColor: const Color(0xFF11111B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Users List Table
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _auth.usersList.length,
                  separatorBuilder: (ctx, i) => const Divider(color: Color(0xFF313244), height: 1),
                  itemBuilder: (ctx, i) {
                    final u = _auth.usersList[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: u.isAdmin ? const Color(0xFFCBA6F7) : const Color(0xFF89B4FA),
                        child: Text(
                          u.username[0].toUpperCase(),
                          style: GoogleFonts.inter(color: const Color(0xFF11111B), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        "${u.username} (${u.role})",
                        style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Path: ${u.folderPath} • ${u.permission}",
                        style: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF38BA8)),
                        onPressed: () => _deleteUser(u.username),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF181825),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF313244)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF89B4FA)),
      ),
    );
  }
}
