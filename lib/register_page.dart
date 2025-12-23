// lib/register_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';       
import 'dart:async';    
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdam_app/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // --- Controllers & Keys ---
  final _pageController = PageController();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  final _idPelangganController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomorHpController = TextEditingController();
  final ApiService _apiService = ApiService();

  // --- State Variables ---
  int _currentPage = 0;
  int? _selectedCabangId;
  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _pageController.dispose();
    _idPelangganController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nomorHpController.dispose();
    super.dispose();
  }

  // --- Navigation Logic ---
  void _nextPage() async {
    bool isStepValid = false;
    switch (_currentPage) {
      case 0:
        if (_step1FormKey.currentState?.validate() ?? false) {
          if (_otomatisPilihCabang()) {
            isStepValid = true;
          } else {
            _showInvalidIdDialog();
          }
        }
        break;
      case 1:
        isStepValid = _step2FormKey.currentState?.validate() ?? false;
        break;
      case 2:
        if (_step3FormKey.currentState?.validate() ?? false) {
          setState(() => _isLoading = true);
          try {
            final nomorSudahAda = await _apiService
                .checkNomorHpExists(_nomorHpController.text.trim());
            if (nomorSudahAda) {
              _showSnackbar(
                  'Nomor WA ini sudah terdaftar. Silakan gunakan nomor lain.',
                  isError: true);
            } else {
              isStepValid = true;
            }
          } catch (e) {
            // --- AWAL PERUBAHAN ---
            String errorMessage;
            if (e is SocketException) {
              errorMessage = 'Periksa koneksi internet Anda.';
            } else if (e is TimeoutException) {
              errorMessage = 'Koneksi timeout. Gagal memverifikasi nomor.';
            } else {
              errorMessage = 'Gagal memverifikasi nomor: ${e.toString().replaceFirst("Exception: ", "")}';
            }
            _showSnackbar(errorMessage, isError: true);
            // --- AKHIR PERUBAHAN ---
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        }
        break;
    }

    if (isStepValid) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // --- Business Logic ---
  bool _otomatisPilihCabang() {
    final idPdam = _idPelangganController.text.trim();
    _selectedCabangId = null;
    
    // UBAH DARI 2 MENJADI 3
    if (idPdam.length >= 3) { 
      // Ambil 3 digit pertama (contoh: 100 dari 1005664558)
      final tigaDigit = idPdam.substring(0, 3); 

      const Map<String, int> cabangMapping = {
        '120': 1,
        '400': 2,
        '100': 3, // Sekarang "100" akan cocok dengan input Anda
        '200': 4,
        '300': 5,
        '500': 6,
        '230': 7,
        '600': 8,
        '220': 9,
        '110': 10,
        '210': 11,
        '320': 12,
        '310': 13,
        '410': 14
      };
      
      // Cari menggunakan 3 digit
      _selectedCabangId = cabangMapping[tigaDigit]; 
    }
    return _selectedCabangId != null;
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.registerPelanggan(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nomorHp: _nomorHpController.text.trim(),
        idCabang: _selectedCabangId!,
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // --- BAGIAN YANG DIPERBARUI ---
        final idPelangganBaru = responseData['user']?['id'] as int?;
        final newToken = responseData['token'] as String?; // <-- Ambil token

        if (idPelangganBaru == null || newToken == null) {
          throw Exception(
              'Registrasi gagal: Data token atau ID tidak diterima.');
        }

        // Simpan token SEGERA setelah registrasi berhasil
        await _apiService.saveToken(newToken);
        // ---------------------------------

        // Sekarang panggil createIdPdam, yang sudah otomatis menggunakan token
        final pdamRes = await _apiService.createIdPdam(
          nomor: _idPelangganController.text.trim(),
          idPelanggan: idPelangganBaru,
        );

        final pdamData = jsonDecode(pdamRes.body);
        if (pdamRes.statusCode >= 200 && pdamRes.statusCode < 300) {
          _showSnackbar('Registrasi berhasil! Silakan login.', isError: false);
          Navigator.of(context).pop();
        } else {
          throw Exception(
              'Akun dibuat, tapi gagal menyimpan ID PDAM: ${pdamData['message']}');
        }
      } else {
        String errorMessage =
            responseData['message'] ?? 'Terjadi kesalahan pada server.';
        if (responseData.containsKey('errors')) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first[0];
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      // --- AWAL PERUBAHAN ---
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'Periksa koneksi internet Anda.';
      } else if (e is TimeoutException) {
        errorMessage = 'Koneksi timeout. Gagal melakukan registrasi.';
      } else {
        errorMessage = e.toString().replaceFirst("Exception: ", "");
      }
      _showSnackbar('Registrasi Gagal: $errorMessage', isError: true);
      // --- AKHIR PERUBAHAN ---
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInvalidIdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nomor Pelanggan Tidak Valid',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
            'Nomor pelanggan yang Anda masukkan tidak dikenali. Harap periksa kembali.',
            style: GoogleFonts.manrope()),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Ionicons.arrow_back), onPressed: _previousPage),
        title: Text('Daftar Akun Pelanggan',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          _buildStepper(primaryColor),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4Confirmation(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavigationButtons(primaryColor),
    );
  }

  // --- UI WIDGETS ---
  Widget _buildStepper(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Row(
        children: List.generate(4, (index) {
          bool isActive = index <= _currentPage;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      isActive ? primaryColor : Colors.grey.shade300,
                  child: Text('${index + 1}',
                      style: GoogleFonts.manrope(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isActive ? primaryColor : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          if (_currentPage > 0 && !_isLoading)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: primaryColor),
                ),
                child: Text('Kembali',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentPage == 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_currentPage == 3 ? _register : _nextPage),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _currentPage == 3 ? Colors.green : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading && _currentPage == 3
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3))
                  : Text(
                      _currentPage == 3 ? 'DAFTAR SEKARANG' : 'Selanjutnya',
                      style: GoogleFonts.manrope(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0077B6), size: 28),
          const SizedBox(width: 12),
          Text(title,
              style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF212529))),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        validator: validator,
        style: GoogleFonts.manrope(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(color: Colors.grey.shade600),
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0077B6), width: 2)),
        ),
      ),
    );
  }

  Widget _buildStepWrapper(
      {required Widget child, required GlobalKey<FormState> formKey}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(key: formKey, child: child),
    );
  }

  Widget _buildStep1() {
    return _buildStepWrapper(
      formKey: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'Langkah 1: Verifikasi Nomor', Ionicons.barcode_outline),
          _buildTextField(
              controller: _idPelangganController,
              label: 'Nomor Pelanggan (NSL)',
              hint: 'Masukkan Nomor Sambungan Langganan',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  v!.isEmpty ? 'Nomor pelanggan wajib diisi' : null),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return _buildStepWrapper(
      formKey: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'Langkah 2: Atur Akun', Ionicons.person_circle_outline),
          _buildTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Buat username unik Anda',
              validator: (v) => v!.isEmpty ? 'Username wajib diisi' : null),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Minimal 8 karakter',
            obscureText: !_passwordVisible,
            suffixIcon: IconButton(
              icon: Icon(_passwordVisible
                  ? Ionicons.eye_outline
                  : Ionicons.eye_off_outline),
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
            ),
            validator: (v) =>
                (v?.length ?? 0) < 8 ? 'Password minimal 8 karakter' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return _buildStepWrapper(
      formKey: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Langkah 3: Data Kontak', Ionicons.call_outline),
          _buildTextField(
              controller: _nomorHpController,
              label: 'Nomor WhatsApp Aktif',
              hint: 'Contoh: 081234567890',
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Nomor WA wajib diisi';
                }
                if (v.length < 10) {
                  return 'Nomor WA terlalu pendek (minimal 10 digit)';
                }
                if (v.length > 13) {
                  return 'Nomor WA terlalu panjang (maksimal 13 digit)';
                }
                return null;
              }),
          _buildTextField(
              controller: _emailController,
              label: 'Email (Opsional)',
              hint: 'email@contoh.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v != null &&
                    v.isNotEmpty &&
                    !RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                        .hasMatch(v)) {
                  return 'Format email tidak valid';
                }
                return null;
              }),
        ],
      ),
    );
  }

  Widget _buildStep4Confirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'Langkah 4: Konfirmasi Data', Ionicons.checkmark_done_outline),
          Text(
            'Mohon periksa kembali semua data yang telah Anda masukkan sebelum mendaftar.',
            style: GoogleFonts.manrope(color: Colors.grey.shade700),
          ),
          const Divider(height: 32),
          _buildConfirmationSection("Data Pelanggan", [
            _buildConfirmationRow(
                "Nomor Pelanggan", _idPelangganController.text),
          ]),
          const Divider(height: 32),
          _buildConfirmationSection("Data Akun", [
            _buildConfirmationRow("Username", _usernameController.text),
            _buildConfirmationRow("Password", "********"),
          ]),
          const Divider(height: 32),
          _buildConfirmationSection("Data Kontak", [
            _buildConfirmationRow("Nomor WhatsApp", _nomorHpController.text),
            _buildConfirmationRow("Email",
                _emailController.text.isEmpty ? "-" : _emailController.text),
          ]),
        ],
      ),
    );
  }

  Widget _buildConfirmationSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: GoogleFonts.manrope(color: Colors.grey.shade600))),
          Expanded(
            flex: 3,
            child: Text(value,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
