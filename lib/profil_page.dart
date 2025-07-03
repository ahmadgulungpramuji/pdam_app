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
  // =========================================================================
  // == SEMUA LOGIKA STATE DAN CONTROLLER TETAP SAMA (TIDAK DIUBAH) ==
  // =========================================================================
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
    final data = await _apiService.getUserProfile();
    if (mounted) {
      if (data != null) {
        setState(() {
          _userData = data;
          _nameController.text = _userData?['nama'] ?? '';
          _emailController.text = _userData?['email'] ?? '';
          _nomorHpController.text = _userData?['nomor_hp'] ?? '';
        });
      } else {
        _showSnackbar('Gagal memuat data profil. Silakan coba lagi.',
            isError: true);
      }
      setState(() => _isLoading = false);
    }
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
      'username': _nameController.text,
      'nomor_hp': _nomorHpController.text,
    };
    if (_passwordController.text.isNotEmpty) {
      updatedData['password'] = _passwordController.text;
      updatedData['password_confirmation'] =
          _passwordConfirmationController.text;
    }
    final success = await _apiService.updateUserProfile(updatedData);
    if (mounted) {
      if (success != null) {
        _showSnackbar('Profil berhasil diperbarui!');
        _passwordController.clear();
        _passwordConfirmationController.clear();
        // Perbarui data di UI setelah berhasil disimpan
        setState(() {
          _userData?['nama'] = success['nama'];
          _userData?['nomor_hp'] = success['nomor_hp'];
        });
        // Tidak perlu pop, agar pengguna bisa lihat perubahannya
        // Navigator.pop(context, true); 
      } else {
        _showSnackbar('Gagal memperbarui profil. Silakan coba lagi.',
            isError: true);
      }
      setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================================
  // == BAGIAN BUILD WIDGET (UI) YANG DIDESAIN ULANG ==
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? _buildErrorState()
              : CustomScrollView(
                  slivers: [
                    _buildHeader(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildSectionCard(
                              title: 'Data Pribadi',
                              icon: FontAwesomeIcons.solidUser,
                              delay: 200,
                              child: Column(
                                children: [
                                  _buildTextField(
                                    controller: _nameController,
                                    label: 'Nama Lengkap / Username',
                                    icon: FontAwesomeIcons.user,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    icon: FontAwesomeIcons.envelope,
                                    readOnly: true,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _nomorHpController,
                                    label: 'Nomor Telepon',
                                    icon: FontAwesomeIcons.phone,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionCard(
                              title: 'Ubah Password',
                              icon: FontAwesomeIcons.lock,
                              delay: 300,
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
                            const SizedBox(height: 32),
                            FadeInUp(
                              from: 20,
                              delay: const Duration(milliseconds: 400),
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveChanges,
                                icon: _isSaving
                                    ? Container()
                                    : const Icon(FontAwesomeIcons.solidFloppyDisk, size: 18),
                                label: _isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Simpan Perubahan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2962FF),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.circleExclamation, color: Colors.red, size: 60),
          const SizedBox(height: 12),
          Text('Tidak dapat memuat data profil.', style: GoogleFonts.poppins()),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUserData,
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF2962FF),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          _userData?['nama'] ?? 'Profil Saya',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2962FF), Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(FontAwesomeIcons.solidUserCircle,
                    size: 75, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(height: 8),
              Text(
                _userData?['email'] ?? '',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 30), // Spacer for title
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
    required int delay,
  }) {
    return FadeInUp(
      from: 20,
      delay: Duration(milliseconds: delay),
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const Divider(height: 24, thickness: 0.5),
            child,
          ],
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
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        prefixIcon: Icon(icon, color: Colors.blueAccent[400], size: 20),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent, width: 2)),
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
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        prefixIcon: Icon(FontAwesomeIcons.lock, color: Colors.blueAccent[400], size: 20),
        suffixIcon: IconButton(
          icon: Icon(
              _isPasswordVisible
                  ? FontAwesomeIcons.eyeSlash
                  : FontAwesomeIcons.eye,
              color: Colors.grey, size: 20),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent, width: 2)),
      ),
    );
  }
}