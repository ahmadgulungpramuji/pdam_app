// main.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/home_pelanggan_page.dart';
import 'package:intl/date_symbol_data_local.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // <-- Pastikan baris ini ada
  await initializeDateFormatting('id_ID', null); // <-- Tambahkan baris ini
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

        // MODIFIED ROUTE FOR /home_petugas
        '/home_petugas': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          int petugasId;

          if (arguments is Map<String, dynamic> &&
              arguments.containsKey('idPetugasLoggedIn')) {
            petugasId = arguments['idPetugasLoggedIn'] as int;
          } else if (arguments is int) {
            // Fallback if only an int is passed directly, though Map is preferred for clarity
            petugasId = arguments;
          } else {
            // Fallback or error handling if argument is not passed or incorrect
            // For now, let's throw an error or navigate to login.
            // It's better to ensure the argument is always passed from LoginPage.
            // If you want a default for testing, you can use a default ID,
            // but this is not recommended for production.
            // Example: petugasId = 0; // Default or placeholder
            print(
              'Error: idPetugasLoggedIn not provided for /home_petugas route. Navigating to login.',
            );
            // Optionally, navigate back or to an error page or login
            // WidgetsBinding.instance.addPostFrameCallback((_) {
            //   Navigator.of(context).pushReplacementNamed('/login');
            // });
            // return const Scaffold(body: Center(child: Text("Error: Missing Petugas ID")));
            // For simplicity in this example, we'll assume login page will always pass it.
            // If it can be null, HomePetugasPage needs to handle null idPetugasLoggedIn
            // or you need a different flow.
            // For now, throwing an error to make it explicit.
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
        '/tracking_page': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          String? kodeTracking;
          if (arguments is Map<String, dynamic> &&
              arguments.containsKey('kodeTracking')) {
            kodeTracking = arguments['kodeTracking'] as String?;
          } else if (arguments is String?) {
            kodeTracking = arguments;
          }
          // If kodeTracking is still null, TrackingPage should handle it (e.g., show a form to enter code)
          return TrackingPage(kodeTracking: kodeTracking);
        },
        '/temuan_kebocoran': (context) => const TemuanKebocoranPage(),

        // Tambahkan rute lain jika ada
      },
      // Optional: Add onUnknownRoute for better error handling of undefined routes
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
