// lib/profil_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdam_app/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// --- WIDGET ANIMASI (Untuk konsistensi) ---
class FadeInAnimation extends StatefulWidget {
  final int delay;
  final Widget child;

  const FadeInAnimation({super.key, this.delay = 0, required this.child});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _position = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(curve);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: widget.child,
      ),
    );
  }
}
// --- END WIDGET ANIMASI ---

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userData;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nomorHpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmationController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPasswordVisible = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nomorHpController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getUserProfile();
      if (mounted) {
        if (data != null) {
          setState(() {
            _userData = data;
            _nameController.text =
                _userData?['nama'] ?? _userData?['username'] ?? '';
            _emailController.text = _userData?['email'] ?? '';
            _nomorHpController.text = _userData?['nomor_hp'] ?? '';
            _selectedImage = null;
          });
        } else {
          _showSnackbar(
            'Gagal memuat data profil. Silakan coba lagi.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Error memuat profil: ${e.toString().replaceFirst('Exception: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (pickedFile != null) {
      final fileExtension = pickedFile.path.split('.').last.toLowerCase();
      if (fileExtension == 'jpg' ||
          fileExtension == 'jpeg' ||
          fileExtension == 'png') {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      } else {
        _showSnackbar(
          'Format file tidak didukung. Harap pilih JPG atau PNG.',
          isError: true,
        );
      }
    }
  }

  Future<void> _showImageSourceActionSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Ionicons.camera_outline),
                title: Text('Ambil Foto', style: GoogleFonts.manrope()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Ionicons.image_outline),
                title: Text('Pilih dari Galeri', style: GoogleFonts.manrope()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!mounted) return;
    if (_nameController.text.isEmpty || _nomorHpController.text.isEmpty) {
      _showSnackbar('Nama dan Nomor HP tidak boleh kosong.', isError: true);
      return;
    }
    if (_passwordController.text.isNotEmpty) {
      if (_passwordController.text != _passwordConfirmationController.text) {
        _showSnackbar('Konfirmasi password tidak cocok.', isError: true);
        return;
      }
      if (_passwordController.text.length < 6) {
        _showSnackbar('Password minimal harus 6 karakter.', isError: true);
        return;
      }
    }
    setState(() => _isSaving = true);

    final updatedData = {
      'nama': _nameController.text.trim(),
      'username': _nameController.text.trim(),
      'nomor_hp': _nomorHpController.text.trim(),
      'email': _emailController.text.trim(),
    };
    if (_passwordController.text.isNotEmpty) {
      updatedData['password'] = _passwordController.text;
      updatedData['password_confirmation'] =
          _passwordConfirmationController.text;
    }

    try {
      final successData = await _apiService.updateUserProfile(
        updatedData,
        profileImage: _selectedImage,
      );

      if (mounted) {
        _showSnackbar('Profil berhasil diperbarui!', isError: false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Gagal memperbarui profil: ${e.toString().replaceFirst('Exception: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);
    const Color textColor = Color(0xFF212529);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Edit Profil',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _userData == null
              ? _buildErrorState()
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        FadeInAnimation(
                            delay: 100, child: _buildProfileImage()),
                        const SizedBox(height: 24),
                        FadeInAnimation(
                          delay: 200,
                          child: _buildSectionCard(
                            title: 'Data Pribadi',
                            icon: Ionicons.person_outline,
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Nama Lengkap / Username',
                                  icon: Ionicons.person_outline,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Ionicons.mail_outline,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _nomorHpController,
                                  label: 'Nomor Telepon',
                                  icon: Ionicons.call_outline,
                                  keyboardType: TextInputType.phone,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeInAnimation(
                          delay: 300,
                          child: _buildSectionCard(
                            title: 'Ubah Password',
                            icon: Ionicons.lock_closed_outline,
                            child: Column(
                              children: [
                                _buildPasswordTextField(
                                  controller: _passwordController,
                                  label: 'Password Baru (opsional)',
                                ),
                                const SizedBox(height: 16),
                                _buildPasswordTextField(
                                  controller: _passwordConfirmationController,
                                  label: 'Konfirmasi Password Baru',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        FadeInAnimation(
                          delay: 400,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveChanges,
                            icon: _isSaving
                                ? Container()
                                : const Icon(Ionicons.save_outline, size: 20),
                            label: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('Simpan Perubahan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileImage() {
    const Color primaryColor = Color(0xFF0077B6);
    final String? profilePhotoPath = _userData?['foto_profil'];
    final String fullImageUrl =
        profilePhotoPath != null && profilePhotoPath.isNotEmpty
            ? '${_apiService.rootBaseUrl}/storage/$profilePhotoPath'
            : '';
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _selectedImage != null
                ? FileImage(_selectedImage!)
                : (fullImageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(fullImageUrl)
                    : null) as ImageProvider<Object>?,
            child: _selectedImage == null && fullImageUrl.isEmpty
                ? Icon(
                    Ionicons.person_circle_outline,
                    size: 100,
                    color: Colors.grey.shade400,
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Ionicons.camera_outline,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return FadeInAnimation(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Ionicons.cloud_offline_outline,
                  size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              Text("Oops!",
                  style: GoogleFonts.manrope(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Tidak dapat memuat data profil.",
                  textAlign: TextAlign.center, style: GoogleFonts.manrope()),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                icon: const Icon(Ionicons.refresh_outline),
                label: const Text("Coba Lagi"),
                onPressed: _fetchUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B6),
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF212529),
            ),
          ),
          const Divider(height: 24, thickness: 0.5),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: GoogleFonts.manrope(),
      decoration: _inputDecoration(
        label: label,
        icon: icon,
      ),
    );
  }

  Widget _buildPasswordTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !_isPasswordVisible,
      style: GoogleFonts.manrope(),
      decoration: _inputDecoration(
        label: label,
        icon: Ionicons.lock_closed_outline,
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible
                ? Ionicons.eye_off_outline
                : Ionicons.eye_outline,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.manrope(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: const Color(0xFF0077B6), size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0077B6), width: 1.5),
      ),
    );
  }
}
