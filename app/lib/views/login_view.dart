import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import '../services/gcs_service.dart';
import '../services/storage_service.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginView({super.key, required this.onLoginSuccess});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _bucketController = TextEditingController();
  final _jsonTextController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  final _auth = AuthService();
  final _gcs = GCSService();
  final _storage = StorageService();

  bool _isGcsConnected = false;
  bool _isTestingGcs = false;
  String? _gcsFileName;
  Map<String, dynamic>? _customKeyJson;
  List<String> _savedDisks = [];

  String? _errorMessage;
  bool _isLoading = false;
  bool _showJsonTextInput = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  void _loadSavedSettings() async {
    final activeDisk = await _storage.getActiveDiskName();
    final savedKey = await _storage.getGcsCustomKeyJson();
    final diskNames = await _storage.getSavedDiskNames();
    final savedCreds = await _storage.getUserCredentials();

    if (savedCreds != null) {
      _userController.text = savedCreds['username'] ?? '';
      _passController.text = savedCreds['password'] ?? '';
    }

    if (activeDisk != null && activeDisk.isNotEmpty) {
      _bucketController.text = activeDisk;
    }

    setState(() {
      _savedDisks = diskNames;
      if (savedKey != null) {
        _customKeyJson = savedKey;
        _gcsFileName = "Stored Key (${savedKey['client_email'] ?? 'Service Account'})";
      }
    });

    if (activeDisk != null && activeDisk.isNotEmpty && savedKey != null) {
      _testGcsConnection(silent: true);
    }
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
              _errorMessage = null;
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

  void _parsePastedJson() {
    final text = _jsonTextController.text.trim();
    if (text.isEmpty) return;

    try {
      final parsed = jsonDecode(text);
      if (parsed['type'] == 'service_account' || parsed['private_key'] != null) {
        setState(() {
          _customKeyJson = parsed;
          _gcsFileName = "Pasted Key (${parsed['client_email'] ?? 'Service Account'})";
          _showJsonTextInput = false;
          _errorMessage = null;
        });
        _testGcsConnection();
      } else {
        setState(() {
          _errorMessage = "Pasted text is not a valid GCP Service Account Key.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Invalid JSON syntax.";
      });
    }
  }

  void _testGcsConnection({bool silent = false}) async {
    final bucket = _bucketController.text.trim();
    if (bucket.isEmpty) {
      if (!silent) {
        setState(() => _errorMessage = "Please enter a GCS Bucket / Disk Name.");
      }
      return;
    }

    if (_customKeyJson == null) {
      if (!silent) {
        setState(() => _errorMessage = "Please add or import your GCP Service Account Key JSON.");
      }
      return;
    }

    if (!silent) {
      setState(() {
        _isTestingGcs = true;
        _errorMessage = null;
      });
    }

    _gcs.configure(
      bucket: bucket,
      keyJson: _customKeyJson,
    );

    final success = await _gcs.testConnection();

    if (mounted) {
      setState(() {
        _isGcsConnected = success;
        _isTestingGcs = false;
        if (!success && !silent) {
          _errorMessage = "Failed to connect to GCS bucket '$bucket'. Check bucket name & key.";
        }
      });

      if (success) {
        final updatedDisks = await _storage.getSavedDiskNames();
        setState(() {
          _savedDisks = updatedDisks;
        });
        await _auth.loadUsersDatabase();
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
      await _storage.saveUserCredentials(username, password);
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
              constraints: const BoxConstraints(maxWidth: 440),
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
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "CLOUD NAS",
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFCDD6F4),
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "Multi-User Cloud Storage",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFA6ADC8),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  // STEP 1: CONFIGURE GCS BUCKET & KEY
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
                                "CONNECT STORAGE DISK",
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

                          if (_savedDisks.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _savedDisks.contains(_bucketController.text) ? _bucketController.text : null,
                              dropdownColor: const Color(0xFF181825),
                              style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 13),
                              decoration: _inputDecoration("Saved Disks / Buckets"),
                              items: _savedDisks.map((disk) {
                                return DropdownMenuItem(value: disk, child: Text("💾 $disk"));
                              }).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  _bucketController.text = val;
                                  final profile = await _storage.getDiskProfile(val);
                                  if (profile != null && profile['key'] != null) {
                                    setState(() {
                                      _customKeyJson = profile['key'];
                                      _gcsFileName = "Stored Key (${profile['key']['client_email'] ?? 'Service Account'})";
                                    });
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                          ],

                          TextField(
                            controller: _bucketController,
                            style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 13),
                            decoration: _inputDecoration("GCS Bucket / Disk Name"),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            "GCP SERVICE ACCOUNT KEY",
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFA6ADC8), letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _customKeyJson != null ? const Color(0xFFA6E3A1) : const Color(0xFFF38BA8)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _customKeyJson != null ? Icons.key_rounded : Icons.key_off_rounded,
                                  color: _customKeyJson != null ? const Color(0xFFA6E3A1) : const Color(0xFFF38BA8),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _gcsFileName ?? "No GCP Key Configured (Empty)",
                                    style: GoogleFonts.inter(
                                      color: _customKeyJson != null ? const Color(0xFFA6E3A1) : const Color(0xFFF38BA8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickJsonKey,
                                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                                  label: Text("Select .json", style: GoogleFonts.inter(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF89B4FA),
                                    side: const BorderSide(color: Color(0xFF313244)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _showJsonTextInput = !_showJsonTextInput),
                                  icon: const Icon(Icons.code_rounded, size: 16),
                                  label: Text("Paste JSON", style: GoogleFonts.inter(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF89B4FA),
                                    side: const BorderSide(color: Color(0xFF313244)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_showJsonTextInput) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _jsonTextController,
                              maxLines: 4,
                              style: GoogleFonts.inter(color: const Color(0xFFCDD6F4), fontSize: 11),
                              decoration: _inputDecoration("Paste Service Account JSON text here..."),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _parsePastedJson,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF313244),
                                  foregroundColor: const Color(0xFFCDD6F4),
                                ),
                                child: Text("Apply Pasted JSON", style: GoogleFonts.inter(fontSize: 12)),
                              ),
                            ),
                          ],
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
                                _isTestingGcs ? "Connecting..." : "CONNECT & SAVE DISK",
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

                  // STEP 2: LOGIN FORM ONCE DISK IS CONNECTED
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
                              "Change Disk",
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
                                  fontSize: 12,
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: const Color(0xFFA6ADC8), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF1E1E2E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
