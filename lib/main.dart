import 'package:flutter/material.dart';
import 'package:pdam_app/calon_pelanggan_register_page.dart';
import 'package:pdam_app/detail_temuan_page.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/home_pelanggan_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdam_app/buat_laporan_page.dart';
import 'package:pdam_app/lacak_laporan_saya_page.dart';
import 'package:pdam_app/cek_tunggakan_page.dart';
import 'package:pdam_app/chat_page.dart';
import 'package:pdam_app/home_petugas_page.dart';
import 'package:pdam_app/models/temuan_kebocoran_model.dart';
import 'package:pdam_app/profil_page.dart';
import 'package:pdam_app/tracking_page.dart';
import 'package:pdam_app/temuan_kebocoran_page.dart';
import 'package:pdam_app/register_page.dart';
import 'package:pdam_app/pages/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Logic untuk menentukan rute awal
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  final prefs = await SharedPreferences.getInstance();
  // Cek jika key 'hasSeenWelcomeScreen' ada dan bernilai true. Defaultnya false.
  final bool hasSeenWelcomeScreen =
      prefs.getBool('hasSeenWelcomeScreen') ?? false;

  runApp(MyApp(hasSeenWelcomeScreen: hasSeenWelcomeScreen));
}

class MyApp extends StatelessWidget {
  final bool hasSeenWelcomeScreen;

  const MyApp({super.key, required this.hasSeenWelcomeScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      // Atur rute awal secara dinamis
      // Jika sudah pernah lihat welcome screen, langsung ke login. Jika belum, ke welcome screen.
      initialRoute: '/welcome',
      routes: {
        // Rute untuk halaman-halaman yang sudah ada
        '/': (context) => const LoginPage(), // Fallback ke login
        '/login': (context) => const LoginPage(),
        '/welcome': (context) => const WelcomePage(), // <-- RUTE HALAMAN BARU
        '/register':
            (context) => const RegisterPage(), // <-- RUTE REGISTER DIAKTIFKAN
        // MODIFIED ROUTE FOR /home_petugas (sudah ada dari kode Anda)
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
              'HomePetugasPage requires an idPetugasLoggedIn argument.',
            );
          }
          return HomePetugasPage(idPetugasLoggedIn: petugasId);
        },
        '/home_pelanggan': (context) => const HomePelangganPage(),
        '/buat_laporan': (context) => const BuatLaporanPage(),
        '/lacak_laporan_saya': (context) => const LacakLaporanSayaPage(),
        '/cek_tunggakan': (context) => const CekTunggakanPage(),
        '/chat_page': (context) => const ChatPage(),
        '/profil_page': (context) => const ProfilPage(),
        '/register_calon_pelanggan':
            (context) => const CalonPelangganRegisterPage(),

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
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder:
              (context) => Scaffold(
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
