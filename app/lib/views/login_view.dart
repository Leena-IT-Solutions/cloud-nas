import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginView({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _auth = AuthService();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _auth.loadUsersDatabase();
  }

  void _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final username = _userController.text.trim();
    final password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Please enter both username and password.";
        _isLoading = false;
      });
      return;
    }

    final user = _auth.login(username, password);
    if (user != null) {
      widget.onLoginSuccess();
    } else {
      setState(() {
        _errorMessage = "Invalid username or password.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext me) {
    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF313244), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_queue_rounded,
                  size: 64,
                  color: Color(0xFF89B4FA),
                ),
                const SizedBox(height: 16),
                Text(
                  "CLOUD NAS",
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFCDD6F4),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Secure Multi-User Cloud NAS Storage",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFA6ADC8),
                  ),
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF38BA8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF38BA8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFF38BA8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(color: const Color(0xFFF38BA8), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _userController,
                  style: GoogleFonts.inter(color: const Color(0xFFCDD6F4)),
                  decoration: InputDecoration(
                    labelText: "Username",
                    labelStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8)),
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF89B4FA)),
                    filled: true,
                    fillColor: const Color(0xFF181825),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF313244)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF89B4FA), width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  style: GoogleFonts.inter(color: const Color(0xFFCDD6F4)),
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8)),
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF89B4FA)),
                    filled: true,
                    fillColor: const Color(0xFF181825),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF313244)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF89B4FA), width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF89B4FA),
                      foregroundColor: const Color(0xFF11111B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11111B)),
                          )
                        : Text(
                            "LOGIN TO CLOUD NAS",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
