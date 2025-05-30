// api_service.dart
// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:developer';
import 'dart:io'; // Import untuk tipe File
import 'package:http/http.dart' as http;
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:pdam_app/models/petugas_model.dart';
import 'package:pdam_app/models/tugas_model.dart'; // Import model Tugas yang baru

import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Ganti dengan Base URL API Anda
  final String baseUrl =
      'http://192.168.0.107:8000/api'; // Menggunakan URL yang Anda berikan

  final String _witAiServerAccessToken = 'BHEGRMVFUOEG45BEAVKLS3OBLATWD2JN';
  final String _witAiApiUrl = 'https://api.wit.ai/message';
  final String _witAiApiVersion = '20240514';

  Future<Map<String, dynamic>?> sendMessage(String message) async {
    if (_witAiServerAccessToken == 'YOUR_WIT_AI_SERVER_ACCESS_TOKEN') {
      log(
        'WARNING: Wit.ai Server Access Token has not been set in ApiService.',
      );
      return {
        "error": true,
        "message":
            "Token API belum diatur. Silakan atur token Wit.ai di api_service.dart.",
      };
    }

    try {
      final uri = Uri.parse(_witAiApiUrl).replace(
        queryParameters: {
          'q': message, // Pesan pengguna
          'v':
              _witAiApiVersion, // Versi API (gunakan tanggal saat Anda melatih model)
        },
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_witAiServerAccessToken'},
      );

      log('Wit.ai API Status Code: ${response.statusCode}');
      log('Wit.ai API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Sukses, parse JSON
        return jsonDecode(response.body);
      } else {
        // Gagal, mungkin token salah, batasan rate limit, dll.
        return {
          "error": true,
          "statusCode": response.statusCode,
          "message":
              "Gagal menghubungi Wit.ai API. Status: ${response.statusCode}. Body: ${response.body}",
        };
      }
    } catch (e) {
      // Tangani error jaringan atau error lainnya
      log('Error calling Wit.ai API: $e');
      return {
        "error": true,
        "message": "Terjadi kesalahan jaringan atau sistem: $e",
      };
    }
  }

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

  // --- FUNGSI BARU ATAU MODIFIKASI ---
  Future<List<Tugas>> getPetugasSemuaTugas(int idPetugas) async {
    final token =
        await getToken(); // Ambil token jika API memerlukan autentikasi
    final response = await http.get(
      Uri.parse(
        '$baseUrl/petugas/$idPetugas/tugas',
      ), // Endpoint baru dari Laravel
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      // Pastikan body adalah List
      List<Tugas> daftarTugas =
          body
              .map(
                (dynamic item) => Tugas.fromJson(item as Map<String, dynamic>),
              )
              .toList();
      return daftarTugas;
    } else {
      // Anda mungkin ingin parse error message dari response.body
      print('Error Body: ${response.body}');
      throw Exception(
        'Gagal memuat daftar tugas (Status Code: ${response.statusCode})',
      );
    }
  }

  Future<Map<String, dynamic>> postPdamId(
    String idPdam,
    String idPelanggan,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/id-pdam'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'id_pelanggan': idPelanggan, // Nilai ini perlu Anda tentukan
        'nomor': idPdam,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal menyimpan ID PDAM ke server');
    }
  }

  Future<List<dynamic>> getAllUserPdamIds() async {
    final token = await getToken();
    if (token == null) {
      print('ApiService DEBUG: getAllUserPdamIds - No token found.');
      return [];
    }

    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) {
      print('ApiService DEBUG: getAllUserPdamIds - User data not found.');
      return [];
    }

    final userData = jsonDecode(userDataString) as Map<String, dynamic>;
    final int idPelanggan = userData['id']; // Ambil ID pengguna

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/id-pdam/$idPelanggan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print(
        'ApiService DEBUG: getAllUserPdamIds - Status Code: ${response.statusCode}',
      );
      print('ApiService DEBUG: getAllUserPdamIds - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['data'] is List) {
          return responseData['data']; // Asumsi API mengembalikan format { 'data': [...] }
        } else {
          print(
            'ApiService DEBUG: getAllUserPdamIds - Unexpected response format.',
          );
          return [];
        }
      } else if (response.statusCode == 401) {
        print('ApiService DEBUG: getAllUserPdamIds - Unauthorized.');
        removeToken(); // Hapus token jika tidak valid
        return [];
      } else {
        print(
          'ApiService DEBUG: getAllUserPdamIds - Failed with status code: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      print('ApiService DEBUG: getAllUserPdamIds - Error during API call: $e');
      return [];
    }
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

  Future<Map<String, dynamic>?> updateUserProfile(
    Map<String, dynamic> updatedData,
  ) async {
    print('ApiService DEBUG: Attempting to update user profile.'); // DEBUG
    final token = await getToken();
    if (token == null) {
      print(
        'ApiService DEBUG: updateUserProfile - No token found, returning null.',
      ); // DEBUG
      return null;
    }

    try {
      // URL endpoint update profil di backend.
      // Gunakan URL dan metode HTTP yang SAMA PERSIS dengan rute di api.php (PATCH /user/profile)
      final response = await http.patch(
        // <-- Menggunakan metode PATCH
        Uri.parse('$baseUrl/user/profile'), // <-- Menggunakan URL /user/profile
        headers: {
          'Authorization': 'Bearer $token', // Kirim token di header
          'Accept': 'application/json',
          'Content-Type':
              'application/json; charset=UTF-8', // Body dalam format JSON
        },
        body: jsonEncode(updatedData), // <-- Mengirim map updatedData di body
      );

      print(
        'ApiService DEBUG: updateUserProfile - API Response Status Code: ${response.statusCode}',
      ); // DEBUG
      print(
        'ApiService DEBUG: updateUserProfile - API Response Body: ${response.body}',
      ); // DEBUG

      if (response.statusCode == 200) {
        // Backend mengembalikan data user terbaru (seperti di method me/login)
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        // Hapus cache user data lama karena data sudah berubah
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_data');

        // Backend disarankan mengembalikan data user yang sudah diperbarui dalam kunci 'user'
        if (responseData.containsKey('user') &&
            responseData['user'] is Map<String, dynamic>) {
          // Simpan data user terbaru ke cache lokal
          await prefs.setString('user_data', jsonEncode(responseData['user']));
          print(
            'ApiService DEBUG: updateUserProfile - Profile updated and cache refreshed.',
          ); // DEBUG
          return responseData['user']
              as Map<String, dynamic>; // Kembalikan data user terbaru
        } else {
          // Jika format respons 200 OK tidak sesuai harapan
          print(
            'ApiService DEBUG: updateUserProfile - 200 OK, but response format unexpected.',
          ); // DEBUG
          // Untuk amannya, kita coba fetch ulang data user setelah update
          print(
            'ApiService DEBUG: Calling getUserProfile() to refresh data after update.',
          ); // DEBUG
          return await getUserProfile(); // Coba muat ulang data user dari API profil
        }
      } else if (response.statusCode == 401) {
        // Token tidak valid, hapus token dan kembalikan null
        print(
          'ApiService DEBUG: updateUserProfile - Received 401, token is invalid. Removing token.',
        ); // DEBUG
        await removeToken();
        return null;
      } else if (response.statusCode == 422) {
        // Error validasi dari backend
        print(
          'ApiService DEBUG: updateUserProfile - Received 422 Validation Error. Body: ${response.body}',
        ); // DEBUG
        // Anda bisa parsing error detail dari response.body jika perlu menampilkan pesan validasi spesifik
        // final validationErrors = jsonDecode(response.body)['errors'];
        // print('Validation Errors: $validationErrors');
        // Jika ingin menampilkan Snackbar dari sini, ApiService butuh cara untuk mengakses context
        return null; // Update gagal karena validasi
      } else {
        // Status code lain menandakan kegagalan update
        print(
          'ApiService DEBUG: updateUserProfile - Failed to update profile with status code: ${response.statusCode}. Body: ${response.body}',
        ); // DEBUG
        return null;
      }
    } catch (e) {
      print('ApiService DEBUG: Error updating profile: $e'); // DEBUG
      return null;
    }
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
          '$baseUrl/auth/login/petugas'; // Menggunakan endpoint spesifik petugas
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

  // Metode BARU untuk mengambil daftar nomor PDAM berdasarkan ID Pelanggan
  // Menggunakan endpoint yang Anda sebutkan: Route::get('{id_pelanggan}', [IDPdamController::class, 'showByPelanggan']);
  // Diasumsikan API mengembalikan List<Map<String, dynamic>> dengan kunci 'nomor'
  Future<List<String>> fetchPdamNumbersByPelanggan(String idPelanggan) async {
    print(
      'ApiService DEBUG: Memulai fetchPdamNumbersByPelanggan untuk ID Pelanggan: $idPelanggan',
    );
    try {
      final url = Uri.parse('$baseUrl/id-pdam/$idPelanggan');
      print('ApiService DEBUG: Memanggil URL: $url');
      final response = await http.get(url);

      print('ApiService DEBUG: Status Code: ${response.statusCode}');
      print('ApiService DEBUG: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(
          response.body,
        ); // <-- PERUBAHAN DI SINI
        if (responseData.containsKey('data') && responseData['data'] is List) {
          // <-- PERUBAHAN DI SINI
          final List<dynamic> data =
              responseData['data']; // <-- PERUBAHAN DI SINI
          final List<String> pdamNumbers =
              data
                  .map((item) {
                    final pdamNum = item['nomor']?.toString();
                    print('ApiService DEBUG: Ditemukan Nomor PDAM: $pdamNum');
                    return pdamNum;
                  })
                  .whereType<String>()
                  .toList(); // Filter out any nulls
          print(
            'ApiService DEBUG: Berhasil mengambil ${pdamNumbers.length} Nomor PDAM.',
          );
          return pdamNumbers;
        } else {
          print(
            'ApiService DEBUG: Respons tidak memiliki kunci "data" atau bukan list.',
          );
          return [];
        }
      } else {
        print(
          'ApiService DEBUG: Gagal mengambil daftar nomor PDAM untuk ID Pelanggan $idPelanggan: ${response.statusCode} ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print(
        'ApiService DEBUG: Error saat mengambil daftar nomor PDAM untuk ID Pelanggan $idPelanggan: $e',
      );
      return [];
    }
  }

  // Metode untuk mengirim laporan pengaduan (dengan file)
  // Menggunakan endpoint POST /api/pengaduan
  Future<http.Response> buatPengaduan(
    Map<String, String> fields, {
    File? fotoBukti,
    File? fotoRumah,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/pengaduan',
    ); // Endpoint POST untuk Pengaduan
    final request = http.MultipartRequest('POST', uri);

    // Tambahkan field teks
    request.fields.addAll(fields);

    // Tambahkan file jika ada
    if (fotoBukti != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'foto_bukti', // Nama field di backend Laravel (sesuai model Pengaduan)
          fotoBukti.path,
          filename: fotoBukti.path.split('/').last,
        ),
      );
    }
    if (fotoRumah != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'foto_rumah', // Nama field di backend Laravel (sesuai model Pengaduan)
          fotoRumah.path,
          filename: fotoRumah.path.split('/').last,
        ),
      );
    }

    // Kirim request
    return await http.Response.fromStream(await request.send());
  }

  Future<List<Pengaduan>> getPetugasAssignments(int idPetugas) async {
    // This is a conceptual endpoint. You need to create this route in your Laravel backend.
    // This endpoint should return a list of 'pengaduans' assigned to the 'id_petugas'
    // by joining 'pengaduans' with 'petugas_pengaduans'.
    final response = await http.get(
      Uri.parse('$baseUrl/petugas/$idPetugas/assignments'),
      headers: {
        'Accept': 'application/json',
        // Add Authorization header if your API requires authentication
        // 'Authorization': 'Bearer YOUR_AUTH_TOKEN',
      },
    );

    if (response.statusCode == 200) {
      // If the API returns a list directly under a 'data' key, use:
      // List<dynamic> body = jsonDecode(response.body)['data'];
      // Otherwise, if it's a direct list:
      List<dynamic> body = jsonDecode(response.body);
      List<Pengaduan> assignments =
          body
              .map(
                (dynamic item) =>
                    Pengaduan.fromJson(item as Map<String, dynamic>),
              )
              .toList();
      return assignments;
    } else {
      // You might want to parse the error message from response.body
      throw Exception(
        'Failed to load assignments (Status Code: ${response.statusCode})',
      );
    }
  }

  Future<Map<String, dynamic>> updateStatusTugas({
    required int idTugas,
    required String tipeTugas,
    required String newStatus,
    String? keterangan,
  }) async {
    final token = await getToken();
    // Sesuaikan endpoint API Anda
    final url = Uri.parse('$baseUrl/tugas/$tipeTugas/$idTugas/update-status');
    print('Calling updateStatusTugas: $url with status: $newStatus');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: {
        'status': newStatus,
        if (keterangan != null) 'keterangan': keterangan,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      print(
        'Error updateStatusTugas (${response.statusCode}): ${response.body}',
      );
      throw Exception('Gagal update status tugas: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> uploadFotoTugas({
    required int idTugas,
    required String tipeTugas,
    required String jenisFoto, // 'foto_sebelum' atau 'foto_sesudah'
    required String imagePath, // Path ke file gambar
    String? newStatus, // Opsional, jika upload foto juga mengubah status
  }) async {
    final token = await getToken();
    final url = Uri.parse(
      '$baseUrl/petugas/tugas/$tipeTugas/$idTugas/upload-foto',
    ); // Tambahkan
    print('Calling uploadFotoTugas: $url for $jenisFoto');

    var request = http.MultipartRequest('POST', url);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';

    request.fields['jenis_foto'] = jenisFoto;
    if (newStatus != null) {
      request.fields['status'] = newStatus;
    }
    request.files.add(await http.MultipartFile.fromPath('foto', imagePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      print('Error uploadFotoTugas (${response.statusCode}): ${response.body}');
      throw Exception('Gagal upload foto tugas: ${response.body}');
    }
  }

  Future<Petugas> getPetugasProfile() async {
    final token = await getToken();
    if (token == null)
      throw Exception('Token tidak ditemukan, silakan login ulang.');

    final response = await http.get(
      Uri.parse('$baseUrl/user/profile'), // Endpoint dari AuthController@me
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      // Asumsi API mengembalikan data user/petugas langsung di body atau di dalam key 'data'/'user'
      final responseData = jsonDecode(response.body);
      // Sesuaikan jika data petugas ada di dalam key tertentu, misal responseData['user']
      return Petugas.fromJson(
        responseData['user'] as Map<String, dynamic>? ?? responseData,
      );
    } else {
      throw Exception('Gagal mengambil data profil: ${response.body}');
    }
  }

  Future<Petugas> updatePetugasProfile({
    required String nama,
    required String email,
    required String nomorHp,
    String? password, // Opsional jika ingin ganti password
    String? passwordConfirmation, // Opsional
  }) async {
    final token = await getToken();
    if (token == null)
      throw Exception('Token tidak ditemukan, silakan login ulang.');

    Map<String, String> body = {
      'nama': nama,
      'email': email,
      'nomor_hp': nomorHp,
    };

    if (password != null && password.isNotEmpty) {
      body['password'] = password;
      if (passwordConfirmation != null) {
        body['password_confirmation'] = passwordConfirmation;
      }
    }

    final response = await http.patch(
      // Atau POST jika API Anda menggunakan POST untuk update
      Uri.parse(
        '$baseUrl/user/profile',
      ), // Endpoint dari AuthController@updateProfile
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json', // Jika mengirim JSON body
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      // Asumsi API mengembalikan data user/petugas yang sudah terupdate
      return Petugas.fromJson(
        responseData['user'] as Map<String, dynamic>? ?? responseData,
      );
    } else {
      // Coba parse error dari backend
      String errorMessage = 'Gagal memperbarui profil.';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['message'] != null) {
          errorMessage += ' Pesan: ${errorData['message']}';
        }
        if (errorData['errors'] != null && errorData['errors'] is Map) {
          (errorData['errors'] as Map).forEach((key, value) {
            if (value is List) {
              errorMessage += '\n- ${value.join(', ')}';
            }
          });
        }
      } catch (e) {
        // Gagal parse error, gunakan body asli jika ada
        errorMessage += ' Respons server: ${response.body}';
      }
      throw Exception(errorMessage);
    }
  }
}

// Helper untuk manajemen PDAM ID secara lokal (contoh sederhana)
// Mungkin tidak lagi relevan jika ID Pelanggan selalu diambil dari API
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
