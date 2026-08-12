import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import '../services/gcs_service.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginView({super.key, required this.onLoginSuccess});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _bucketController = TextEditingController(text: "sv-school");
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  final _auth = AuthService();
  final _gcs = GCSService();

  bool _isGcsConnected = false;
  bool _isTestingGcs = false;
  String? _gcsFileName;
  Map<String, dynamic>? _customKeyJson;

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-test default GCS connection on startup
    _testGcsConnection(silent: true);
  }

  Future<void> _pickJsonKey() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes != null) {
        try {
          final jsonStr = utf8.decode(bytes);
          final parsed = jsonDecode(jsonStr);

          if (parsed['type'] == 'service_account' || parsed['private_key'] != null) {
            setState(() {
              _customKeyJson = parsed;
              _gcsFileName = file.name;
              _isGcsConnected = false;
            });
            _testGcsConnection();
          } else {
            setState(() {
              _errorMessage = "Selected file is not a valid GCP Service Account Key.";
            });
          }
        } catch (e) {
          setState(() {
            _errorMessage = "Invalid JSON file format.";
          });
        }
      }
    }
  }

  void _testGcsConnection({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isTestingGcs = true;
        _errorMessage = null;
      });
    }

    _gcs.configure(
      bucket: _bucketController.text,
      keyJson: _customKeyJson,
    );

    final success = await _gcs.testConnection();

    if (mounted) {
      setState(() {
        _isGcsConnected = success;
        _isTestingGcs = false;
        if (!success && !silent) {
          _errorMessage = "Failed to connect to GCS bucket '${_bucketController.text}'. Check bucket name and key.";
        }
      });
      if (success) {
        _auth.loadUsersDatabase();
      }
    }
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

    final user = await _auth.login(username, password);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF313244), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/app_logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "LITS IN THE CLOUD",
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFCDD6F4),
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "Cloud NAS Storage System",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFA6ADC8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF38BA8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF38BA8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFF38BA8), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(color: const Color(0xFFF38BA8), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // STEP 1: GCS CONNECTION SETUP CARD
                  if (!_isGcsConnected) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181825),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF313244)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud_sync_rounded, color: Color(0xFFF9E2AF), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "CONNECT GOOGLE CLOUD",
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFCDD6F4),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _bucketController,
                            style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 13),
                            decoration: InputDecoration(
                              labelText: "GCS Bucket Name",
                              labelStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 12),
                              prefixIcon: const Icon(Icons.folder_special_rounded, color: Color(0xFF89B4FA), size: 18),
                              filled: true,
                              fillColor: const Color(0xFF1E1E2E),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _pickJsonKey,
                            icon: const Icon(Icons.key_rounded, size: 16),
                            label: Text(
                              _gcsFileName != null ? "Key: $_gcsFileName" : "Use Embedded GCP Key (Or Import JSON)",
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF89B4FA),
                              side: const BorderSide(color: Color(0xFF313244)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _isTestingGcs ? null : () => _testGcsConnection(),
                              icon: _isTestingGcs
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11111B)))
                                  : const Icon(Icons.power_settings_new_rounded, size: 18),
                              label: Text(
                                _isTestingGcs ? "Connecting..." : "CONNECT TO STORAGE",
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF9E2AF),
                                foregroundColor: const Color(0xFF11111B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // STEP 2: LOGIN FORM ONCE GCS IS CONNECTED
                  if (_isGcsConnected) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA6E3A1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA6E3A1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFFA6E3A1), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "Connected: ${_bucketController.text}",
                                style: GoogleFonts.inter(color: const Color(0xFFA6E3A1), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => setState(() => _isGcsConnected = false),
                            child: Text(
                              "Change",
                              style: GoogleFonts.inter(color: const Color(0xFF89B4FA), fontSize: 12, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userController,
                      style: GoogleFonts.inter(color: const Color(0xFFCDD6F4)),
                      decoration: InputDecoration(
                        labelText: "Username",
                        labelStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8)),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF89B4FA)),
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
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      style: GoogleFonts.inter(color: const Color(0xFFCDD6F4)),
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8)),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF89B4FA)),
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
                    const SizedBox(height: 20),
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
                                  fontSize: 13,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
