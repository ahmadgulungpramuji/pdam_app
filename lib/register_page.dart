// lib/register_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan path ini benar
import 'package:google_fonts/google_fonts.dart'; // Untuk font yang lebih menarik
import 'package:flutter_vector_icons/flutter_vector_icons.dart'; // Untuk ikon

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomorHpController = TextEditingController();
  final _idPelangganController =
      TextEditingController(); // Ini untuk ID PDAM/Nomor Sambungan Langganan (NSL)
  final ApiService _apiService = ApiService();

  int? _selectedCabangId;
  bool _isLoading = false;
  bool _passwordVisible = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Daftar cabang statis untuk contoh, idealnya ini dari API jika dinamis
  // Atau jika logika _otomatisPilihCabang sudah cukup, ini tidak perlu ditampilkan
  // final List<Map<String, dynamic>> _cabangOptions = [
  //   {'id': 1, 'nama': 'Cabang A (ID PDAM diawali 10)'},
  //   {'id': 2, 'nama': 'Cabang B (ID PDAM diawali 12)'},
  //   // Tambahkan cabang lain jika perlu
  // ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nomorHpController.dispose();
    _idPelangganController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _otomatisPilihCabang() {
    final idPdam = _idPelangganController.text.trim();
    // Logika penentuan cabang Anda sudah baik.
    // Pastikan ID Cabang (1, 2, 3, dst.) sesuai dengan ID di database tabel 'cabangs' Anda.
    if (idPdam.length >= 2) {
      final duaDigit = idPdam.substring(0, 2);
      switch (duaDigit) {
        case '10':
          _selectedCabangId = 1;
          break; // Sesuaikan ID ini dengan ID di DB
        case '12':
          _selectedCabangId = 2;
          break; // Sesuaikan ID ini dengan ID di DB
        case '15':
          _selectedCabangId = 3;
          break; // Sesuaikan ID ini dengan ID di DB
        case '20':
          _selectedCabangId = 4;
          break; // Sesuaikan ID ini dengan ID di DB
        case '30':
          _selectedCabangId = 5;
          break; // Sesuaikan ID ini dengan ID di DB
        case '40':
          _selectedCabangId = 6;
          break; // Sesuaikan ID ini dengan ID di DB
        case '50':
          _selectedCabangId = 7;
          break; // Sesuaikan ID ini dengan ID di DB
        case '60':
          _selectedCabangId = 8;
          break; // Sesuaikan ID ini dengan ID di DB
        default:
          _selectedCabangId = null;
          break;
      }
    } else {
      _selectedCabangId = null;
    }
    // Untuk memicu rebuild dan menampilkan status cabang terdeteksi
    if (mounted) setState(() {});
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Harap perbaiki semua error pada form.', isError: true);
      return;
    }
    // Panggil _otomatisPilihCabang sekali lagi untuk memastikan _selectedCabangId terbaru
    _otomatisPilihCabang();
    if (_selectedCabangId == null) {
      _showSnackbar(
        'ID Pelanggan (NSL) tidak valid atau tidak sesuai dengan format cabang yang terdaftar.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Panggil API untuk registrasi pelanggan (tabel pelanggans)
      final response = await _apiService.registerPelanggan(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nomorHp: _nomorHpController.text.trim(),
        idCabang: _selectedCabangId!,
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // 201 Created
        final idPelangganBaru =
            responseData['id'] as int?; // Ambil ID pelanggan dari respons
        if (idPelangganBaru == null) {
          _showSnackbar(
            'Registrasi berhasil, namun ID pelanggan tidak diterima dari server.',
            isError: true,
          );
          return;
        }

        // Setelah pelanggan berhasil dibuat, buat entri di tabel id_pdams
        final pdamRes = await _apiService.createIdPdam(
          nomor: _idPelangganController.text.trim(), // Ini adalah NSL
          idPelanggan: idPelangganBaru,
        );

        if (!mounted) return;

        if (pdamRes.statusCode == 201 || pdamRes.statusCode == 200) {
          _showSnackbar(
            'Registrasi berhasil! Akun dan ID PDAM Anda telah dibuat.',
            isError: false,
          );
          // Kembali ke halaman login setelah registrasi sukses
          Navigator.pop(context);
        } else {
          final pdamErrorData = jsonDecode(pdamRes.body);
          _showSnackbar(
            'Akun berhasil dibuat, namun gagal menyimpan ID PDAM: ${pdamErrorData['message'] ?? 'Error tidak diketahui'}',
            isError: true,
          );
        }
      } else if (response.statusCode == 422) {
        // Validation errors
        final errors = responseData['errors'] as Map<String, dynamic>?;
        String msg = 'Registrasi gagal:';
        errors?.forEach((field, messages) {
          if (messages is List && messages.isNotEmpty) {
            msg +=
                '\n- ${field.toString().capitalize()}: ${messages.join(', ')}';
          }
        });
        _showSnackbar(msg, isError: true);
      } else {
        final errMsg =
            responseData['message'] ?? 'Terjadi kesalahan pada server.';
        _showSnackbar('Gagal melakukan registrasi: $errMsg', isError: true);
      }
    } catch (e) {
      if (mounted)
        _showSnackbar('Terjadi kesalahan: ${e.toString()}', isError: true);
      print("Error register: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    String? labelText, // Opsional, jika ingin label di atas
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.5),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 8.0),
            child: Icon(icon, color: Colors.blue.shade700, size: 22),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.blue.shade50.withOpacity(0.7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            // Border saat tidak fokus
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 1.8,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade700, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade900, width: 1.8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 10,
          ),
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Warna latar lebih netral
      appBar: AppBar(
        title: Text(
          'Buat Akun Baru',
          style: GoogleFonts.lato(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white, // AppBar putih
        foregroundColor: Colors.blue.shade800, // Warna teks dan ikon AppBar
        elevation: 1.5, // Shadow tipis
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Ionicons.person_add_outline,
                        size: 50,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Daftar Akun Pelanggan',
                        style: GoogleFonts.lato(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Isi data diri Anda untuk melanjutkan.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 30),

                      _buildTextField(
                        controller: _usernameController,
                        hintText: 'Masukkan username Anda',
                        labelText: 'Username',
                        icon: Ionicons.person_outline,
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Username wajib diisi'
                                    : null,
                      ),
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'contoh@email.com',
                        labelText: 'Email',
                        icon: Ionicons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Email wajib diisi';
                          if (!RegExp(
                            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                          ).hasMatch(value)) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _nomorHpController,
                        hintText: 'Contoh: 081234567890',
                        labelText: 'Nomor HP',
                        icon: Ionicons.call_outline,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Nomor HP wajib diisi';
                          if (value.length < 10 || value.length > 15)
                            return 'Nomor HP antara 10-15 digit';
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _passwordController,
                        hintText: 'Minimal 6 karakter',
                        labelText: 'Password',
                        icon: Ionicons.lock_closed_outline,
                        obscureText: !_passwordVisible,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Ionicons.eye_outline
                                : Ionicons.eye_off_outline,
                            color: Colors.grey.shade600,
                          ),
                          onPressed:
                              () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                        ),
                        validator:
                            (value) =>
                                value != null && value.length < 6
                                    ? 'Password minimal 6 karakter'
                                    : null,
                      ),
                      _buildTextField(
                        controller: _idPelangganController,
                        hintText: 'Masukkan Nomor Sambungan Langganan (NSL)',
                        labelText: 'ID Pelanggan / NSL',
                        icon: Ionicons.barcode_outline,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator:
                            (value) =>
                                value == null ||
                                        value
                                            .isEmpty // Cukup cek kosong, validasi format di _otomatisPilihCabang
                                    ? 'ID Pelanggan (NSL) wajib diisi'
                                    : null,
                        onChanged: (_) => _otomatisPilihCabang(),
                      ),

                      // Menampilkan status deteksi cabang
                      if (_idPelangganController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15.0, top: 0),
                          child: Text(
                            _selectedCabangId != null
                                ? 'Cabang terdeteksi: ID ${_selectedCabangId}.' // Anda bisa mapping ID ke Nama Cabang jika mau
                                : 'Format ID Pelanggan (NSL) tidak dikenali untuk cabang manapun.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  _selectedCabangId != null
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                              fontSize: 13,
                              // fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Ionicons.person_add_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          style: ElevatedButton.styleFrom(
                            // backgroundColor: Colors.blue.shade700, // Sudah diatur theme
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          onPressed:
                              _isLoading ||
                                      (_idPelangganController.text.isNotEmpty &&
                                          _selectedCabangId == null)
                                  ? null // Disable jika loading atau ID Pelanggan diisi tapi cabang tidak terdeteksi
                                  : _register,
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
                                    'DAFTAR SEKARANG',
                                    style: TextStyle(color: Colors.white),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: Text(
                          'Sudah punya akun? Login',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
extension StringExtension on String {
  String capitalize() {
    return substring(0, 1).toUpperCase() + substring(1).toLowerCase();
  }
}

// Extension StringCapitalize sudah ada di file Anda sebelumnya, jadi tidak perlu diulang
// extension StringCapitalize on String {
//   String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
// }
