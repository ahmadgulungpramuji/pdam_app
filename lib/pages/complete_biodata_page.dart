import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk SystemNavigator
import 'package:google_fonts/google_fonts.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/petugas_model.dart';
import 'package:pdam_app/home_petugas_page.dart'; // Sesuaikan import
import 'package:pdam_app/main.dart'; // Untuk navigatorKey jika perlu

class CompleteBiodataPage extends StatefulWidget {
  final Petugas petugas;

  const CompleteBiodataPage({Key? key, required this.petugas})
      : super(key: key);

  @override
  State<CompleteBiodataPage> createState() => _CompleteBiodataPageState();
}

class _CompleteBiodataPageState extends State<CompleteBiodataPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _hpController;
  late TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller. Jika null, set string kosong.
    _hpController = TextEditingController(text: widget.petugas.nomorHp ?? '');
    _emailController = TextEditingController(text: widget.petugas.email ?? '');
  }

  @override
  void dispose() {
    _hpController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Buka complete_biodata_page.dart

  Future<void> _submitBiodata() async {
    // 1. Validasi Form Frontend
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 2. Panggil API Update Profile
      // Data dikirim ke server. Jika No HP duplikat, server akan melempar error (Exception).
      await _apiService.updatePetugasProfile(data: {
        'nama': widget.petugas.nama,
        'nomor_hp': _hpController.text.trim(),
        if (_emailController.text.trim().isNotEmpty)
          'email': _emailController.text.trim(),
      });

      // 3. Sync ke Firebase (Opsional, dijalankan jika update sukses)
      try {
        await _apiService.syncUserToFirebase();
      } catch (e) {
        print("Warning: Firebase sync failed: $e");
      }

      if (!mounted) return;

      // 4. Navigasi ke Beranda (Hanya tercapai jika tidak ada error)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              HomePetugasPage(idPetugasLoggedIn: widget.petugas.id),
        ),
        (route) => false,
      );

      // Tampilkan pesan sukses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Biodata berhasil disimpan. Selamat datang!"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      // === BAGIAN PENANGANAN ERROR YANG DISESUAIKAN ===
      
      String rawError = e.toString();
      String finalErrorMessage;

      // Deteksi kata kunci error dari server (Laravel)
      // Kita cek variasi kata-kata yang mungkin muncul saat duplikat
      if (rawError.toLowerCase().contains("sudah digunakan") || 
          rawError.toLowerCase().contains("sudah terdaftar") ||
          rawError.toLowerCase().contains("taken")) {
        
        // PAKSA pesan menjadi kalimat yang Anda inginkan
        finalErrorMessage = "Nomor HP yang Anda masukan sudah terdaftar.";
        
      } else {
        // Jika errornya BUKAN masalah nomor HP (misal koneksi putus),
        // kita bersihkan pesan error bawaan agar tetap rapi.
        finalErrorMessage = rawError.replaceAll('Exception:', '').trim();
        
        // Bersihkan prefix umum seperti "Data tidak valid:"
        if (finalErrorMessage.startsWith("Data tidak valid:")) {
           finalErrorMessage = finalErrorMessage.replaceAll("Data tidak valid:", "").trim();
        }
        
        // Hapus tanda strip (-) di awal jika ada
        if (finalErrorMessage.startsWith("-")) {
          finalErrorMessage = finalErrorMessage.substring(1).trim();
        }
      }

      // Tampilkan SnackBar dengan pesan yang sudah difilter
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(finalErrorMessage), 
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // WillPopScope untuk menangani tombol Back fisik
    return WillPopScope(
      onWillPop: () async {
        // Opsi B: Menutup aplikasi jika ditekan back
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Lengkapi Biodata",
              style: GoogleFonts.poppins(color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false, // Hilangkan tombol back di AppBar
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(),
                const SizedBox(height: 30),
                Text(
                  "Data Kontak (Wajib Diisi)",
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Mohon lengkapi nomor HP aktif Anda agar dapat menerima notifikasi tugas.",
                  style:
                      GoogleFonts.lato(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),

                // Input No HP
                TextFormField(
                  controller: _hpController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Nomor HP (Wajib)",
                    hintText: "Contoh: 0812xxxxxxxx",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.phone_android),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nomor HP wajib diisi';
                    }
                    if (value.length < 10) {
                      return 'Nomor HP tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Input Email (Opsional)
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email (Opsional)",
                    hintText: "petugas@pdam.com",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 40),

                // Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitBiodata,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "SIMPAN & LANJUTKAN",
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          _readOnlyRow("Nama Lengkap", widget.petugas.nama),
          const Divider(),
          _readOnlyRow("NIK", widget.petugas.nik ?? '-'),
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.lato(color: Colors.grey[600])),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
