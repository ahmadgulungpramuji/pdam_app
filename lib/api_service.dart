// api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Ganti dengan Base URL API Anda
  final String baseUrl = 'http://192.168.0.107:8000/api';

  // Fungsi untuk menyimpan token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Fungsi untuk mendapatkan token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Fungsi untuk menghapus token (logout)
  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<http.Response> trackReport(String trackingCode) async {
    final headers = {'Accept': 'application/json'};
    // Endpoint sesuai dengan route backend yang baru
    final url = Uri.parse('$baseUrl/track/$trackingCode');
    // Menggunakan GET karena hanya mengambil data, tidak perlu body
    return await http.get(url, headers: headers);
  }

  // Helper untuk membuat header dengan token (jika diperlukan di request lain)
  Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Fungsi Fetch Cabangs
  Future<http.Response> fetchCabangs() async {
    // Cabangs tidak memerlukan token untuk diakses (berdasarkan controller TemuanKebocoranPage)
    final headers = {'Accept': 'application/json'};
    final url = Uri.parse('$baseUrl/cabangs');
    return await http.get(url, headers: headers);
  }

  // Fungsi Register Pelanggan
  Future<http.Response> registerPelanggan({
    required String username,
    required String email,
    required String password,
    required String nomorHp,
    required int idCabang,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final url = Uri.parse(
      '$baseUrl/pelanggan',
    ); // Spesifik ke endpoint pelanggan
    final body = jsonEncode({
      'username': username,
      'email': email,
      'password': password,
      'nomor_hp': nomorHp,
      'id_cabang': idCabang,
    });
    return await http.post(url, headers: headers, body: body);
  }

  // Fungsi Create ID PDAM
  Future<http.Response> createIdPdam({
    required String nomor,
    required int idPelanggan,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final url = Uri.parse('$baseUrl/id-pdam');
    final body = jsonEncode({'nomor': nomor, 'id_pelanggan': idPelanggan});
    return await http.post(url, headers: headers, body: body);
  }

  // Fungsi Login Pelanggan
  Future<http.Response> loginUser({
    required String email,
    required String password,
    required String userType, // 'pelanggan' atau 'petugas'
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final String loginEndpoint;
    if (userType == 'pelanggan') {
      loginEndpoint =
          '$baseUrl/pelanggan/login'; // Menggunakan endpoint spesifik pelanggan
    } else if (userType == 'petugas') {
      loginEndpoint =
          '$baseUrl/petugas/login'; // Menggunakan endpoint spesifik petugas
    } else {
      throw ArgumentError('Tipe pengguna tidak valid: $userType');
    }
    final url = Uri.parse(loginEndpoint);
    final body = jsonEncode({'email': email, 'password': password});
    return await http.post(url, headers: headers, body: body);
  }

  // Fungsi Logout
  Future<http.Response> logoutUser() async {
    final headers = await getHeaders(); // Membutuhkan token untuk logout
    final url = Uri.parse('$baseUrl/logout');
    return await http.post(url, headers: headers);
  }
}
