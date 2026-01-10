import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdam_app/api_service.dart';

class HomeAdminCabangPage extends StatefulWidget {
  const HomeAdminCabangPage({super.key});

  @override
  State<HomeAdminCabangPage> createState() => _HomeAdminCabangPageState();
}

class _HomeAdminCabangPageState extends State<HomeAdminCabangPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    // 1. Konfigurasi Controller WebView
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // Wajib on agar fitur web jalan
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            _controller.runJavaScript("document.body.style.zoom = '50%'");
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Error handling jika web gagal dimuat
            if (mounted) {
              setState(() {
                _isLoading = false;
                // _errorMessage = "Gagal memuat halaman: ${error.description}"; 
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Mencegah membuka link keluar (misal youtube/iklan) jika tidak diinginkan
            return NavigationDecision.navigate;
          },
        ),
      );

    // 2. Minta URL Magic Link dari Server
    try {
      // Memanggil fungsi yang kita buat sebelumnya di ApiService
      // Ini akan return: "https://domain-anda.com/auth/sso-login?token=xyz..."
      final String autoLoginUrl = await _apiService.getAutoLoginUrl();
      
      // 3. Load URL tersebut
      await _controller.loadRequest(Uri.parse(autoLoginUrl));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal terhubung ke server: $e";
        });
      }
    }
  }

  // Fungsi Logout dari Aplikasi Mobile
  Future<void> _logout() async {
    // Tampilkan dialog konfirmasi
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Keluar')),
        ],
      ),
    );

    if (confirm == true) {
      await _apiService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope digunakan agar tombol BACK di HP tidak langsung menutup aplikasi,
    // tapi kembali ke halaman web sebelumnya (history browser).
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          // Jika tidak bisa back lagi di web, tanya mau logout/keluar?
          // Atau biarkan default behaviour (Navigator.pop)
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        // AppBar tetap dipertahankan agar user bisa Logout dari Aplikasi Mobile
        appBar: AppBar(
          title: const Text("Admin Panel"),
          backgroundColor: Colors.blue[900],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(), // Tombol refresh web
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout, // Tombol Logout
            ),
          ],
        ),
        body: _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _initializeWebView();
                      },
                      child: const Text("Coba Lagi"),
                    )
                  ],
                ),
              )
            : Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Container(
                      color: Colors.white,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}