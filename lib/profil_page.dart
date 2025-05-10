// profil_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan import

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  TextEditingController _nameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();
  // Tambahkan controller lain jika ada, misal alamat

  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getUserProfile();
    if (mounted) {
      setState(() {
        _userData = data;
        if (data != null) {
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text =
              data['phone_number'] ?? ''; // Sesuaikan dengan field dari API
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    Map<String, String> updatedData = {
      'name': _nameController.text,
      'email': _emailController.text, // Jika email bisa diubah
      'phone_number': _phoneController.text,
      // tambahkan field lain
    };

    try {
      final response = await _apiService.updateUserProfile(updatedData);
      if (!mounted) return;

      if (response?.statusCode == 200) {
        _showSnackbar('Profil berhasil diperbarui.', isError: false);
        await _loadUserProfile(); // Muat ulang data untuk memastikan sinkron
        setState(() => _isEditing = false);
        Navigator.pop(context, true); // Kirim true untuk menandakan ada update
      } else {
        final responseData = jsonDecode(response!.body);
        _showSnackbar(
          'Gagal memperbarui profil: ${responseData['message'] ?? response.reasonPhrase}',
        );
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly || !_isEditing,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: readOnly || !_isEditing,
          fillColor: (readOnly || !_isEditing) ? Colors.grey[100] : null,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pengguna'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.save_outlined : Icons.edit_outlined,
              ),
              tooltip: _isEditing ? 'Simpan' : 'Edit Profil',
              onPressed: () {
                if (_isEditing) {
                  _updateUserProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
            ),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.cancel_outlined),
              tooltip: 'Batal Edit',
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset fields ke data awal jika ada perubahan yang belum disimpan
                  if (_userData != null) {
                    _nameController.text = _userData!['name'] ?? '';
                    _emailController.text = _userData!['email'] ?? '';
                    _phoneController.text = _userData!['phone_number'] ?? '';
                  }
                });
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userData == null
              ? const Center(child: Text('Gagal memuat data profil.'))
              : RefreshIndicator(
                onRefresh: _loadUserProfile,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 50,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person_outline,
                            size: 50,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                          ),
                          // backgroundImage: NetworkImage(_userData!['profile_picture_url'] ?? ''), // Jika ada URL gambar profil
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isEditing
                              ? 'Edit Profil Anda'
                              : (_userData!['name'] ?? 'Nama Pengguna'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _userData!['email'] ?? 'email@example.com',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 30),
                        _buildProfileField(
                          icon: Icons.person_outline,
                          label: 'Nama Lengkap',
                          controller: _nameController,
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? 'Nama tidak boleh kosong'
                                      : null,
                        ),
                        _buildProfileField(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          readOnly: true, // Email biasanya tidak bisa diubah
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Email tidak boleh kosong';
                            if (!value.contains('@'))
                              return 'Email tidak valid';
                            return null;
                          },
                        ),
                        _buildProfileField(
                          icon: Icons.phone_outlined,
                          label: 'Nomor Telepon',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? 'Nomor telepon tidak boleh kosong'
                                      : null,
                        ),
                        // Tambahkan field lain seperti alamat, dll.
                        // _buildProfileField(
                        //   icon: Icons.location_city_outlined,
                        //   label: 'Alamat',
                        //   controller: _addressController,
                        // ),
                        const SizedBox(height: 30),
                        if (_isEditing)
                          ElevatedButton.icon(
                            icon:
                                _isLoading
                                    ? const SizedBox.shrink()
                                    : const Icon(Icons.save_alt_outlined),
                            label:
                                _isLoading
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text('Simpan Perubahan'),
                            onPressed: _isLoading ? null : _updateUserProfile,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
