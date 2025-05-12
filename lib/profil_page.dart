// profil_page.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan path ApiService benar

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final ApiService _apiService = ApiService();
  // Data pengguna yang dimuat dari API
  Map<String, dynamic>? _userData;
  // Controller untuk mengelola input di TextField
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController =
      TextEditingController(); // Email biasanya read-only
  final TextEditingController _nomorHpController = TextEditingController();

  // Status loading saat memuat data atau menyimpan perubahan
  bool _isLoading = true;
  // Status menyimpan perubahan
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Muat data profil saat halaman pertama kali dibuat
    _fetchUserData();
  }

  @override
  void dispose() {
    // Pastikan controller dibuang saat widget tidak lagi digunakan untuk mencegah memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _nomorHpController.dispose();
    super.dispose();
  }

  // Mengambil data profil pengguna dari API
  Future<void> _fetchUserData() async {
    if (!mounted) return; // Pastikan widget masih ada
    setState(() {
      _isLoading = true;
      _userData = null; // Reset data sebelumnya
    });

    final data = await _apiService.getUserProfile();

    if (mounted) {
      // Pastikan widget masih ada setelah async call
      if (data != null) {
        _userData = data;
        // Isi controller dengan data yang dimuat
        _nameController.text =
            _userData?['username'] ?? ''; // Asumsi field 'username'
        _emailController.text =
            _userData?['email'] ?? ''; // Asumsi field 'email'
        _nomorHpController.text =
            _userData?['nomor_hp'] ?? ''; // Asumsi field 'nomor_hp'
      } else {
        // Jika gagal memuat data (misal 401), tampilkan pesan atau kembali ke login
        // Untuk kasus ini, kita asumsikan Home page sudah menangani logout
        // Kita cukup tampilkan pesan error di sini
        _showSnackbar(
          'Gagal memuat data profil. Silakan coba lagi.',
          isError: true,
        );
        // Biarkan _userData null, fields akan kosong
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Menyimpan perubahan profil ke API
  Future<void> _saveChanges() async {
    if (!mounted) return; // Pastikan widget masih ada

    // Anda bisa tambahkan validasi di sini sebelum mengirim ke API
    // Contoh validasi sederhana:
    if (_nameController.text.isEmpty || _nomorHpController.text.isEmpty) {
      _showSnackbar('Nama dan Nomor HP tidak boleh kosong.', isError: true);
      return;
    }
    // Validasi format email atau nomor HP yang lebih kompleks bisa ditambahkan

    setState(() {
      _isSaving = true; // Set status menyimpan menjadi true
    });

    // Kumpulkan data dari controller yang sudah diubah
    final updatedData = {
      // Pastikan nama field sesuai dengan yang diharapkan backend
      'username': _nameController.text,
      // 'email': _emailController.text, // Email biasanya tidak bisa langsung diubah
      'nomor_hp': _nomorHpController.text,
    };

    // Panggil ApiService untuk mengirim update data
    // Anda perlu membuat method update di ApiService dan endpoint di backend
    final success = await _apiService.updateUserProfile(
      updatedData, // <-- Hanya mengirimkan argumen ini
    );

    if (mounted) {
      // Pastikan widget masih ada setelah async call
      if (success != null) {
        // Jika update berhasil, tampilkan pesan sukses
        _showSnackbar('Profil berhasil diperbarui!');

        // Update data lokal setelah berhasil disimpan
        // Atau panggil ulang _fetchUserData() jika respons backend tdk mengembalikan data lengkap
        setState(() {
          _userData =
              success
                  as Map<
                    String,
                    dynamic
                  >?; // Asumsi response backend mengembalikan data user terbaru
        });

        // Kembali ke halaman sebelumnya (Home)
        // Mengembalikan 'true' agar Home page tahu bahwa ada perubahan dan bisa refresh datanya
        Navigator.pop(context, true);
      } else {
        // Jika update gagal, tampilkan pesan error
        _showSnackbar(
          'Gagal memperbarui profil. Silakan coba lagi.',
          isError: true,
        );
        // Mungkin perlu penanganan error spesifik (misal 401, 422 validasi)
      }
      setState(() {
        _isSaving = false; // Set status menyimpan menjadi false
      });
    }
  }

  // Helper untuk menampilkan Snackbar
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3), // Durasi snackbar
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        // Jika sedang loading atau menyimpan, sembunyikan tombol back
        automaticallyImplyLeading: !_isLoading && !_isSaving,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(),
              ) // Tampilkan loading indicator jika memuat data
              : _userData == null && !_isSaving
              ? Center(
                // Tampilkan pesan error jika data gagal dimuat dan tidak sedang menyimpan
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Tidak dapat memuat data profil.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchUserData, // Tombol coba lagi
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                // Tampilkan form jika data sudah dimuat
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Field Nama (Username)
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap / Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Field Email (Biasanya Read-only)
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        suffixIcon: Icon(Icons.lock_outline), // Icon gembok
                      ),
                      readOnly:
                          true, // Email biasanya tidak bisa diubah langsung
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ), // Tampilan read-only
                    ),
                    const SizedBox(height: 16),
                    // Field Nomor HP
                    TextField(
                      controller: _nomorHpController,
                      decoration: InputDecoration(
                        labelText: 'Nomor Telepon',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      keyboardType:
                          TextInputType.phone, // Keyboard tipe telepon
                      // Tambahkan inputFormatters jika perlu format khusus nomor HP
                    ),
                    const SizedBox(height: 24),

                    // Tombol Simpan Perubahan
                    ElevatedButton(
                      // Nonaktifkan tombol saat sedang menyimpan
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                // Tampilkan loading indicator di tombol saat menyimpan
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                              : const Text(
                                'Simpan Perubahan',
                                style: TextStyle(fontSize: 16),
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}
