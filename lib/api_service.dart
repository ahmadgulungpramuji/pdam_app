// api_service.dart
// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Ganti dengan Base URL API Anda
  final String baseUrl = 'http://192.168.0.107:8000/api';

  // Fungsi untuk menyimpan token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_token');
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_token');
    await prefs.remove('user_data'); // Hapus juga data pengguna jika ada
    await prefs.remove('pdam_ids'); // Hapus juga pdam ids jika disimpan lokal
  }

  // ApiService.dart - Method getUserProfile
  Future<Map<String, dynamic>?> getUserProfile() async {
    // Step 1: Coba ambil token yang tersimpan lokal
    final token = await getToken();
    print(
      'ApiService DEBUG: getUserProfile - Token retrieved: ${token != null ? "Exists" : "Null"}',
    ); // DEBUG

    // Jika tidak ada token sama sekali, pengguna tidak login, kembalikan null
    if (token == null) {
      print(
        'ApiService DEBUG: getUserProfile - No token found, returning null.',
      ); // DEBUG
      return null;
    }

    // Step 2: Coba ambil data user dari cache lokal (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    String? cachedUserData = prefs.getString('user_data');

    if (cachedUserData != null) {
      try {
        // Jika cache ada dan bisa di-parse, kembalikan data dari cache
        print(
          'ApiService DEBUG: getUserProfile - Found and parsed cached data.',
        ); // DEBUG
        return jsonDecode(cachedUserData) as Map<String, dynamic>;
      } catch (e) {
        // Jika gagal parse cache (misal format berubah), hapus cache lama
        print(
          'ApiService DEBUG: getUserProfile - Error parsing cached data: $e. Removing cache.',
        ); // DEBUG
        await prefs.remove('user_data');
        // Lanjutkan untuk mengambil dari network setelah cache dihapus
      }
    }

    // Step 3: Jika tidak ada cache atau cache gagal, ambil data dari API backend
    print(
      'ApiService DEBUG: getUserProfile - Fetching profile from network.',
    ); // DEBUG
    try {
      final response = await http.get(
        // Pastikan URL endpoint ini benar sesuai dengan rute di api.php
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Authorization': 'Bearer $token', // Kirim token di header
          'Accept': 'application/json',
        },
      );

      // DEBUG: Cetak status code dan body respons API untuk diagnosis
      print(
        'ApiService DEBUG: getUserProfile - API Response Status Code: ${response.statusCode}',
      );
      print(
        'ApiService DEBUG: getUserProfile - API Response Body: ${response.body}',
      );

      // Step 4: Proses respons dari API
      if (response.statusCode == 200) {
        // Jika sukses (200 OK)
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Penting: Periksa apakah respons JSON memiliki kunci 'user'
        // Sesuai dengan method 'me' di AuthController yang mengembalikan {'user': {...}}
        if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
          // Simpan data user ke cache lokal untuk penggunaan selanjutnya
          await prefs.setString('user_data', jsonEncode(data['user']));
          print(
            'ApiService DEBUG: getUserProfile - Profile fetched successfully and cached.',
          ); // DEBUG
          return data['user'] as Map<String, dynamic>; // Kembalikan data user
        } else {
          // Jika respons 200 tapi formatnya tidak sesuai harapan
          print(
            'ApiService DEBUG: getUserProfile - 200 OK, but response format unexpected (missing "user" key or not a map).',
          ); // DEBUG
          // Mungkin perlu logout di sini juga tergantung kebijakan, tapi return null sdh cukup u/ memicu logout di Home
          return null;
        }
      } else if (response.statusCode == 401) {
        // Jika respons 401 Unauthorized (token tidak valid/expired)
        print(
          'ApiService DEBUG: getUserProfile - Received 401, token is invalid. Removing token and returning null.',
        ); // DEBUG
        await removeToken(); // Hapus token lokal karena tidak valid
        return null; // Kembalikan null untuk menandakan gagal autentikasi
      } else {
        // Jika status code lain selain 200 atau 401 (misal 404, 500, dll.)
        print(
          'ApiService DEBUG: getUserProfile - Failed with status code: ${response.statusCode}.',
        ); // DEBUG
        return null; // Kembalikan null
      }
    } catch (e) {
      // Step 5: Tangani kesalahan saat melakukan permintaan HTTP (misal, tidak ada koneksi, server down)
      print(
        'ApiService DEBUG: getUserProfile - Exception during network fetch: $e',
      ); // DEBUG
      return null; // Kembalikan null
    }
  }

  Future<http.Response?> updateUserProfile(Map<String, String> data) async {
    final token = await getToken();
    print(
      'ApiService DEBUG: getUserProfile - Token retrieved: $token',
    ); // DEBUG
    if (token == null) {
      print(
        'ApiService DEBUG: getUserProfile - No token found, returning null',
      ); // DEBUG
      return null;
    }

    // Ganti dengan endpoint update profil Anda
    final response = await http.post(
      Uri.parse('$baseUrl/user/profile/update'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      // Refresh cached user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      await getUserProfile(); // Panggil untuk refresh cache
    }
    return response;
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
      '$baseUrl/auth/register',
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
          '$baseUrl/auth/login/pelanggan'; // Menggunakan endpoint spesifik pelanggan
    } else if (userType == 'petugas') {
      loginEndpoint =
          '$baseUrl/petugas'; // Menggunakan endpoint spesifik petugas
    } else {
      throw ArgumentError('Tipe pengguna tidak valid: $userType');
    }
    final url = Uri.parse(loginEndpoint);
    final body = jsonEncode({'email': email, 'password': password});
    return await http.post(url, headers: headers, body: body);
  }

  Future<List<dynamic>> getLaporanPengaduan() async {
    final token = await getToken();
    // Implementasi API call untuk mendapatkan daftar laporan
    await Future.delayed(const Duration(seconds: 1)); // Simulasi network delay
    // Contoh data dummy
    return [
      {
        'id': 'LP001',
        'judul': 'Pipa bocor di Jl. Merdeka',
        'status': 'Sedang Diproses',
        'tanggal': '2025-05-08',
      },
      {
        'id': 'LP002',
        'judul': 'Air keruh',
        'status': 'Selesai',
        'tanggal': '2025-05-05',
      },
    ];
  }

  Future<Map<String, dynamic>> getTunggakan(String pdamId) async {
    final token = await getToken();
    // Implementasi API call ke eksternal API untuk tunggakan
    // Ini HANYA CONTOH, sesuaikan dengan API eksternal Anda
    print('Fetching tunggakan untuk ID: $pdamId');
    await Future.delayed(const Duration(seconds: 2)); // Simulasi network delay
    // Contoh data dummy
    if (pdamId == "PDAM001") {
      return {
        'id_pdam': pdamId,
        'jumlah': 150000,
        'bulan': 'April 2025',
        'jatuh_tempo': '2025-05-20',
      };
    } else if (pdamId == "PDAM002") {
      return {
        'id_pdam': pdamId,
        'jumlah': 75000,
        'bulan': 'April 2025',
        'jatuh_tempo': '2025-05-20',
      };
    }
    return {
      'id_pdam': pdamId,
      'jumlah': 0,
      'bulan': '-',
      'error': 'ID Tidak ditemukan atau belum ada tagihan',
    };
  }

  Future<http.Response> buatLaporan(
    Map<String, dynamic> dataLaporan,
    String? pdamId,
  ) async {
    final token = await getToken();
    // Ganti dengan endpoint buat laporan Anda
    final response = await http.post(
      Uri.parse('$baseUrl/laporan/buat'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        ...dataLaporan,
        'pdam_id':
            pdamId, // Sertakan pdam_id jika laporan terikat pada ID tertentu
      }),
    );
    return response;
  }
}

// Helper untuk manajemen PDAM ID secara lokal (contoh sederhana)
class PdamIdManager {
  static const String _pdamIdsKey = 'pdam_ids';

  static Future<List<String>> getPdamIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pdamIdsKey) ?? [];
  }

  static Future<void> addPdamId(String pdamId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ids = await getPdamIds();
    if (!ids.contains(pdamId) && ids.length < 5) {
      // Batasi jumlah ID misal 5
      ids.add(pdamId);
      await prefs.setStringList(_pdamIdsKey, ids);
    }
  }

  static Future<void> removePdamId(String pdamId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ids = await getPdamIds();
    ids.remove(pdamId);
    await prefs.setStringList(_pdamIdsKey, ids);
  }
}
