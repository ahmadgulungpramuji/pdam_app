import 'package:flutter_test/flutter_test.dart';
import 'package:pdam_app/main.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/pages/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Baris ini penting untuk memastikan platform channel siap untuk di-mock
  // sebelum pengujian widget dijalankan.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test untuk skenario saat aplikasi dibuka pertama kali
  testWidgets('Displays WelcomePage when app is opened for the first time',
      (WidgetTester tester) async {
    // Atur SharedPreferences untuk mensimulasikan belum pernah melihat welcome screen
    SharedPreferences.setMockInitialValues({
      'hasSeenWelcomeScreen': false,
    });

    // Bangun aplikasi tanpa parameter
    await tester.pumpWidget(const MyApp());

    // Tunggu hingga semua frame selesai (termasuk navigasi dari AuthCheckPage)
    await tester.pumpAndSettle();

    // Verifikasi bahwa WelcomePage yang tampil.
    expect(find.byType(WelcomePage), findsOneWidget);
    // Verifikasi bahwa LoginPage TIDAK tampil.
    expect(find.byType(LoginPage), findsNothing);
  });

  // Test untuk skenario saat aplikasi sudah pernah dibuka sebelumnya
  testWidgets('Displays LoginPage when app has been opened before',
      (WidgetTester tester) async {
    // Atur SharedPreferences untuk mensimulasikan sudah pernah melihat welcome screen
    SharedPreferences.setMockInitialValues({
      'hasSeenWelcomeScreen': true,
      // 'user_token' bisa null atau tidak ada untuk mengarah ke login
    });

    // Bangun aplikasi tanpa parameter
    await tester.pumpWidget(const MyApp());

    // Tunggu hingga semua frame selesai
    await tester.pumpAndSettle();

    // Verifikasi bahwa LoginPage yang tampil.
    expect(find.byType(LoginPage), findsOneWidget);
    // Verifikasi bahwa WelcomePage TIDAK tampil.
    expect(find.byType(WelcomePage), findsNothing);
  });
}

