import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pdam_app/calon_pelanggan_register_page.dart';
import 'package:pdam_app/detail_temuan_page.dart';
import 'package:pdam_app/lapor_foto_meter_page.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/home_pelanggan_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdam_app/buat_laporan_page.dart';
import 'package:pdam_app/services/notification_service.dart';
import 'package:pdam_app/lacak_laporan_saya_page.dart';
import 'package:pdam_app/cek_tunggakan_page.dart';
import 'package:pdam_app/chat_page.dart'; // <-- Pastikan ini diimpor
import 'package:pdam_app/pages/notifikasi_page.dart'; // <-- Pastikan ini diimpor
import 'package:pdam_app/view_profil_page.dart'; // <-- Pastikan ini diimpor

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:pdam_app/home_petugas_page.dart';
import 'package:pdam_app/models/temuan_kebocoran_model.dart';
import 'package:pdam_app/profil_page.dart';
import 'package:pdam_app/tracking_page.dart';
import 'package:pdam_app/temuan_kebocoran_page.dart';
import 'package:pdam_app/register_page.dart';
import 'package:pdam_app/pages/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id_ID', null);
  await NotificationService().init();

  NotificationService().onNotificationTap.listen((data) {
    log("Notifikasi di-tap dengan data: $data");
    if (data.containsKey('pengaduan_id')) {
      final pengaduanId = int.tryParse(data['pengaduan_id'] ?? '');
      if (pengaduanId != null) {
        navigatorKey.currentState?.pushNamed(
          '/lacak_laporan_saya',
          arguments: {'pengaduan_id': pengaduanId},
        );
      }
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenWelcomeScreen = prefs.getBool('hasSeenWelcomeScreen') ?? false;

  runApp(MyApp(hasSeenWelcomeScreen: hasSeenWelcomeScreen));
}

class MyApp extends StatelessWidget {
  final bool hasSeenWelcomeScreen;

  const MyApp({super.key, required this.hasSeenWelcomeScreen});

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
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        ),
      ),
      initialRoute: hasSeenWelcomeScreen ? '/login' : '/welcome',
      routes: {
        '/': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
        '/welcome': (context) => const WelcomePage(),
        '/register': (context) => const RegisterPage(),
        '/home_petugas': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          int petugasId;
          if (arguments is Map<String, dynamic> && arguments.containsKey('idPetugasLoggedIn')) {
            petugasId = arguments['idPetugasLoggedIn'] as int;
          } else if (arguments is int) {
            petugasId = arguments;
          } else {
            throw FlutterError('HomePetugasPage requires an idPetugasLoggedIn argument.');
          }
          return HomePetugasPage(idPetugasLoggedIn: petugasId);
        },
        '/home_pelanggan': (context) => const HomePelangganPage(),
        '/buat_laporan': (context) => const BuatLaporanPage(),
        '/lacak_laporan_saya': (context) => const LacakLaporanSayaPage(),
        '/cek_tunggakan': (context) => const CekTunggakanPage(),
        '/lapor_foto_meter': (context) => const LaporFotoMeterPage(),
        '/view_profil': (context) => const ViewProfilPage(), // <-- Rute yang hilang
        '/profil_page': (context) => const ProfilPage(), // Rute lama, mungkin perlu dihapus atau disesuaikan
        '/register_calon_pelanggan': (context) => const CalonPelangganRegisterPage(),
        '/detail_temuan_page': (context) {
          final temuan = ModalRoute.of(context)!.settings.arguments as TemuanKebocoran;
          return DetailTemuanPage(temuanKebocoran: temuan);
        },
        '/tracking_page': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          String? kodeTracking;
          if (arguments is Map<String, dynamic> && arguments.containsKey('kodeTracking')) {
            kodeTracking = arguments['kodeTracking'] as String?;
          } else if (arguments is String?) {
            kodeTracking = arguments;
          }
          return TrackingPage(kodeTracking: kodeTracking);
        },
        '/temuan_kebocoran': (context) => const TemuanKebocoranPage(),
        '/notifikasi_page': (context) => const NotifikasiPage(), // <-- Tambahkan jika belum ada
        '/chat_page': (context) {
           final userData = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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