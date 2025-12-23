// lib/login_page.dart
// ignore_for_file: unused_import, use_build_context_synchronously

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/calon_pelanggan_register_page.dart';
import 'package:pdam_app/detail_calon_pelanggan_page.dart';
import 'package:pdam_app/models/temuan_kebocoran_model.dart';
import 'package:pdam_app/register_page.dart';
import 'package:pdam_app/services/notification_service.dart';
import 'package:pdam_app/temuan_kebocoran_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- WIDGET ANIMASI ---
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

class StaggeredFadeIn extends StatelessWidget {
  final List<Widget> children;
  final int delay;
  const StaggeredFadeIn({super.key, required this.children, this.delay = 100});
  @override
  Widget build(BuildContext context) {
    return Column(
        children: List.generate(
            children.length,
            (index) =>
                FadeInAnimation(delay: delay * index, child: children[index])));
  }
}
// --- END WIDGET ANIMASI ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _trackCodeController = TextEditingController();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _isTrackingReport = false;
  bool _passwordVisible = false;

  // --- MODIFIKASI: Variabel "Ingat Saya" ---
  final _storage = const FlutterSecureStorage();
  bool _rememberMe = false; // State untuk checkbox
  // Kunci penyimpanan
  final String _storageKeyIdentifier = 'saved_identifier';
  final String _storageKeyPassword = 'saved_password';
  // --- AKHIR MODIFIKASI ---

  final String _checkBillUrl =
      'http://182.253.104.60:1818/info/info_tagihan_rekening.php';

  // --- MODIFIKASI: Panggil fungsi load saat initState ---
  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // <-- PANGGIL FUNGSI BARU INI
  }

  // --- MODIFIKASI: Fungsi baru untuk memuat kredensial ---
  Future<void> _loadSavedCredentials() async {
    try {
      // Baca semua data yang mungkin tersimpan
      final allValues = await _storage.readAll();
      final identifier = allValues[_storageKeyIdentifier];
      final password = allValues[_storageKeyPassword];

      if (identifier != null && password != null) {
        if (!mounted) return;
        setState(() {
          _identifierController.text = identifier;
          _passwordController.text = password;
          _rememberMe = true; // Set checkbox ke "true" jika data ada
        });
      }
    } catch (e) {
      log("Gagal memuat kredensial tersimpan: $e");
      // Jika gagal (misal: Keystore error), hapus saja datanya
      await _storage.deleteAll();
    }
  }
  // --- AKHIR MODIFIKASI ---

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _trackCodeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _trackReportFromLogin() async {
    final code = _trackCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showSnackbar('Masukkan kode tracking terlebih dahulu.');
      return;
    }
    setState(() => _isTrackingReport = true);

    try {
      if (code.startsWith('TK-')) {
        final TemuanKebocoran temuan = await _apiService.trackReport(code);
        _trackCodeController.clear();
        Navigator.pushNamed(context, '/detail_temuan_page', arguments: temuan);
      } else if (code.startsWith('CP-')) {
        final Map<String, dynamic> dataPendaftaran =
            await _apiService.trackCalonPelanggan(code);
        _trackCodeController.clear();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DetailCalonPelangganPage(data: dataPendaftaran),
          ),
        );
      } else {
        throw Exception(
            'Format kode tracking tidak valid. Pastikan kode diawali "TK-" atau "CP-".');
      }
    } catch (e) {
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'Periksa koneksi internet Anda.';
      } else if (e is TimeoutException) {
        errorMessage = 'Koneksi timeout. Gagal melacak laporan.';
      } else {
        errorMessage = e.toString().replaceFirst("Exception: ", "");
      }
      _showSnackbar(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isTrackingReport = false);
    }
  }

  Future<void> _reauthenticateWithFirebase() async {
    log('[LoginPage] Memulai re-otentikasi Firebase...');
    try {
      final String? customToken = await _apiService.getFirebaseCustomToken();
      if (customToken != null) {
        await FirebaseAuth.instance.signInWithCustomToken(customToken);
        log('[LoginPage] Re-otentikasi Firebase BERHASIL.');
      } else {
        throw Exception(
            'Gagal mendapatkan token otentikasi Firebase dari server.');
      }
    } catch (e) {
      log('[LoginPage] Re-otentikasi Firebase GAGAL: $e');
      if (e is SocketException) {
        throw Exception('Periksa koneksi internet Anda.');
      } else if (e is TimeoutException) {
        throw Exception('Koneksi timeout saat otentikasi.');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _login() async {
    // 1. Cek koneksi internet di awal
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      _showSnackbar(
          "Tidak ada koneksi internet. Silakan periksa jaringan Anda.",
          isError: true);
      return;
    }

    // 2. Lanjutkan proses login jika ada koneksi
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // --- MODIFIKASI: Panggil fungsi "Ingat Saya" ---
    // Panggil fungsi untuk menyimpan atau menghapus kredensial
    await _handleRememberMe();
    // --- AKHIR MODIFIKASI ---

    setState(() => _isLoading = true);
    try {
      // 1. Login ke Backend
      final Map<String, dynamic> responseData = await _apiService.unifiedLogin(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      final String token = responseData['token'] as String;
      final String userType = responseData['user_type'] as String;
      final Map<String, dynamic> userData =
          responseData['user'] as Map<String, dynamic>;

      // 2. Simpan token SEMENTARA (Jika gagal nanti, kita hapus)
      await _apiService.saveToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(userData));

      // 3. Update FCM
      log("Mencoba mengirim FCM token ke server setelah login...");
      await NotificationService().sendFcmTokenToServer();

      // 4. Coba Re-auth Firebase
      try {
        await _reauthenticateWithFirebase();
      } catch (e) {
        // OPSIONAL: Jika Anda ingin login BATAL jika Firebase Error:
        /*
        await _apiService.removeToken(); // Hapus token
        throw Exception("Gagal sinkronisasi Firebase: $e"); // Lempar error agar masuk ke catch utama
        */

        // ATAU: Biarkan login tetap jalan tapi log errornya (User bisa masuk tapi chat mungkin error)
        log("Warning: Firebase auth failed, but proceeding login. Error: $e");
      }

      _showSnackbar('Login berhasil sebagai $userType!', isError: false);

      // 5. Navigasi
      if (userType == 'pelanggan') {
        Navigator.pushNamedAndRemoveUntil(
            context, '/home_pelanggan', (route) => false);
      } else if (userType == 'petugas') {
        final int petugasId = userData['id'] as int;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home_petugas',
          (route) => false,
          arguments: {'idPetugasLoggedIn': petugasId},
        );
      } else {
        _showSnackbar('Tipe pengguna tidak dikenal.', isError: true);
      }
    } catch (e) {
      // JIKA GAGAL DI TAHAP UTAMA
      // Pastikan token dihapus agar tidak terjadi kasus "Hot Reload Login"
      await _apiService.removeToken();

      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'Periksa koneksi internet Anda.';
      } else if (e is TimeoutException) {
        errorMessage = 'Koneksi timeout. Gagal login.';
      } else {
        errorMessage = e.toString().replaceFirst("Exception: ", "");
      }
      _showSnackbar(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MODIFIKASI: Fungsi baru untuk menyimpan/menghapus kredensial ---
  Future<void> _handleRememberMe() async {
    try {
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text;

      if (_rememberMe) {
        // Jika dicentang, SIMPAN dengan aman
        await _storage.write(key: _storageKeyIdentifier, value: identifier);
        await _storage.write(key: _storageKeyPassword, value: password);
        log("Kredensial disimpan dengan aman.");
      } else {
        // Jika tidak dicentang, HAPUS
        await _storage.delete(key: _storageKeyIdentifier);
        await _storage.delete(key: _storageKeyPassword);
        log("Kredensial tersimpan dihapus.");
      }
    } catch (e) {
      log("Error saat menyimpan/menghapus kredensial: $e");
      // Tidak perlu mengganggu pengguna, cukup log
    }
  }
  // --- AKHIR MODIFIKASI ---

  Future<void> _forgotPassword() async {
    final identifierController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Reset Password"),
        content: TextField(
          controller: identifierController,
          decoration: InputDecoration(hintText: "Masukkan Email Anda"),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              final email = identifierController.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  final connectivityResult =
                      await (Connectivity().checkConnectivity());
                  if (connectivityResult == ConnectivityResult.none) {
                    throw SocketException("Tidak ada koneksi internet.");
                  }

                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);
                  _showSnackbar(
                    "Link reset password telah dikirim ke email Anda. Silakan periksa.",
                    isError: false,
                  );
                } on FirebaseAuthException catch (e) {
                  _showSnackbar("Gagal: ${e.message}", isError: true);
                } catch (e) {
                  String errorMessage;
                  if (e is SocketException) {
                    errorMessage = 'Periksa koneksi internet Anda.';
                  } else if (e is TimeoutException) {
                    errorMessage = 'Koneksi timeout.';
                  } else {
                    errorMessage = e.toString().replaceFirst("Exception: ", "");
                  }
                  _showSnackbar(errorMessage, isError: true);
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              } else {
                _showSnackbar("Harap masukkan alamat email yang valid.",
                    isError: true);
              }
            },
            child: Text("Kirim"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchBillUrl() async {
    final Uri url = Uri.parse(_checkBillUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showSnackbar(
        'Tidak dapat membuka tautan. Pastikan Anda memiliki aplikasi browser.',
        isError: true,
      );
    }
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);
    const Color textColor = Color(0xFF212529);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            FadeInAnimation(
              delay: 100,
              child: Image.asset('assets/images/logo.png', height: 80),
            ),
            const SizedBox(height: 16),
            FadeInAnimation(
              delay: 200,
              child: Text(
                'Selamat Datang',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeInAnimation(
              delay: 300,
              child: Text(
                _currentPage == 0
                    ? "Login atau daftar sambungan baru."
                    : "Lacak laporan atau akses layanan cepat.",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeInAnimation(
              delay: 400,
              child: _buildSwipeHint(primaryColor),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildLoginPageContent(primaryColor),
                  _buildTrackingPageContent(primaryColor),
                ],
              ),
            ),
            _buildPageIndicator(primaryColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPageContent(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        children: [
          FadeInAnimation(
            delay: 500,
            child: _buildLoginForm(primaryColor),
          ),
          const SizedBox(height: 24),
          FadeInAnimation(delay: 600, child: _buildSectionDivider("ATAU")),
          const SizedBox(height: 24),
          FadeInAnimation(
            delay: 700,
            child: _buildActionCard(
              icon: Ionicons.person_add_outline,
              iconColor: Colors.blue.shade700,
              title: "Daftar Sambungan Baru",
              subtitle: "Ajukan pemasangan untuk pelanggan baru.",
              onTap: () => _navigateTo(const CalonPelangganRegisterPage()),
            ),
          ),
          const SizedBox(height: 16),
          FadeInAnimation(
            delay: 800,
            child: _buildRegisterFooter(primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(Color primaryColor) {
    // --- MODIFIKASI: Dibungkus dengan AutofillGroup ---
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _identifierController,
              decoration: _inputDecoration("ID PDAM / No. HP / Email",
                  Ionicons.person_circle_outline, primaryColor),

              // --- PERBAIKAN (AUTOFIL) ---
              keyboardType: TextInputType.emailAddress, // 1. Keyboard email
              autofillHints: const [
                AutofillHints.username
              ], // 2. Petunjuk Autofill
              // --- AKHIR PERBAIKAN ---

              validator: (val) => val == null || val.isEmpty
                  ? 'Kolom ini tidak boleh kosong'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: _inputDecoration(
                      "Password", Ionicons.lock_closed_outline, primaryColor)
                  .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible
                        ? Ionicons.eye_outline
                        : Ionicons.eye_off_outline,
                    color: primaryColor,
                  ),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
              obscureText: !_passwordVisible,

              // --- PERBAIKAN (AUTOFIL) ---
              autofillHints: const [
                AutofillHints.password
              ], // 3. Petunjuk Autofill
              // --- AKHIR PERBAIKAN ---

              validator: (val) => val == null || val.isEmpty
                  ? 'Password tidak boleh kosong'
                  : null,
            ),

            // --- AWAL PERUBAHAN: Menggabungkan "Ingat Saya" dan "Lupa Password?" ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bagian "Ingat Saya" (dibuat ringkas)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (newValue) {
                        if (newValue == null) return;
                        setState(() {
                          _rememberMe = newValue;
                        });
                      },
                      activeColor: primaryColor,
                      visualDensity:
                          VisualDensity.compact, // Mengurangi padding
                      materialTapTargetSize: MaterialTapTargetSize
                          .shrinkWrap, // Mengurangi area tap
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _rememberMe = !_rememberMe; // Toggle saat teks di-tap
                        });
                      },
                      // Tambahkan padding kecil di sini jika teks terlalu dekat checkbox
                      // padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        "Ingat Saya",
                        style: GoogleFonts.manrope(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),

                // Bagian "Lupa Password?"
                TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  // Mengurangi padding default TextButton agar lebih sejajar
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Lupa Password?',
                    style: GoogleFonts.manrope(
                        color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            // --- AKHIR PERUBAHAN ---

            // SizedBox ini sebelumnya ada di bawah CheckboxListTile,
            // kita biarkan untuk memberi jarak ke tombol LOGIN
            const SizedBox(height: 12),
            _GradientButton(
              onPressed: _isLoading || _isTrackingReport ? null : _login,
              isLoading: _isLoading,
              text: 'LOGIN',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingPageContent(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: StaggeredFadeIn(
        delay: 150,
        children: [
          _buildTrackingForm(primaryColor),
          const SizedBox(height: 24),
          _buildActionCard(
            icon: Ionicons.create_outline,
            iconColor: Colors.orange.shade700,
            title: "Buat Laporan Kebocoran",
            subtitle: "Laporkan jika menemukan kebocoran air.",
            onTap: () => _navigateTo(const TemuanKebocoranPage()),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Ionicons.wallet_outline,
            iconColor: Colors.green.shade700,
            title: "Cek Tagihan Anda",
            subtitle: "Lihat informasi tagihan rekening air.",
            onTap: _launchBillUrl,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingForm(Color primaryColor) {
    return Column(
      children: [
        TextFormField(
          controller: _trackCodeController,
          onChanged: (text) {
            setState(() {});
          },
          decoration: _inputDecoration("Masukkan Kode Lacak (TK- atau CP-)",
              Ionicons.search_outline, primaryColor),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _GradientButton(
          onPressed: (_trackCodeController.text.trim().isEmpty ||
                  _isTrackingReport ||
                  _isLoading)
              ? null
              : _trackReportFromLogin,
          isLoading: _isTrackingReport,
          text: 'LACAK LAPORAN',
        ),
      ],
    );
  }

  Widget _buildActionCard(
      {required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.manrope(
                            color: Colors.grey.shade700, fontSize: 13)),
                  ]),
            ),
            const Icon(Ionicons.chevron_forward, color: Colors.grey, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _buildRegisterFooter(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Sudah terdaftar sebagai pelanggan PDAM?",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(color: Colors.grey.shade800, fontSize: 15),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Ionicons.key_outline),
          label: Text(
            'Aktifkan Akun Anda Di Sini',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed:
              _isLoading ? null : () => _navigateTo(const RegisterPage()),
        ),
      ],
    );
  }

  Widget _buildSectionDivider(String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            text,
            style: GoogleFonts.manrope(
                color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildPageIndicator(Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 8.0,
          width: _currentPage == index ? 24.0 : 8.0,
          decoration: BoxDecoration(
            color: _currentPage == index ? primaryColor : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

  Widget _buildSwipeHint(Color primaryColor) {
    return InkWell(
      onTap: () {
        _pageController.animateToPage(
          _currentPage == 0 ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      },
      borderRadius: BorderRadius.circular(30.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 16.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentPage == 0 ? 'Layanan Cepat' : 'Login Pelanggan',
              style: GoogleFonts.manrope(
                color: primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Ionicons.swap_horizontal,
              size: 22,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      String label, IconData icon, Color primaryColor) {
    return InputDecoration(
      hintText: label,
      hintStyle: GoogleFonts.manrope(color: Colors.grey.shade600, fontSize: 15),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 18.0, right: 12.0),
        child: Icon(icon, color: primaryColor, size: 22),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    );
  }
}

// Widget Bantuan untuk Tombol Gradien
class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;

  const _GradientButton({
    required this.onPressed,
    required this.text,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color secondaryColor = Color(0xFF00B4D8);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      text,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
