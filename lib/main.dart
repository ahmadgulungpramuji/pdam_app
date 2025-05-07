// main.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart'; // Import halaman Home
import 'tracking_page.dart'; // Import halaman Tracking
import 'temuan_kebocoran_page.dart'; // Import halaman Temuan Kebocoran

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',

      // Definisikan SEMUA named routes yang akan digunakan
      routes: {
        // Gunakan const di sini jika Widget-nya Stateless dan constructor-nya const
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),

        // >>> Hapus 'const' di sini di dalam lambda <<<
        '/home': (context) => HomePage(),
        // >>> Hapus 'const' di sini di dalam lambda <<<
        '/temuan_kebocoran': (context) => TemuanKebocoranPage(),

        // Route untuk halaman tracking. Menerima argumen kode tracking.
        '/tracking_page': (context) {
          final trackingCode =
              ModalRoute.of(context)?.settings.arguments as String?;
          if (trackingCode == null) {
            // Tetap boleh const di sini karena Scaffold dan isinya bisa const
            return Scaffold(
              appBar: AppBar(title: Text('Error')),
              body: Center(child: Text('Kode tracking tidak ditemukan.')),
            );
          }
          // >>> Pastikan TIDAK ADA 'const' di sini karena 'trackingCode' bukan const <<<
          return TrackingPage(trackingCode: trackingCode);
        },
      },
    );
  }
}
