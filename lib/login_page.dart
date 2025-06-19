// lib/login_page.dart
// ignore_for_file: unused_import

import 'dart:convert'; // Tidak selalu perlu di sini jika ApiService menangani semua
import 'package:flutter/material.dart';
import 'package:pdam_app/register_page.dart';
import 'package:pdam_app/temuan_kebocoran_page.dart';
// import 'package:pdam_app/home_pelanggan_page.dart'; // Akan dinavigasi via named route
// import 'package:pdam_app/home_petugas_page.dart'; // Akan dinavigasi via named route
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'api_service.dart';
import 'models/temuan_kebocoran_model.dart'; // Untuk navigasi ke detail temuan

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

  bool _isLoading = false; // Untuk loading login
  bool _isTrackingReport = false; // Untuk loading track report
  bool _passwordVisible = false;

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
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _trackReportFromLogin() async {
    final code = _trackCodeController.text.trim();
    if (code.isEmpty) {
      _showSnackbar('Masukkan kode tracking terlebih dahulu.');
      return;
    }
    setState(() => _isTrackingReport = true);
    try {
      final TemuanKebocoran temuan = await _apiService.trackReport(code);
      if (mounted) {
        _trackCodeController.clear();
        Navigator.pushNamed(context, '/detail_temuan_page', arguments: temuan);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith("Exception: ")) {
          errorMessage = errorMessage.substring("Exception: ".length);
        }
        _showSnackbar(errorMessage, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isTrackingReport = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> responseData = await _apiService.unifiedLogin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final String token = responseData['token'] as String;
      final String userType = responseData['user_type'] as String;
      final Map<String, dynamic> userData =
          responseData['user'] as Map<String, dynamic>;

      await _apiService.saveToken(token); // Simpan token
      // Anda bisa menyimpan userData ke SharedPreferences di sini jika perlu diakses global
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.setString('user_data_app', jsonEncode(userData));

      _showSnackbar('Login berhasil sebagai $userType!', isError: false);

      if (userType == 'pelanggan') {
        // Menggunakan pushNamedAndRemoveUntil agar tidak bisa kembali ke halaman login
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home_pelanggan',
          (route) => false,
        );
      } else if (userType == 'petugas') {
        final int petugasId =
            userData['id'] as int; // Pastikan 'id' ada di userData
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home_petugas',
          (route) => false,
          arguments: {'idPetugasLoggedIn': petugasId},
        );
      } else {
        _showSnackbar(
          'Tipe pengguna tidak dikenal dari server.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith("Exception: ")) {
          errorMessage = errorMessage.substring("Exception: ".length);
        }
        _showSnackbar(errorMessage, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Warna latar yang lebih netral
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'app_logo_pdam',
                  child: Icon(
                    Ionicons.water,
                    size: 70,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 15),
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'PDAM Tirta Kencana', // Ganti dengan nama PDAM Anda
                      textAlign: TextAlign.center,
                      textStyle: GoogleFonts.lato(
                        // Ganti font jika mau
                        fontSize: 26,
                        fontWeight: FontWeight.w700, // Bold
                        color: Colors.blue.shade900,
                      ),
                      speed: const Duration(milliseconds: 120),
                    ),
                  ],
                  isRepeatingAnimation: false,
                  totalRepeatCount: 1,
                ),
                const SizedBox(height: 8),
                Text(
                  "Solusi Layanan Air Terpadu",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 35),
                _buildLoginFormCard(),
                const SizedBox(height: 25),
                _buildTrackingCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginFormCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Login Akun Anda",
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration(
                  "Email",
                  Ionicons.mail_open_outline,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!RegExp(
                    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                  ).hasMatch(val)) {
                    return 'Masukkan format email yang valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: _inputDecoration(
                  "Password",
                  Ionicons.lock_closed_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Ionicons.eye_outline
                          : Ionicons.eye_off_outline,
                      color: Colors.blue.shade700,
                    ),
                    onPressed:
                        () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                  ),
                ),
                obscureText: !_passwordVisible,
                validator:
                    (val) =>
                        val == null || val.isEmpty
                            ? 'Password tidak boleh kosong'
                            : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Ionicons.log_in_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  label:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                          : const Text(
                            'LOGIN',
                            style: TextStyle(
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                  style: ElevatedButton.styleFrom(
                    // backgroundColor: Colors.blue.shade700, // Diatur oleh theme
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _isLoading ? null : _login,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Belum punya akun?",
                    style: TextStyle(color: Colors.black54),
                  ),
                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterPage(),
                              ),
                            ), // Pastikan RegisterPage ada
                    child: Text(
                      "Daftar di sini",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Layanan Pelaporan Kebocoran",
              style: GoogleFonts.lato(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.teal.shade800,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _trackCodeController,
              decoration: _inputDecoration(
                "Masukkan Kode Tracking",
                Ionicons.search_circle_outline,
                iconColor: Colors.teal.shade700,
                fillColor: Colors.teal.shade50,
              ),
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(
                  Ionicons.locate_outline,
                  color: Colors.white,
                  size: 20,
                ),
                label:
                    _isTrackingReport
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : const Text(
                          "LACAK LAPORAN",
                          style: TextStyle(
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                onPressed:
                    (_trackCodeController.text.trim().isEmpty ||
                            _isTrackingReport ||
                            _isLoading)
                        ? null
                        : _trackReportFromLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 20, thickness: 0.5),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Ionicons.warning_outline,
                  color: Colors.teal,
                  size: 20,
                ),
                label: const Text(
                  "BUAT LAPORAN BARU",
                  style: TextStyle(color: Colors.teal, letterSpacing: 0.5),
                ),
                onPressed:
                    _isLoading || _isTrackingReport
                        ? null
                        : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TemuanKebocoranPage(),
                            ),
                          );
                        },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.teal.shade600),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Color? iconColor,
    Color? fillColor,
  }) {
    return InputDecoration(
      hintText:
          label, // Ganti labelText menjadi hintText untuk tampilan yang lebih modern
      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12.0, right: 8.0),
        child: Icon(icon, color: iconColor ?? Colors.blue.shade700, size: 22),
      ),
      filled: true,
      fillColor: fillColor ?? Colors.blue.shade50.withOpacity(0.7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: iconColor ?? Theme.of(context).primaryColor,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 5,
      ), // Sesuaikan padding
    );
  }
}
