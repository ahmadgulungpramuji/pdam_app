// register_page.dart
// ignore_for_file: unused_import

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart'; // Import file api_service.dart Anda
import 'package:flutter/services.dart'; // Import for TextInputFormatters
import 'package:flutter/foundation.dart'; // Tambahkan import ini

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nomorHpController = TextEditingController();
  final TextEditingController _idPelangganController =
      TextEditingController(); // Controller untuk nomor ID PDAM
  final ApiService _apiService = ApiService(); // Inisialisasi ApiService

  // State untuk Dropdown Cabang (tidak lagi diperlukan)
  int? _selectedCabangId;
  // List<Map<String, dynamic>> _cabangOptionsApi = []; (tidak lagi diperlukan)
  // bool _isCabangLoading = true; (tidak lagi diperlukan)
  // String? _cabangError; (tidak lagi diperlukan)

  bool _isLoading = false;
  bool _passwordVisible = false; // Untuk visibility password

  // @override
  // void initState() {
  //   super.initState();
  //   _fetchCabangOptions(); // Ambil data cabang saat halaman dimuat (tidak lagi diperlukan)
  // }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nomorHpController.dispose();
    _idPelangganController.dispose(); // Dispose controller ID Pelanggan
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

  // // --- Fungsi untuk mengambil data Cabang dari API --- (tidak lagi diperlukan)
  // Future<void> _fetchCabangOptions() async { ... }

  void _otomatisPilihCabang() {
    final idPdam = _idPelangganController.text.trim();
    if (idPdam.length >= 2) {
      final duaDigitPertama = idPdam.substring(0, 2);
      switch (duaDigitPertama) {
        case '10':
          _selectedCabangId = 1; // Indramayu
          break;
        case '12':
          _selectedCabangId = 2; // Asumsi ID untuk Losarang
          break;
        case '15':
          _selectedCabangId = 3; // Sindang
          break;
        case '20':
          _selectedCabangId = 4; // Jatibarang
          break;
        case '30':
          _selectedCabangId = 5; // Kertasmaya
          break;
        case '40':
          _selectedCabangId = 6; // Kandanghaur
          break;
        case '50':
          _selectedCabangId = 7; // Lohbener
          break;
        case '60':
          _selectedCabangId = 8; // Karangampel
          break;
        default:
          _selectedCabangId = null; // Atau logika default lainnya jika perlu
          break;
      }
    } else {
      _selectedCabangId = null; // Atau logika default lainnya jika perlu
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _otomatisPilihCabang(); // Otomatis pilih cabang berdasarkan ID PDAM

    // Validasi tambahan untuk memastikan cabang terpilih
    if (_selectedCabangId == null) {
      _showSnackbar(
        'ID Pelanggan tidak valid untuk pemilihan cabang otomatis.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final responsePelanggan = await _apiService.registerPelanggan(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        nomorHp: _nomorHpController.text,
        idCabang: _selectedCabangId!,
      );

      if (!mounted) return;

      if (responsePelanggan.statusCode == 201) {
        // Registrasi pelanggan berhasil, sekarang buat ID PDAM
        final responseDataPelanggan = jsonDecode(responsePelanggan.body);
        debugPrint("Username: ${responseDataPelanggan['username']}");
        debugPrint("Email: ${responseDataPelanggan['email']}");
        debugPrint("ID: ${responseDataPelanggan['id']}");
        debugPrint("ID Cabang: ${responseDataPelanggan['id_cabang']}");
        // Jangan mencetak password
        final int idPelanggan = responseDataPelanggan['id'];

        final responseIdPdam = await _apiService.createIdPdam(
          nomor: _idPelangganController.text,
          idPelanggan: idPelanggan,
        );

        if (responseIdPdam.statusCode == 201) {
          // Pembuatan ID PDAM berhasil
          _showSnackbar('Registrasi berhasil!', isError: false);
          Navigator.pop(context);
        } else {
          // Gagal membuat ID PDAM, mungkin perlu handling rollback atau info ke user
          final responseDataIdPdam = jsonDecode(responseIdPdam.body);
          _showSnackbar(
            'Registrasi berhasil, namun gagal membuat ID Pelanggan: ${responseDataIdPdam['message'] ?? 'Silakan coba lagi.'}',
          );
          // Mungkin arahkan user ke halaman login atau berikan opsi lain
          Navigator.pop(context);
        }
      } else if (responsePelanggan.statusCode == 422) {
        // Handle validation errors dari registrasi pelanggan
        final errors = jsonDecode(responsePelanggan.body)['errors'];
        String errorMessage = 'Registrasi gagal:';
        errors.forEach((field, messages) {
          String displayField = field.replaceAll('_', ' ').capitalize();
          errorMessage += '\n- $displayField: ${messages.join(", ")}';
        });
        _showSnackbar(errorMessage);
      } else {
        // Handle error status codes dari registrasi pelanggan
        final responseDataPelanggan = jsonDecode(responsePelanggan.body);
        String errorMessage =
            responseDataPelanggan['message'] ??
            'Registrasi gagal. Silakan coba lagi.';
        _showSnackbar('Registrasi gagal: $errorMessage');
        print(
          'Registration failed (Pelanggan): ${responsePelanggan.statusCode} - ${responsePelanggan.body}',
        );
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan saat registrasi: $e');
      print('Error during registration: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper Widget untuk membangun bagian Dropdown Cabang (tidak lagi diperlukan)
  // Widget _buildCabangDropdown() { ... }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrasi')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Daftar Akun Baru',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // Field Username
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Username tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Field Email
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

                // Field Nomor HP
                TextFormField(
                  controller: _nomorHpController,
                  decoration: InputDecoration(
                    labelText: 'Nomor HP',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nomor HP tidak boleh kosong';
                    }
                    // Tambahkan validasi format nomor HP jika perlu
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Field Password
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
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Field ID Pelanggan (sebenarnya nomor ID PDAM)
                TextFormField(
                  controller: _idPelangganController,
                  decoration: InputDecoration(
                    labelText: 'ID Pelanggan',
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  keyboardType: TextInputType.number, // Hanya menerima angka
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (value) {
                    _otomatisPilihCabang(); // Panggil saat nilai berubah
                    setState(
                      () {},
                    ); // Rebuild UI agar _selectedCabangId bisa berpengaruh (jika ada widget yang membutuhkannya)
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'ID Pelanggan tidak boleh kosong';
                    }
                    if (value.length < 8) {
                      return 'ID Pelanggan minimal 8 digit';
                    }
                    // Tambahkan validasi format ID Pelanggan jika perlu
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Text(
                  _selectedCabangId != null
                      ? 'Cabang akan otomatis dipilih.'
                      : 'Cabang tidak dapat ditentukan dari ID Pelanggan.',
                  style: TextStyle(
                    color:
                        _selectedCabangId != null ? Colors.green : Colors.red,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                // Tombol Register
                ElevatedButton(
                  onPressed:
                      _isLoading || _selectedCabangId == null
                          ? null
                          : _register, // Disable jika loading atau cabang belum dipilih otomatis
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
                          : const Text('Daftar'),
                ),
                const SizedBox(height: 20),

                // Link kembali ke Halaman Login
                TextButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            Navigator.pop(
                              context,
                            ); // Kembali ke halaman sebelumnya (Login)
                          },
                  child: const Text('Sudah punya akun? Login di sini'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Extension untuk capitalize (Opsional, untuk format pesan error)
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
