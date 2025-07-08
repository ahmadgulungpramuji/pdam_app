// lib/register_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan path ini benar
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
  void _nextPage() {
    if (_currentPage < 3) {
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
      // If on the first page, pop the navigator
      Navigator.of(context).pop();
    }
  }

  // --- Business Logic ---
  bool _otomatisPilihCabang() {
    final idPdam = _idPelangganController.text.trim();
    _selectedCabangId = null; // Reset first
    if (idPdam.length >= 2) {
      final duaDigit = idPdam.substring(0, 2);
      switch (duaDigit) {
        case '10':
          _selectedCabangId = 1;
          break;
        case '12':
          _selectedCabangId = 2;
          break;
        case '15':
          _selectedCabangId = 3;
          break;
        case '20':
          _selectedCabangId = 4;
          break;
        case '30':
          _selectedCabangId = 5;
          break;
        case '40':
          _selectedCabangId = 6;
          break;
        case '50':
          _selectedCabangId = 7;
          break;
        case '60':
          _selectedCabangId = 8;
          break;
      }
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

      if (response.statusCode == 201) {
        final idPelangganBaru = responseData['id'] as int?;
        if (idPelangganBaru == null) {
          _showSnackbar(
            'Registrasi gagal: ID pelanggan tidak diterima.',
            isError: true,
          );
          return;
        }

        final pdamRes = await _apiService.createIdPdam(
          nomor: _idPelangganController.text.trim(),
          idPelanggan: idPelangganBaru,
        );

        if (pdamRes.statusCode == 201 || pdamRes.statusCode == 200) {
          _showSnackbar('Registrasi berhasil!', isError: false);
          Navigator.of(context).pop();
        } else {
          final pdamErrorData = jsonDecode(pdamRes.body);
          _showSnackbar(
            'Akun dibuat, tapi gagal menyimpan ID PDAM: ${pdamErrorData['message'] ?? 'Error'}',
            isError: true,
          );
        }
      } else {
        final errMsg =
            responseData['message'] ?? 'Terjadi kesalahan pada server.';
        _showSnackbar('Registrasi gagal: $errMsg', isError: true);
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInvalidIdDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nomor Tidak Valid'),
            content: const Text(
              'Nomor pelanggan yang Anda masukkan tidak dikenali atau tidak valid. Harap periksa kembali.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back),
          onPressed: _previousPage,
          tooltip: 'Kembali',
        ),
        title: const Text('Daftar Baru'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProgressBar(),
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
    );
  }

  Widget _buildProgressBar() {
    final double progress = (_currentPage + 1) / 4.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Langkah ${_currentPage + 1} dari 4',
            style: GoogleFonts.lato(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget form,
    required VoidCallback onContinue,
    required GlobalKey<FormState> formKey,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.lato(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 32),
          Form(key: formKey, child: form),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('LANJUT'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return _buildStepContainer(
      title: 'Masukkan Nomor Pelanggan',
      subtitle: 'Gunakan Nomor Sambungan Langganan (NSL) Anda untuk memulai.',
      formKey: _step1FormKey,
      form: TextFormField(
        controller: _idPelangganController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Nomor Pelanggan (NSL)',
          prefixIcon: Icon(Ionicons.barcode_outline),
        ),
        validator:
            (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
        onChanged: (_) => setState(() {}), // To rebuild and check button state
      ),
      onContinue: () {
        if (_step1FormKey.currentState!.validate()) {
          if (_otomatisPilihCabang()) {
            _nextPage();
          } else {
            _showInvalidIdDialog();
          }
        }
      },
    );
  }

  Widget _buildStep2() {
    return _buildStepContainer(
      title: 'Pilih Username Anda',
      subtitle: 'Username ini akan digunakan untuk login ke aplikasi.',
      formKey: _step2FormKey,
      form: TextFormField(
        controller: _usernameController,
        decoration: const InputDecoration(
          labelText: 'Username',
          prefixIcon: Icon(Ionicons.person_outline),
        ),
        validator:
            (value) =>
                value == null || value.isEmpty ? 'Username wajib diisi' : null,
      ),
      onContinue: () {
        if (_step2FormKey.currentState!.validate()) {
          _nextPage();
        }
      },
    );
  }

  Widget _buildStep3() {
    return _buildStepContainer(
      title: 'Lengkapi Data Diri',
      subtitle: 'Hampir selesai! Mohon isi data berikut.',
      formKey: _step3FormKey,
      form: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Ionicons.mail_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Email wajib diisi';
              if (!RegExp(
                r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
              ).hasMatch(value)) {
                return 'Format email tidak valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nomorHpController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nomor HP',
              prefixIcon: Icon(Ionicons.call_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Nomor HP wajib diisi';
              if (value.length < 10) return 'Nomor HP minimal 10 digit';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Ionicons.lock_closed_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Ionicons.eye_outline
                      : Ionicons.eye_off_outline,
                ),
                onPressed:
                    () => setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            validator:
                (value) =>
                    value != null && value.length < 6
                        ? 'Password minimal 6 karakter'
                        : null,
          ),
        ],
      ),
      onContinue: () {
        if (_step3FormKey.currentState!.validate()) {
          _nextPage();
        }
      },
    );
  }

  Widget _buildStep4Confirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konfirmasi Data Anda',
            style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Pastikan semua data di bawah ini sudah benar sebelum mendaftar.',
            style: GoogleFonts.lato(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildConfirmationTile(
                    Ionicons.barcode_outline,
                    'Nomor Pelanggan',
                    _idPelangganController.text,
                  ),
                  _buildConfirmationTile(
                    Ionicons.person_outline,
                    'Username',
                    _usernameController.text,
                  ),
                  _buildConfirmationTile(
                    Ionicons.mail_outline,
                    'Email',
                    _emailController.text,
                  ),
                  _buildConfirmationTile(
                    Ionicons.call_outline,
                    'Nomor HP',
                    _nomorHpController.text,
                  ),
                  _buildConfirmationTile(
                    Ionicons.lock_closed_outline,
                    'Password',
                    '********',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                      : const Text('DAFTAR SEKARANG'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: GoogleFonts.lato(fontSize: 15)),
      dense: true,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return substring(0, 1).toUpperCase() + substring(1).toLowerCase();
  }
}
