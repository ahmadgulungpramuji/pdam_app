// lib/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/petugas_model.dart';

class EditProfilePage extends StatefulWidget {
  final Petugas currentPetugas;

  const EditProfilePage({super.key, required this.currentPetugas});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _emailController;
  late TextEditingController _nomorHpController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmationController =
      TextEditingController();

  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _passwordConfirmationVisible = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.currentPetugas.nama);
    _emailController = TextEditingController(text: widget.currentPetugas.email);
    _nomorHpController = TextEditingController(
      text: widget.currentPetugas.nomorHp,
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _nomorHpController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  void _showSnackbar(
    String message, {
    bool isError = true,
    BuildContext? scaffoldContext,
  }) {
    final currentContext = scaffoldContext ?? context;
    if (!mounted && scaffoldContext == null) return;

    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      Petugas updatedPetugas = await _apiService.updatePetugasProfile(
        nama: _namaController.text,
        email: _emailController.text,
        nomorHp: _nomorHpController.text,
        password:
            _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
        passwordConfirmation:
            _passwordConfirmationController.text.isNotEmpty
                ? _passwordConfirmationController.text
                : null,
      );
      if (mounted) {
        _showSnackbar(
          'Profil berhasil diperbarui!',
          isError: false,
          scaffoldContext: context,
        );
        Navigator.pop(
          context,
          updatedPetugas,
        ); // Kirim data terbaru kembali ke ProfilePage
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal memperbarui profil: $e', scaffoldContext: context);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(),
      prefixIcon: Icon(icon, color: Colors.blue[700]),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profil',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ubah Informasi Profil Anda',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _namaController,
                decoration: _inputDecoration(
                  'Nama Lengkap',
                  Ionicons.person_outline,
                ),
                style: GoogleFonts.poppins(),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Nama tidak boleh kosong'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration('Email', Ionicons.mail_outline),
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Email tidak boleh kosong';
                  if (!value.contains('@') || !value.contains('.'))
                    return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomorHpController,
                decoration: _inputDecoration('Nomor HP', Ionicons.call_outline),
                keyboardType: TextInputType.phone,
                style: GoogleFonts.poppins(),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Nomor HP tidak boleh kosong'
                            : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Ganti Password (Opsional)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: _inputDecoration(
                  'Password Baru',
                  Ionicons.lock_closed_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Ionicons.eye_outline
                          : Ionicons.eye_off_outline,
                      color: Colors.blueGrey,
                    ),
                    onPressed:
                        () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                  ),
                ),
                obscureText: !_passwordVisible,
                style: GoogleFonts.poppins(),
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  if (value != null &&
                      value.isNotEmpty &&
                      _passwordConfirmationController.text != value) {
                    return 'Konfirmasi password tidak cocok';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordConfirmationController,
                decoration: _inputDecoration(
                  'Konfirmasi Password Baru',
                  Ionicons.lock_closed_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordConfirmationVisible
                          ? Ionicons.eye_outline
                          : Ionicons.eye_off_outline,
                      color: Colors.blueGrey,
                    ),
                    onPressed:
                        () => setState(
                          () =>
                              _passwordConfirmationVisible =
                                  !_passwordConfirmationVisible,
                        ),
                  ),
                ),
                obscureText: !_passwordConfirmationVisible,
                style: GoogleFonts.poppins(),
                validator: (value) {
                  if (_passwordController.text.isNotEmpty &&
                      (value == null || value.isEmpty)) {
                    return 'Konfirmasi password tidak boleh kosong jika password baru diisi';
                  }
                  if (_passwordController.text.isNotEmpty &&
                      value != _passwordController.text) {
                    return 'Konfirmasi password tidak cocok';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon:
                    _isLoading
                        ? Container()
                        : const Icon(Ionicons.save_outline, size: 20),
                label:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          'Simpan Perubahan',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                onPressed: _isLoading ? null : _submitUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
