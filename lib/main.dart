// lib/main.dart
// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/calon_pelanggan_register_page.dart';
import 'package:pdam_app/cek_tunggakan_page.dart';
import 'package:pdam_app/chat_page.dart';
import 'package:pdam_app/detail_temuan_page.dart';
import 'package:pdam_app/home_pelanggan_page.dart';
import 'package:pdam_app/home_petugas_page.dart';
import 'package:pdam_app/lacak_laporan_saya_page.dart';
import 'package:pdam_app/lapor_foto_meter_page.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/models/temuan_kebocoran_model.dart';
import 'package:pdam_app/pages/notifikasi_page.dart';
import 'package:pdam_app/pages/welcome_page.dart';
import 'package:pdam_app/profil_page.dart';
import 'package:pdam_app/register_page.dart';
import 'package:pdam_app/services/notification_service.dart';
import 'package:pdam_app/buat_laporan_page.dart';
import 'package:pdam_app/temuan_kebocoran_page.dart';
import 'package:pdam_app/tracking_page.dart';
import 'package:pdam_app/view_profil_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdam_app/home_admin_cabang_page.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id_ID', null);
  await NotificationService().init();

  NotificationService().onNotificationTap.listen((data) {
    log('--- DEBUG NOTIFIKASI DARI HP ---');
    log('Notifikasi di-tap dengan data: ${jsonEncode(data)}');
    log('---------------------------------');

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      log('Navigator state is null. Cannot navigate.');
      return;
    }

    final String? type = data['type'];
    final String? status = data['status'];

    log('Notifikasi Type: $type');
    log('Notifikasi Status: $status');

    if (type == 'lapor_foto_water_meter_status') {
      log('Jenis notifikasi cocok: lapor_foto_water_meter_status');
      if (status == 'ditolak') {
        log('Status ditolak, mengarahkan ke /lapor_foto_meter');
        navigator.pushNamed('/lapor_foto_meter');
      } else if (status == 'dikonfirmasi') {
        log('Status dikonfirmasi, mengarahkan ke /notifikasi_page');
        navigator.pushNamedAndRemoveUntil('/notifikasi_page', (route) => false);
      } else {
        log('Status tidak dikenal: $status. Tidak ada navigasi.');
      }
    } else if (data.containsKey('reference_id')) {
      final pengaduanId = int.tryParse(data['reference_id'] ?? '');
      log('Jenis notifikasi cocok: Pengaduan (reference_id)');
      if (pengaduanId != null) {
        log('Pengaduan ID: $pengaduanId. Mengarahkan ke /lacak_laporan_saya');
        navigator.pushNamed(
          '/lacak_laporan_saya',
          arguments: {'pengaduan_id': pengaduanId},
        );
      } else {
        log('reference_id tidak valid: ${data['reference_id']}. Tidak ada navigasi.');
      }
    } else {
      log('Jenis notifikasi tidak cocok dengan kondisi yang ada.');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PDAM App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          // <--- Tanda kurung '(' pembuka di sini
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        ),
      ),
      initialRoute:
          '/auth_check', // Menggunakan AuthCheckPage sebagai rute awal
      routes: {
        '/auth_check': (context) => const AuthCheckPage(),
        '/': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
        '/welcome': (context) => const WelcomePage(),
        '/register': (context) => const RegisterPage(),
        '/home_admin_cabang': (context) => const HomeAdminCabangPage(),
        '/home_petugas': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          int petugasId;
          if (arguments is Map<String, dynamic> &&
              arguments.containsKey('idPetugasLoggedIn')) {
            petugasId = arguments['idPetugasLoggedIn'] as int;
          } else if (arguments is int) {
            petugasId = arguments;
          } else {
            throw FlutterError(
                'HomePetugasPage requires an idPetugasLoggedIn argument.');
          }
          return HomePetugasPage(idPetugasLoggedIn: petugasId);
        },
        '/home_pelanggan': (context) => const HomePelangganPage(),
        '/buat_laporan': (context) => const BuatLaporanPage(),
        '/lacak_laporan_saya': (context) => const LacakLaporanSayaPage(),
        '/cek_tunggakan': (context) => const CekTunggakanPage(),
        '/lapor_foto_meter': (context) => const LaporFotoMeterPage(),
        '/view_profil': (context) => const ViewProfilPage(),
        '/profil_page': (context) => const ProfilPage(),
        '/register_calon_pelanggan': (context) =>
            const CalonPelangganRegisterPage(),
        '/detail_temuan_page': (context) {
          final temuan =
              ModalRoute.of(context)!.settings.arguments as TemuanKebocoran;
          return DetailTemuanPage(temuanKebocoran: temuan);
        },
        '/tracking_page': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          String? kodeTracking;
          if (arguments is Map<String, dynamic> &&
              arguments.containsKey('kodeTracking')) {
            kodeTracking = arguments['kodeTracking'] as String?;
          } else if (arguments is String?) {
            kodeTracking = arguments;
          }
          return TrackingPage(kodeTracking: kodeTracking);
        },
        '/temuan_kebocoran': (context) => const TemuanKebocoranPage(),
        '/notifikasi_page': (context) => const NotifikasiPage(),
        '/chat_page': (context) {
          final userData = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return ChatPage(userData: userData ?? {});
        },
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Halaman Tidak Ditemukan')),
            body: Center(
              child: Text('Rute "${settings.name}" tidak ditemukan.'),
            ),
          ),
        );
      },
    );
  }
}

// Widget untuk memeriksa status login saat aplikasi dibuka
class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');
    final hasSeenWelcome = prefs.getBool('hasSeenWelcomeScreen') ?? false;

    if (!mounted) return;

    if (!hasSeenWelcome) {
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }

    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final apiService = ApiService();
      final userProfile = await apiService.getUserProfile();

      if (!mounted) return;

      if (userProfile != null) {
        final userDataString = prefs.getString('user_data');
        if (userDataString != null) {
          final userData = jsonDecode(userDataString) as Map<String, dynamic>;

          // --- PERBAIKAN LOGIKA AUTO LOGIN ---

          // 1. Cek Admin Cabang (Biasanya punya kolom 'jabatan')
          if (userData.containsKey('jabatan')) {
            Navigator.pushReplacementNamed(context, '/home_admin_cabang');
          }
          // 2. Cek Petugas (Punya kolom 'is_active')
          else if (userData.containsKey('is_active')) {
            final int petugasId = userData['id'] as int;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    HomePetugasPage(idPetugasLoggedIn: petugasId),
              ),
            );
          }
          // 3. Sisanya adalah Pelanggan
          else {
            Navigator.pushReplacementNamed(context, '/home_pelanggan');
          }
        } else {
          // Fallback jika user_data tidak ditemukan
          await apiService.logout();
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // Token tidak valid (kedaluwarsa atau lainnya)
        await ApiService().logout();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // Terjadi error (misal: tidak ada internet), arahkan ke login
      log("Error saat cek status login: $e");
      await ApiService().logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
