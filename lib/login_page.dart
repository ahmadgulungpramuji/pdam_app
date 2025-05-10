// login_page.dart
// ignore_for_file: unused_import, unused_local_variable

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdam_app/register_page.dart';
import 'package:pdam_app/temuan_kebocoran_page.dart';
import 'package:pdam_app/home_pelanggan_page.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Pastikan import
import 'api_service.dart'; // Import file api_service.dart Anda
// Import halaman utama pelanggan

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _trackCodeController =
      TextEditingController(); // Controller baru
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService(); // Inisialisasi ApiService

  bool _isLoading = false;
  bool _passwordVisible = false; // Untuk visibility password
  String? _selectedUserType; // Untuk menyimpan jenis pengguna yang dipilih
  List<String> _userTypes = ['pelanggan', 'petugas'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _trackCodeController.dispose(); // Jangan lupa dispose controller baru
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
      '/tracking_page', // Ganti dengan route halaman tracking Anda
      arguments: code, // Kirim kode tracking
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
        final user = responseData['user']; // Data user jika perlu

        // Simpan token
        await _apiService.saveToken(token);

        _showSnackbar('Login berhasil!', isError: false);

        // Navigasi berdasarkan jenis pengguna
        if (_selectedUserType == 'pelanggan') {
          // <-- Bagian ini yang diubah
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const HomePelangganPage(),
            ), // Menggunakan MaterialPageRoute
          );
          // <-- Akhir bagian yang diubah
        } else if (_selectedUserType == 'petugas') {
          Navigator.pushReplacementNamed(
            context,
            '/home_petugas', // Ganti dengan route halaman utama petugas Anda (atau gunakan MaterialPageRoute jika diinginkan)
          );
        }
      } else if (response.statusCode == 422) {
        // Handle validation errors from Laravel
        final errors = jsonDecode(response.body)['errors'];
        String errorMessage = 'Login gagal:';
        errors.forEach((field, messages) {
          errorMessage += '\n- ${messages.join(", ")}';
        });
        _showSnackbar(errorMessage);
      } else {
        // Handle other error status codes
        final responseData = jsonDecode(response.body);
        String errorMessage =
            responseData['message'] ?? 'Login gagal. Silakan coba lagi.';
        _showSnackbar('Login gagal: $errorMessage');
        print('Login failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan saat login: $e');
      print('Error during login: $e');
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
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey, // Form ini hanya untuk login, bukan tracking
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Selamat Datang',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // Dropdown untuk memilih jenis pengguna
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Login Sebagai',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  value: _selectedUserType,
                  items:
                      _userTypes.map((userType) {
                        return DropdownMenuItem(
                          value: userType,
                          child: Text(
                            userType == 'pelanggan' ? 'Pelanggan' : 'Petugas',
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Pilih jenis pengguna';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!value.contains('@')) {
                      return 'Masukkan email yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Theme.of(context).primaryColorDark,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_passwordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('Login'),
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterPage(),
                              ),
                            );
                          },
                  child: const Text('Belum punya akun? Daftar di sini'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.report_problem),
                  label: const Text("Laporkan Temuan Kebocoran"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TemuanKebocoranPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40), // Spacer

                const Divider(height: 40), // Pemisah

                const Text(
                  'Lacak Laporan Anda (Tanpa Login)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Field Kode Tracking
                TextFormField(
                  controller: _trackCodeController,
                  decoration: InputDecoration(
                    labelText: 'Masukkan Kode Tracking',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  // Tidak perlu validator di sini jika tracking tidak wajib diisi
                ),
                const SizedBox(height: 16),

                // Tombol Lacak
                ElevatedButton(
                  // Disable jika sedang loading login, atau jika field kode kosong
                  onPressed:
                      _isLoading || _trackCodeController.text.trim().isEmpty
                          ? null
                          : _trackReportFromLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    backgroundColor:
                        Colors.grey[300], // Warna berbeda untuk tombol tracking
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Lacak Laporan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
