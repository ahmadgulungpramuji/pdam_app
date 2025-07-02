// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pdam_app/api_service.dart';

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
  bool _isLoading = true;
  bool _isSaving = false;

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
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _userData = null;
    });

    final data = await _apiService.getUserProfile();

    if (mounted) {
      if (data != null) {
        _userData = data;
        _nameController.text = _userData?['nama'] ?? '';
        _emailController.text = _userData?['email'] ?? '';
        _nomorHpController.text = _userData?['nomor_hp'] ?? '';
      } else {
        _showSnackbar(
          'Gagal memuat data profil. Silakan coba lagi.',
          isError: true,
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!mounted) return;

    if (_nameController.text.isEmpty || _nomorHpController.text.isEmpty) {
      _showSnackbar('Nama dan Nomor HP tidak boleh kosong.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updatedData = {
      'username': _nameController.text,
      'nomor_hp': _nomorHpController.text,
    };

    final success = await _apiService.updateUserProfile(updatedData);

    if (mounted) {
      if (success != null) {
        _showSnackbar('Profil berhasil diperbarui!');
        Navigator.pop(context, true);
      } else {
        _showSnackbar(
          'Gagal memperbarui profil. Silakan coba lagi.',
          isError: true,
        );
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width > 600;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.tealAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Profil Saya',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0, // Remove shadow
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _userData == null && !_isSaving
                ? FadeInDown(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            FontAwesomeIcons.circleExclamation,
                            color: Colors.red,
                            size: 60,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak dapat memuat data profil.',
                            style: GoogleFonts.poppins(),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            onPressed: _fetchUserData,
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white, // Text color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? width * 0.15 : 20,
                        vertical: 20),
                    child: FadeInUp(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // User Avatar Section
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: isLargeScreen ? 60 : 48,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(
                                    FontAwesomeIcons.userCircle,
                                    size: isLargeScreen ? 70 : 55,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text
                                      : 'Pengguna',
                                  style: GoogleFonts.poppins(
                                    fontSize: isLargeScreen ? 24 : 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _emailController.text,
                                  style: GoogleFonts.poppins(
                                    fontSize: isLargeScreen ? 16 : 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // User Information Card
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _buildTextField(
                                    controller: _nameController,
                                    label: 'Nama Lengkap / Username',
                                    icon: FontAwesomeIcons.user,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    icon: FontAwesomeIcons.envelope,
                                    readOnly: true,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _nomorHpController,
                                    label: 'Nomor Telepon',
                                    icon: FontAwesomeIcons.phone,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          // Save Changes Button
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: width,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Colors.blueAccent, Colors.lightBlue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      'Simpan Perubahan',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Remove default border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }
}