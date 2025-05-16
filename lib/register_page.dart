// register_page.dart - Versi upgrade dengan animasi, responsif, dan tampilan keren
// ignore_for_file: unused_import, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  final _idPelangganController = TextEditingController();
  final ApiService _apiService = ApiService();

  int? _selectedCabangId;
  bool _isLoading = false;
  bool _passwordVisible = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _otomatisPilihCabang() {
    final idPdam = _idPelangganController.text.trim();
    if (idPdam.length >= 2) {
      final duaDigit = idPdam.substring(0, 2);
      switch (duaDigit) {
        case '10': _selectedCabangId = 1; break;
        case '12': _selectedCabangId = 2; break;
        case '15': _selectedCabangId = 3; break;
        case '20': _selectedCabangId = 4; break;
        case '30': _selectedCabangId = 5; break;
        case '40': _selectedCabangId = 6; break;
        case '50': _selectedCabangId = 7; break;
        case '60': _selectedCabangId = 8; break;
        default: _selectedCabangId = null; break;
      }
    } else {
      _selectedCabangId = null;
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    _otomatisPilihCabang();
    if (_selectedCabangId == null) {
      _showSnackbar('ID Pelanggan tidak valid untuk cabang.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.registerPelanggan(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        nomorHp: _nomorHpController.text,
        idCabang: _selectedCabangId!,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final idPelanggan = data['id'];

        final pdamRes = await _apiService.createIdPdam(
          nomor: _idPelangganController.text,
          idPelanggan: idPelanggan,
        );

        if (pdamRes.statusCode == 201) {
          _showSnackbar('Registrasi berhasil!', isError: false);
          Navigator.pop(context);
        } else {
          _showSnackbar('Gagal membuat ID PDAM.');
        }
      } else if (response.statusCode == 422) {
        final errors = jsonDecode(response.body)['errors'];
        String msg = 'Registrasi gagal:';
        errors.forEach((field, messages) {
          msg += '\n- ${field.toString().capitalize()}: ${messages.join(', ')}';
        });
        _showSnackbar(msg);
      } else {
        final errMsg = jsonDecode(response.body)['message'] ?? 'Terjadi kesalahan.';
        _showSnackbar('Gagal: $errMsg');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Registrasi'),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FontAwesomeIcons.userPlus, size: 64, color: Colors.blue),
                  const SizedBox(height: 20),
                  const Text(
                    'Daftar Akun Baru',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.person,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Username wajib diisi' : null,
                  ),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        value != null && !value.contains('@') ? 'Email tidak valid' : null,
                  ),

                  _buildTextField(
                    controller: _nomorHpController,
                    label: 'Nomor HP',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Nomor HP wajib diisi' : null,
                  ),

                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    obscure: !_passwordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                    ),
                    validator: (value) => value != null && value.length < 6
                        ? 'Password minimal 6 karakter'
                        : null,
                  ),

                  _buildTextField(
                    controller: _idPelangganController,
                    label: 'ID Pelanggan',
                    icon: Icons.confirmation_number,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value == null || value.length < 8
                        ? 'Minimal 8 digit ID'
                        : null,
                    onChanged: (_) {
                      _otomatisPilihCabang();
                      setState(() {});
                    },
                  ),

                  Text(
                    _selectedCabangId != null
                        ? 'Cabang otomatis terdeteksi.'
                        : 'Cabang tidak bisa ditentukan.',
                    style: TextStyle(
                      color: _selectedCabangId != null ? Colors.green : Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading || _selectedCabangId == null ? null : _register,
                      label: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Daftar', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Sudah punya akun? Login di sini'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
