// ignore_for_file: unused_import, unused_local_variable

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdam_app/register_page.dart';
import 'package:pdam_app/temuan_kebocoran_page.dart';
import 'package:pdam_app/home_pelanggan_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _trackCodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _selectedUserType;
  List<String> _userTypes = ['pelanggan', 'petugas'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _trackCodeController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _trackReportFromLogin() {
    final code = _trackCodeController.text.trim();
    if (code.isEmpty) {
      _showSnackbar('Masukkan kode tracking terlebih dahulu.');
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      '/tracking_page',
      arguments: code,
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _selectedUserType == null) {
      if (_selectedUserType == null) {
        _showSnackbar('Pilih jenis pengguna terlebih dahulu.');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.loginUser(
        email: _emailController.text,
        password: _passwordController.text,
        userType: _selectedUserType!,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String token = responseData['token'];

        await _apiService.saveToken(token);
        _showSnackbar('Login berhasil!', isError: false);

        if (_selectedUserType == 'pelanggan') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePelangganPage()),
          );
        } else if (_selectedUserType == 'petugas') {
          Navigator.pushReplacementNamed(context, '/home_petugas');
        }
      } else if (response.statusCode == 422) {
        final errors = jsonDecode(response.body)['errors'];
        String errorMessage = 'Login gagal:';
        errors.forEach((field, messages) {
          errorMessage += '\n- ${messages.join(", ")}';
        });
        _showSnackbar(errorMessage);
      } else {
        final responseData = jsonDecode(response.body);
        String errorMessage =
            responseData['message'] ?? 'Login gagal. Silakan coba lagi.';
        _showSnackbar('Login gagal: $errorMessage');
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan saat login: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 40),
                child: AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'Selamat Datang di PDAM App',
                      textStyle: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                      speed: const Duration(milliseconds: 100),
                    ),
                  ],
                  isRepeatingAnimation: false,
                ),
              ),
              const SizedBox(height: 20),
              _buildLoginCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                decoration: _inputDecoration("Login Sebagai", Ionicons.person),
                value: _selectedUserType,
                items: _userTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type == 'pelanggan' ? 'Pelanggan' : 'Petugas'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedUserType = val),
                validator: (value) =>
                    value == null ? 'Pilih jenis pengguna' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration("Email", Ionicons.mail),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val!.isEmpty || !val.contains("@")
                    ? 'Email tidak valid'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: _inputDecoration("Password", Ionicons.lock_closed)
                    .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Ionicons.eye
                          : Ionicons.eye_off_outline,
                      color: Colors.blue,
                    ),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                obscureText: !_passwordVisible,
                validator: (val) =>
                    val!.isEmpty ? 'Password tidak boleh kosong' : null,
              ),
              const SizedBox(height: 24),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Ionicons.log_in_outline),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _login,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterPage()),
                        ),
                icon: const Icon(Ionicons.person_add),
                label: const Text("Belum punya akun? Daftar di sini"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Ionicons.warning_outline),
                label: const Text("Laporkan Temuan Kebocoran"),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TemuanKebocoranPage()),
                ),
              ),
              const Divider(height: 40),
              Text(
                "Lacak Laporan Anda (Tanpa Login)",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _trackCodeController,
                decoration:
                    _inputDecoration("Masukkan Kode Tracking", Ionicons.search),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    _trackCodeController.text.trim().isEmpty || _isLoading
                        ? null
                        : _trackReportFromLogin,
                child: const Text("Lacak Laporan"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue[100],
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue[700]),
      filled: true,
      fillColor: Colors.blue[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
