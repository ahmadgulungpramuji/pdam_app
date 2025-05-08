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

  // State untuk Dropdown Cabang
  int? _selectedCabangId;
  List<Map<String, dynamic>> _cabangOptionsApi = [];
  bool _isCabangLoading = true;
  String? _cabangError;

  bool _isLoading = false;
  bool _passwordVisible = false; // Untuk visibility password

  @override
  void initState() {
    super.initState();
    _fetchCabangOptions(); // Ambil data cabang saat halaman dimuat
  }

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

  // --- Fungsi untuk mengambil data Cabang dari API ---
  Future<void> _fetchCabangOptions() async {
    setState(() {
      _isCabangLoading = true;
      _cabangError = null;
    });

    try {
      final response = await _apiService
          .fetchCabangs() // Gunakan fungsi dari ApiService
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Map<String, dynamic>> options = [];

        for (var item in data) {
          // Pastikan item memiliki 'id' dan 'nama_cabang'
          if (item is Map<String, dynamic> &&
              item.containsKey('id') &&
              item.containsKey('nama_cabang')) {
            options.add({
              'id': item['id'] as int,
              'nama_cabang': item['nama_cabang'] as String,
              // Jika perlu data lain dari cabang (misal lokasi_maps), tambahkan di sini
            });
          } else {
            print("Invalid item format from API: $item");
          }
        }

        setState(() {
          _cabangOptionsApi = options;
        });
      } else {
        setState(() {
          _cabangError = 'Gagal memuat cabang: Status ${response.statusCode}';
        });
        print(
          'Failed to load cabang: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cabangError = 'Terjadi kesalahan saat memuat data cabang.';
      });
      print('Error fetching cabang: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCabangLoading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validasi tambahan untuk dropdown cabang
    if (_selectedCabangId == null) {
      _showSnackbar('Silakan pilih cabang terlebih dahulu.');
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

  // Helper Widget untuk membangun bagian Dropdown Cabang (sama seperti di TemuanKebocoranPage)
  Widget _buildCabangDropdown() {
    if (_isCabangLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 15),
            Text("Memuat data cabang...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_cabangError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 30),
            const SizedBox(height: 8),
            Text(
              _cabangError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              onPressed: _fetchCabangOptions, // Tombol untuk retry
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    // Tampilan dropdown jika data berhasil dimuat dan tidak ada error
    return DropdownButtonFormField<int>(
      value: _selectedCabangId,
      hint: const Text('Pilih Cabang'),
      isExpanded: true,
      items:
          _cabangOptionsApi.isEmpty
              ? [
                const DropdownMenuItem<int>(
                  value: null,
                  enabled:
                      false, // Disable dropdown item jika tidak ada data cabang
                  child: Text(
                    "Tidak ada data cabang tersedia",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ]
              : _cabangOptionsApi.map((cabang) {
                return DropdownMenuItem<int>(
                  value: cabang['id'] as int,
                  child: Text(cabang['nama_cabang'] as String),
                );
              }).toList(),
      onChanged:
          _cabangOptionsApi.isEmpty || _isLoading
              ? null
              : (value) {
                setState(() {
                  _selectedCabangId = value;
                });
              },
      validator: (value) {
        // Validasi hanya jika tidak sedang loading, tidak ada error cabang,
        // ada options cabang, dan value masih null
        if (!_isCabangLoading &&
            _cabangError == null &&
            _cabangOptionsApi.isNotEmpty &&
            value == null) {
          return 'Cabang tidak boleh kosong';
        }
        return null;
      },
      decoration: const InputDecoration(
        labelText: 'Cabang',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_city),
      ),
    );
  }

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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'ID Pelanggan tidak boleh kosong';
                    }
                    // Tambahkan validasi format ID Pelanggan jika perlu
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Dropdown Cabang
                _buildCabangDropdown(),
                const SizedBox(height: 24),

                // Tombol Register
                ElevatedButton(
                  onPressed:
                      _isLoading || _isCabangLoading || _cabangError != null
                          ? null
                          : _register, // Disable jika loading atau ada masalah cabang
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
