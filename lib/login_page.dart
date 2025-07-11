import 'package:flutter/material.dart';
import 'package:pdam_app/calon_pelanggan_register_page.dart';
import 'package:pdam_app/register_page.dart';
import 'package:pdam_app/temuan_kebocoran_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'models/temuan_kebocoran_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _trackCodeController = TextEditingController();
  // DIUBAH: Menggunakan controller generik untuk identifier
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _isLoading = false;
  bool _isTrackingReport = false;
  bool _passwordVisible = false;

  final String _checkBillUrl =
      'http://182.253.104.60:1818/info/info_tagihan_rekening.php';

  @override
  void initState() {
    super.initState();
    _trackCodeController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    // DIUBAH: Dispose controller yang benar
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
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _trackReportFromLogin() async {
    final code = _trackCodeController.text.trim();
    if (code.isEmpty) {
      _showSnackbar('Masukkan kode tracking terlebih dahulu.');
      return;
    }
    setState(() => _isTrackingReport = true);
    try {
      final TemuanKebocoran temuan = await _apiService.trackReport(code);
      if (!mounted) return;
      _trackCodeController.clear();
      Navigator.pushNamed(context, '/detail_temuan_page', arguments: temuan);
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString().replaceFirst("Exception: ", "");
      _showSnackbar(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isTrackingReport = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      // DIUBAH: Mengirim identifier ke service
      final Map<String, dynamic> responseData = await _apiService.unifiedLogin(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final String token = responseData['token'] as String;
      final String userType = responseData['user_type'] as String;
      final Map<String, dynamic> userData =
          responseData['user'] as Map<String, dynamic>;

      await _apiService.saveToken(token);

      if (!mounted) return;
      _showSnackbar('Login berhasil sebagai $userType!', isError: false);

      if (userType == 'pelanggan') {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home_pelanggan',
          (route) => false,
        );
      } else if (userType == 'petugas') {
        if (!mounted) return;
        final int petugasId = userData['id'] as int;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home_petugas',
          (route) => false,
          arguments: {'idPetugasLoggedIn': petugasId},
        );
      } else {
        if (!mounted) return;
        _showSnackbar('Tipe pengguna tidak dikenal.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString().replaceFirst("Exception: ", "");
      _showSnackbar(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchBillUrl() async {
    final Uri url = Uri.parse(_checkBillUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showSnackbar(
        'Tidak dapat membuka tautan cek tagihan. Pastikan Anda memiliki aplikasi browser.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),
              Icon(Ionicons.water, size: 60, color: Colors.blue.shade700),
              const SizedBox(height: 15),
              Text(
                'Selamat Datang',
                style: GoogleFonts.lato(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  Text(
                    _currentPage == 0
                        ? "Login untuk mengakses layanan PDAM"
                        : "Lacak atau buat laporan kebocoran baru",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSwipeHint(),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        key: const PageStorageKey('loginPage'),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildLoginForm(),
                      ),
                    ),
                    Center(
                      child: SingleChildScrollView(
                        key: const PageStorageKey('trackingPage'),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildTrackingSection(),
                      ),
                    ),
                  ],
                ),
              ),

              _buildPageIndicator(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextFormField(
            // DIUBAH: Menggunakan controller & dekorasi baru
            controller: _identifierController,
            decoration: _inputDecoration(
              "ID PDAM / No. HP / Email",
              Ionicons.person_circle_outline,
            ),
            keyboardType: TextInputType.text,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Kolom ini tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: _inputDecoration(
              "Password",
              Ionicons.lock_closed_outline,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Ionicons.eye_outline
                      : Ionicons.eye_off_outline,
                  color: Colors.blue.shade700,
                ),
                onPressed:
                    () => setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            obscureText: !_passwordVisible,
            validator:
                (val) =>
                    val == null || val.isEmpty
                        ? 'Password tidak boleh kosong'
                        : null,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005A9C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: _isLoading || _isTrackingReport ? null : _login,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                      : const Text(
                        'LOGIN',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Belum punya akun?",
                style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed:
                    _isLoading
                        ? null
                        : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterPage(),
                            ),
                          );
                        },
                child: const Text(
                  'Daftar di sini',
                  style: TextStyle(
                    color: Color(0xFF005A9C),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF005A9C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
                  _isLoading || _isTrackingReport
                      ? null
                      : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const CalonPelangganRegisterPage(),
                          ),
                        );
                      },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade700, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'DAFTAR PELANGGAN PDAM BARU',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextFormField(
          controller: _trackCodeController,
          decoration: _inputDecoration(
            "Masukkan Kode Tracking",
            Ionicons.search_outline,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF005A9C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed:
                (_trackCodeController.text.trim().isEmpty ||
                        _isTrackingReport ||
                        _isLoading)
                    ? null
                    : _trackReportFromLogin,
            child:
                _isTrackingReport
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                    : const Text(
                      "LACAK LAPORAN",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Ionicons.create_outline, size: 20),
            label: const Text("BUAT LAPORAN BARU"),
            onPressed:
                _isLoading || _isTrackingReport
                    ? null
                    : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TemuanKebocoranPage(),
                      ),
                    ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF005A9C),
              side: const BorderSide(color: Color(0xFF005A9C), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Ionicons.wallet_outline, size: 20),
            label: const Text("CEK TAGIHAN"),
            onPressed: _isLoading || _isTrackingReport ? null : _launchBillUrl,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              side: BorderSide(color: Colors.green.shade700, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 18.0, right: 12.0),
        child: Icon(icon, color: Colors.blue.shade700, size: 22),
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
        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5.0),
          height: 10.0,
          width: _currentPage == index ? 25.0 : 10.0,
          decoration: BoxDecoration(
            color:
                _currentPage == index
                    ? const Color(0xFF005A9C)
                    : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

  Widget _buildSwipeHint() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: 1.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Ionicons.swap_horizontal,
            size: 28,
            color: const Color(0xFF005A9C),
          ),
          const SizedBox(width: 8),
          Text(
            'Geser untuk opsi lainnya',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
