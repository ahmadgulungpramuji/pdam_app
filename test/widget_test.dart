import 'package:flutter_test/flutter_test.dart';
import 'package:pdam_app/main.dart'; // Ganti 'pdam_app' jika nama package Anda berbeda
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/pages/welcome_page.dart';

void main() {
  testWidgets('Displays WelcomePage when app is opened for the first time', (
    WidgetTester tester,
  ) async {
    // Bangun aplikasi dengan hasSeenWelcomeScreen diatur ke false.
    await tester.pumpWidget(const MyApp(hasSeenWelcomeScreen: false));

    // Verifikasi bahwa WelcomePage yang tampil.
    expect(find.byType(WelcomePage), findsOneWidget);

    // Verifikasi bahwa LoginPage TIDAK tampil.
    expect(find.byType(LoginPage), findsNothing);

    // Anda juga bisa memverifikasi berdasarkan teks spesifik.
    expect(find.text('Selamat Datang di Aplikasi PDAM'), findsOneWidget);
  });

  testWidgets('Displays LoginPage when app has been opened before', (
    WidgetTester tester,
  ) async {
    // Bangun aplikasi dengan hasSeenWelcomeScreen diatur ke true.
    await tester.pumpWidget(const MyApp(hasSeenWelcomeScreen: true));

    // Verifikasi bahwa LoginPage yang tampil.
    expect(find.byType(LoginPage), findsOneWidget);

    // Verifikasi bahwa WelcomePage TIDAK tampil.
    expect(find.byType(WelcomePage), findsNothing);
  });
}
