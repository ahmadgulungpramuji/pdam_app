// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pdam_app/api_service.dart';

/// Handler untuk notifikasi yang masuk saat aplikasi berada di state background atau terminated.
/// HARUS berada di level atas (bukan di dalam class).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log("Menangani notifikasi background: ${message.messageId}");
}

class NotificationService {
  // Setup Singleton pattern agar hanya ada satu instance dari service ini di seluruh aplikasi.
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  /// Stream Controller tunggal untuk menangani semua aksi tap pada notifikasi.
  /// Komponen lain di aplikasi (misal: di main.dart) bisa "mendengarkan" stream ini
  /// untuk melakukan navigasi atau refresh data berdasarkan payload notifikasi.
  final StreamController<Map<String, dynamic>> _onNotificationTapController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _onNotificationTapController.stream;

  /// Fungsi inisialisasi utama untuk layanan notifikasi.
  /// Panggil fungsi ini sekali di `main.dart` saat aplikasi pertama kali dijalankan.
  Future<void> init() async {
    // 1. Meminta izin notifikasi dari pengguna (untuk iOS dan Android versi baru).
    await _firebaseMessaging.requestPermission();

    // 2. Inisialisasi plugin notifikasi lokal (untuk menampilkan notifikasi saat aplikasi terbuka).
    await _initializeLocalNotifications();

    // 3. Setup semua listener dari Firebase Messaging.
    _setupFirebaseListeners();

    // 4. Cek jika aplikasi dibuka dari notifikasi saat dalam keadaan mati (terminated).
    _handleInitialMessage();
  }

  /// Inisialisasi FlutterLocalNotificationsPlugin.
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings,
      // Handler ini dipanggil saat notifikasi LOKAL (foreground) di-tap.
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          // Payload berisi data notifikasi dalam format JSON string, perlu di-decode.
          final Map<String, dynamic> data = jsonDecode(response.payload!);
          _onNotificationTapController.add(data);
        }
      },
    );
  }

  /// Mengatur semua listener dari Firebase Cloud Messaging.
  void _setupFirebaseListeners() {
    // Listener untuk notifikasi yang masuk saat aplikasi sedang berjalan di foreground.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Notifikasi diterima saat foreground: ${message.notification?.title}');
      // Tampilkan notifikasi secara manual menggunakan flutter_local_notifications.
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Listener untuk notifikasi yang di-tap saat aplikasi berada di background.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('Notifikasi dibuka dari background: ${message.data}');
      // Langsung teruskan data payload ke stream controller tunggal.
      _onNotificationTapController.add(message.data);
    });

    // Mendaftarkan background handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Menangani notifikasi yang membuka aplikasi dari state terminated.
  void _handleInitialMessage() async {
    final RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      log('Aplikasi dibuka dari notifikasi (terminated): ${initialMessage.data}');
      // Langsung teruskan data payload ke stream controller tunggal.
      _onNotificationTapController.add(initialMessage.data);
    }
  }

  /// Menampilkan notifikasi lokal menggunakan flutter_local_notifications.
  void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pdam_app_channel', // ID channel (harus unik)
      'Notifikasi Penting',
      channelDescription:
          'Channel untuk notifikasi status laporan dan tugas PDAM',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    _localNotifications.show(
      message.hashCode, // ID unik untuk notifikasi
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      // Sertakan data dari notifikasi sebagai payload.
      payload: jsonEncode(message.data),
    );
  }

  /// Mendapatkan FCM token perangkat dan mengirimkannya ke server backend.
  Future<void> sendFcmTokenToServer() async {
    final String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      log("FCM Token Petugas Didapatkan: $token");
      try {
        log("Mencoba mengirim token ke server...");
        await _apiService.updateFcmToken(token);
        log("Panggilan API untuk update token selesai.");
      } catch (e) {
        log("GAGAL mengirim FCM token ke server: $e");
      }
    } else {
      log("Tidak bisa mendapatkan FCM Token dari Firebase.");
    }
  }

  /// Membersihkan resource saat service tidak lagi digunakan.
  void dispose() {
    _onNotificationTapController.close();
  }
}
