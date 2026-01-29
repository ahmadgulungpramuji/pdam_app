import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/petugas_model.dart';
import 'package:pdam_app/home_petugas_page.dart';

// --- WIDGET ANIMASI (Sama seperti di Home Pelanggan) ---
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
        vsync: this, duration: const Duration(milliseconds: 600));
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
        child: SlideTransition(position: _position, child: widget.child));
  }
}
// --- END WIDGET ANIMASI ---

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
  bool _isLoading = false;

  // Warna Tema (Sesuai Home Pelanggan)
  final Color primaryColor = const Color(0xFF0077B6);
  final Color backgroundColor = const Color(0xFFF8F9FA);
  final Color textColor = const Color(0xFF212529);

  @override
  void initState() {
    super.initState();
    _hpController = TextEditingController(text: widget.petugas.nomorHp ?? '');
  }

  @override
  void dispose() {
    _hpController.dispose();
    super.dispose();
  }

  Future<void> _submitBiodata() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Logic Update API
      await _apiService.updatePetugasProfile(data: {
        'nama': widget.petugas.nama,
        'nomor_hp': _hpController.text.trim(),
      });

      // Sync Firebase (Opsional)
      try {
        await _apiService.syncUserToFirebase();
      } catch (e) {
        print("Warning: Firebase sync failed: $e");
      }

      if (!mounted) return;

      // Navigasi ke Home Petugas
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              HomePetugasPage(idPetugasLoggedIn: widget.petugas.id),
        ),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Data berhasil disimpan. Selamat bertugas!",
              style: GoogleFonts.manrope()),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      String rawError = e.toString();
      String finalErrorMessage;

      if (rawError.toLowerCase().contains("sudah digunakan") ||
          rawError.toLowerCase().contains("sudah terdaftar") ||
          rawError.toLowerCase().contains("taken")) {
        finalErrorMessage = "Nomor HP ini sudah digunakan petugas lain.";
      } else {
        finalErrorMessage = rawError.replaceAll('Exception:', '').trim();
        if (finalErrorMessage.startsWith("Data tidak valid:")) {
          finalErrorMessage =
              finalErrorMessage.replaceAll("Data tidak valid:", "").trim();
        }
        if (finalErrorMessage.startsWith("-")) {
          finalErrorMessage = finalErrorMessage.substring(1).trim();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(finalErrorMessage, style: GoogleFonts.manrope()),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Text(
            "Verifikasi Petugas",
            style: GoogleFonts.manrope(
                color: textColor, fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Animasi
                FadeInAnimation(
                  delay: 100,
                  child: Center(
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Ionicons.shield_checkmark_outline,
                        size: 50,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FadeInAnimation(
                  delay: 200,
                  child: Text(
                    "Lengkapi Profil Anda",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeInAnimation(
                  delay: 300,
                  child: Text(
                    "Data ini diperlukan untuk aktivasi akun petugas dan penerimaan tugas lapangan.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Info Card (Tugas Petugas) - Sesuai Permintaan
                FadeInAnimation(
                  delay: 400,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.blue.shade100, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Ionicons.information_circle,
                            color: primaryColor, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Mengapa Nomor HP?",
                                style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Nomor HP digunakan sebagai ID unik untuk menandai Anda sebagai petugas yang aktif dan terverifikasi.",
                                style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Data Read-Only (Nama & NIK)
                FadeInAnimation(
                  delay: 500,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildReadOnlyItem("Nama Petugas", widget.petugas.nama),
                        const Divider(height: 24),
                        _buildReadOnlyItem(
                            "NIK / NIP", widget.petugas.nik ?? '-'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Form Input HP
                FadeInAnimation(
                  delay: 600,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nomor WhatsApp Aktif",
                        style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _hpController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600, color: textColor),
                        decoration: InputDecoration(
                          hintText: "Contoh: 0812xxxxxxxx",
                          hintStyle: GoogleFonts.manrope(
                              color: Colors.grey.shade400),
                          prefixIcon: Icon(Ionicons.call_outline,
                              color: primaryColor),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nomor HP wajib diisi';
                          }
                          if (value.length < 10) {
                            return 'Nomor HP tidak valid (min. 10 digit)';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 5. Tombol Submit
                FadeInAnimation(
                  delay: 700,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitBiodata,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: primaryColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3),
                            )
                          : Text(
                              "Simpan & Aktifkan Akun",
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}