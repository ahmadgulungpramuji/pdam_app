// main.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/home_pelanggan_page.dart';
// Import halaman lain yang akan dibuat
import 'package:pdam_app/buat_laporan_page.dart';
import 'package:pdam_app/lacak_laporan_saya_page.dart';
import 'package:pdam_app/cek_tunggakan_page.dart';
import 'package:pdam_app/chat_page.dart';
import 'package:pdam_app/home_petugas_page.dart';
import 'package:pdam_app/profil_page.dart';
import 'package:pdam_app/tracking_page.dart'; // Jika ada halaman tracking anonim
import 'package:pdam_app/temuan_kebocoran_page.dart'; // Sudah ada dari login
// import 'package:pdam_app/register_page.dart'; // Jika ada halaman register

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDAM App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true, // Opsional, untuk tampilan Material 3
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
      initialRoute: '/', // Atau '/login' jika ingin langsung ke login
      routes: {
        '/': (context) => const LoginPage(), // Atau SplashScreen jika ada
        '/login': (context) => const LoginPage(),
        // '/register': (context) => const RegisterPage(), // Jika ada
        '/home_petugas': (context) => const HomePetugasPage(), // Add this lin
        '/home_pelanggan': (context) => const HomePelangganPage(),
        '/buat_laporan': (context) => const BuatLaporanPage(),
        '/lacak_laporan_saya': (context) => const LacakLaporanSayaPage(),
        '/cek_tunggakan': (context) => const CekTunggakanPage(),
        '/chat_page': (context) => const ChatPage(),
        '/profil_page': (context) => const ProfilPage(),
        '/tracking_page':
            (context) => TrackingPage(
              kodeTracking:
                  ModalRoute.of(context)?.settings.arguments as String?,
            ), // Halaman tracking anonim dari login
        '/temuan_kebocoran': (context) => const TemuanKebocoranPage(),

        // Tambahkan rute lain jika ada, misal '/home_petugas'
      },
    );
  }
}
