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
  double _loadingProgress = 0.0;
  String? _errorMessage;
  bool _desktopMode = true; 
  final ApiService _apiService = ApiService();

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const String? _mobileUserAgent = null; 

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(_desktopMode ? _desktopUserAgent : _mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onProgress: (int progress) {
            if (mounted) setState(() => _loadingProgress = progress / 100.0);
          },
          onPageFinished: (String url) async {
            await _applyViewportAndLayoutFix();
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
             print("WebView Error: ${error.description}");
          },
        ),
      );
    _loadInitialUrl();
  }

  Future<void> _loadInitialUrl() async {
    try {
      setState(() => _isLoading = true);
      final String autoLoginUrl = await _apiService.getAutoLoginUrl();
      await _controller.loadRequest(Uri.parse(autoLoginUrl));
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = "Gagal terhubung ke server.\n$e";
      });
    }
  }

  // =================================================================
  // PERBAIKAN: SIDEBAR FULL HEIGHT (MENTOK KE BAWAH)
  // =================================================================
  Future<void> _applyViewportAndLayoutFix() async {
    if (_desktopMode) {
      await _controller.runJavaScript('''
        (function() {
          // 1. ATUR VIEWPORT
          var meta = document.querySelector('meta[name="viewport"]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
          }
          meta.content = 'width=1280, initial-scale=0.1, maximum-scale=5.0, user-scalable=yes';
          
          // 2. INJEKSI CSS FIX
          var style = document.createElement('style');
          style.innerHTML = \`
            /* FIX SIDEBAR: Gunakan top & bottom 0 agar mentok */
            .sidebar, #sidebar { 
                 transform: translateX(0) !important; 
                 display: block !important;
                 visibility: visible !important;
                 width: 16rem !important;
                 
                 /* KUNCI PERBAIKAN DI SINI: */
                 position: fixed !important;
                 top: 0 !important;
                 bottom: 0 !important; /* Paksa memanjang sampai ujung bawah */
                 height: auto !important; /* Biarkan height mengikuti top-bottom */
                 
                 z-index: 9999 !important;
                 left: 0 !important;
                 
                 /* Agar bisa di-scroll jika menu sangat panjang */
                 overflow-y: auto !important; 
                 
                 /* Padding extra di bawah agar menu 'Keluar' tidak tertutup bezel HP */
                 padding-bottom: 120px !important; 
            }

            /* Scrollbar styling */
            .sidebar::-webkit-scrollbar { width: 4px; }
            .sidebar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.3); border-radius: 4px; }

            /* FIX KONTEN UTAMA */
            .main-content, .footer, main {
                 margin-left: 16rem !important; 
                 width: calc(100% - 16rem) !important; 
                 min-width: 900px !important; 
            }

            /* Hapus tombol mobile */
            #mobileMenuButton, .fa-bars { display: none !important; }
          \`;
          document.head.appendChild(style);
        })();
      ''');
    } else {
      await _controller.runJavaScript('''
        (function() {
          var meta = document.querySelector('meta[name="viewport"]');
          if (meta) meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
        })();
      ''');
    }
  }

  Future<void> _toggleDesktopMode() async {
    setState(() => _desktopMode = !_desktopMode);
    await _controller.setUserAgent(_desktopMode ? _desktopUserAgent : _mobileUserAgent);
    await _controller.reload();
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _controller.clearLocalStorage(); 
      await _apiService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Keluar Aplikasi?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya')),
              ],
            ),
          );
          if (shouldPop == true && context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Admin Panel", style: TextStyle(fontSize: 18)),
              Text(_desktopMode ? "Desktop View" : "Mobile View", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300))
            ],
          ),
          backgroundColor: Colors.blue[900],
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller.reload()),
            IconButton(icon: Icon(_desktopMode ? Icons.phone_android : Icons.desktop_windows), onPressed: _toggleDesktopMode),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
          bottom: _isLoading ? PreferredSize(preferredSize: const Size.fromHeight(4.0), child: LinearProgressIndicator(value: _loadingProgress > 0 ? _loadingProgress : null, backgroundColor: Colors.blue[800], color: Colors.orange)) : null,
        ),
        body: _errorMessage != null
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_errorMessage!, style: const TextStyle(color: Colors.red)), ElevatedButton(onPressed: _loadInitialUrl, child: const Text("Refresh"))]))
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}