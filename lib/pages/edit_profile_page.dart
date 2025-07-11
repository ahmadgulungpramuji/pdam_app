// lib/pages/edit_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/petugas_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _passwordConfirmationVisible = false;
  
  File? _selectedImage;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.currentPetugas.nama);
    _emailController = TextEditingController(text: widget.currentPetugas.email);
    _nomorHpController = TextEditingController(text: widget.currentPetugas.nomorHp);
    
    if (widget.currentPetugas.fotoProfil != null && widget.currentPetugas.fotoProfil!.isNotEmpty) {
      _currentImageUrl = '${_apiService.rootBaseUrl}/storage/${widget.currentPetugas.fotoProfil}';
    }
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

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }
  
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Ionicons.camera_outline),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Ionicons.image_outline),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final Map<String, String> data = {
        'nama': _namaController.text,
        'email': _emailController.text,
        'nomor_hp': _nomorHpController.text,
      };

      if (_passwordController.text.isNotEmpty) {
        data['password'] = _passwordController.text;
        data['password_confirmation'] = _passwordConfirmationController.text;
      }

      Petugas updatedPetugas = await _apiService.updatePetugasProfile(
        data: data,
        profileImage: _selectedImage,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil berhasil diperbarui!', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, updatedPetugas); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString().replaceFirst("Exception: ", "")}', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProfileImagePicker() {
    ImageProvider? backgroundImage;
    if (_selectedImage != null) {
      backgroundImage = FileImage(_selectedImage!);
    } else if (_currentImageUrl != null) {
      backgroundImage = CachedNetworkImageProvider(_currentImageUrl!);
    }
    
    return Center(
      child: GestureDetector(
        onTap: _showImageSourceActionSheet,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[200],
              backgroundImage: backgroundImage,
              child: backgroundImage == null 
                  ? Icon(Ionicons.person, size: 60, color: Colors.grey[400]) 
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Ionicons.camera, color: Colors.white, size: 20),
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
              _buildProfileImagePicker(),
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
                  if (value == null || value.isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Format email tidak valid';
                  }
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
                    return 'Konfirmasi password tidak boleh kosong';
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