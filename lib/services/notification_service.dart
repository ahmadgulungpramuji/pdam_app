// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pdam_app/api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log("Menangani notifikasi background: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  // Stream untuk memberitahu UI bahwa notifikasi telah di-tap
  final StreamController<Map<String, dynamic>> _onNotificationTapController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _onNotificationTapController.stream;

  // Fungsi inisialisasi utama
  Future<void> init() async {
    // 1. Meminta izin notifikasi dari pengguna
    await _firebaseMessaging.requestPermission();

    // 2. Inisialisasi untuk notifikasi lokal (saat app di foreground)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _onNotificationTapController.add(jsonDecode(response.payload!));
        }
      },
    );

    // 3. Setup semua listener notifikasi
    _setupListeners();
  }

  void _setupListeners() {
    // Saat aplikasi sedang dibuka (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log(
        'Notifikasi diterima saat foreground: ${message.notification?.title}',
      );
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Saat notifikasi di-tap dan membuka aplikasi dari background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('Notifikasi dibuka dari background: ${message.data}');
      _onNotificationTapController.add(message.data);
    });

    // Handler untuk notifikasi saat aplikasi ditutup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Cek jika aplikasi dibuka dari notifikasi saat ditutup (terminated)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        log('Notifikasi dibuka dari terminated: ${message.data}');
        _onNotificationTapController.add(message.data);
      }
    });
  }

  // Menampilkan notifikasi lokal menggunakan flutter_local_notifications
  void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pdam_app_channel', // ID channel
      'Notifikasi Penting',
      channelDescription: 'Channel untuk notifikasi status laporan PDAM',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Fungsi untuk mendapatkan FCM token dan mengirimkannya ke backend Laravel Anda
  Future<void> sendFcmTokenToServer() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      log("FCM Token Perangkat: $token");
      try {
        // Panggil API untuk menyimpan token.
        await _apiService.updateFcmToken(
          token,
        ); // Kita akan buat method ini di ApiService
        log("FCM Token berhasil dikirim ke server.");
      } catch (e) {
        log("Gagal mengirim FCM token ke server: $e");
      }
    }
  }

  void dispose() {
    _onNotificationTapController.close();
  }
}
