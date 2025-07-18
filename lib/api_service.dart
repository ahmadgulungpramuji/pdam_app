// ignore_for_file: unused_local_variable, unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io'; // Import ini untuk File
import 'package:http/http.dart' as http; //
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:pdam_app/models/petugas_model.dart';
import 'package:pdam_app/models/temuan_kebocoran_model.dart';
import 'package:pdam_app/models/cabang_model.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:shared_preferences/shared_preferences.dart'; //
import 'package:pdam_app/models/paginated_response.dart';

class ApiService {
  final String baseUrl = 'http://10.136.211.196:8000/api'; //

  final String _witAiServerAccessToken = 'BHEGRMVFUOEG45BEAVKLS3OBLATWD2JN'; //
  final String _witAiApiUrl = 'https://api.wit.ai/message'; //
  final String _witAiApiVersion = '20240514'; //

  String get rootBaseUrl {
    //
    if (baseUrl.endsWith('/api')) {
      //
      return baseUrl.substring(0, baseUrl.length - '/api'.length); //
    }
    if (baseUrl.endsWith('/api/')) {
      // jaga-jaga jika ada trailing slash setelah /api
      return baseUrl.substring(0, baseUrl.length - '/api/'.length); //
    }
    return baseUrl; //
  }

  Future<Map<String, dynamic>?> sendMessage(String message) async {
    //
    if (_witAiServerAccessToken == 'YOUR_WIT_AI_SERVER_ACCESS_TOKEN') {
      //
      log(
        'WARNING: Wit.ai Server Access Token has not been set in ApiService.', //
      );
      return {
        //
        "error": true, //
        "message": //
            "Token API belum diatur. Silakan atur token Wit.ai di api_service.dart.", //
      };
    }

    try {
      //
      final uri = Uri.parse(_witAiApiUrl).replace(
        //
        queryParameters: {
          //
          'q': message, // Pesan pengguna
          'v': _witAiApiVersion, //
        },
      );

      final response = await http.get(
        //
        uri, //
        headers: {'Authorization': 'Bearer $_witAiServerAccessToken'}, //
      );

      log('Wit.ai API Status Code: ${response.statusCode}'); //
      log('Wit.ai API Response Body: ${response.body}'); //

      if (response.statusCode == 200) {
        //
        return jsonDecode(response.body); //
      } else {
        return {
          //
          "error": true, //
          "statusCode": response.statusCode, //
          "message": //
              "Gagal menghubungi Wit.ai API. Status: ${response.statusCode}. Body: ${response.body}", //
        };
      }
    } catch (e) {
      //
      log('Error calling Wit.ai API: $e'); //
      return {
        //
        "error": true, //
        "message": "Terjadi kesalahan jaringan atau sistem: $e", //
      };
    }
  }

  Future<void> saveToken(String token) async {
    //
    final prefs = await SharedPreferences.getInstance(); //
    await prefs.setString('user_token', token); //
  }

  Future<String?> getToken() async {
    //
    final prefs = await SharedPreferences.getInstance(); //
    return prefs.getString('user_token'); //
  }

  Future<void> removeToken() async {
    //
    final prefs = await SharedPreferences.getInstance(); //
    await prefs.remove('user_token'); //
    await prefs.remove('user_data'); //
    await prefs.remove('pdam_ids'); //
  }

  Future<http.Response> getBranchAdminInfo(String token) async {
    final url = Uri.parse('$baseUrl/chat/branch-admin-info');
    try {
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      return response;
    } catch (e) {
      // Mengembalikan response error manual jika terjadi exception jaringan
      return http.Response(
        jsonEncode({'message': 'Error jaringan: ${e.toString()}'}),
        500, // Internal Server Error
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<List<Cabang>> getCabangList() async {
    //
    // Endpoint ini sudah ada di api.php Anda: Route::apiResource('cabangs', CabangController::class);
    final url = Uri.parse('$baseUrl/cabangs'); //
    try {
      //
      final response = await http.get(
        //
        url, //
        headers: {'Accept': 'application/json'}, //
      );

      if (response.statusCode == 200) {
        //
        // Data dari Laravel kemungkinan besar ada di dalam key 'data' jika menggunakan apiResource
        final dynamic body = jsonDecode(response.body); //
        List<dynamic> dataList; //

        if (body is Map<String, dynamic> && body.containsKey('data')) {
          //
          dataList = body['data'] as List; //
        } else if (body is List) {
          //
          dataList = body; //
        } else {
          throw Exception('Format respons data cabang tidak dikenali.'); //
        }

        return dataList //
            .map((json) => Cabang.fromJson(json as Map<String, dynamic>)) //
            .toList(); //
      } else {
        throw Exception(
          //
          'Gagal memuat data cabang (Status: ${response.statusCode})', //
        );
      }
    } catch (e) {
      //
      print('ApiService Error getCabangList: $e'); //
      rethrow; //
    }
  }

  Future<PaginatedTugasResponse> getRiwayatPetugas(
    //
    int idPetugas, //
    int page, //
  ) async {
    final url = Uri.parse('$baseUrl/petugas/history/$idPetugas?page=$page'); //
    final token = await getToken(); //

    // Pastikan Anda sudah mengimpor 'package:http/http.dart' as http;
    final response = await http //
        .get(
          //
          url, //
          headers: {
            //
            'Content-Type': 'application/json', //
            if (token != null) 'Authorization': 'Bearer $token', //
          },
        )
        .timeout(const Duration(seconds: 30)); //

    if (response.statusCode == 200) {
      //
      // Pastikan Anda sudah mengimpor 'dart:convert';
      final responseBody = json.decode(response.body); //
      final List<dynamic> riwayatJson = responseBody['data']; //

      // LOGIKA KUNCI: Cek apakah ada halaman berikutnya dari respons API
      final bool hasMore = responseBody['next_page_url'] != null; //

      // Pastikan Anda sudah mengimpor model Tugas
      final List<Tugas> tugasList = //
          riwayatJson //
              .map((json) => Tugas.fromJson(json as Map<String, dynamic>)) //
              .toList(); //

      // Kembalikan objek PaginatedTugasResponse yang baru
      return PaginatedTugasResponse(
        //
        tugasList: tugasList, //
        hasMorePages: hasMore, //
      );
    } else {
      throw Exception('Gagal memuat data riwayat dari API'); //
    }
  }
      ///riwayat yg baru di tambahkan
  
Future<void> batalkanPenugasanMandiri({
    required int idTugas,
    required String tipeTugas,
    required String alasan,
}) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/tugas/$tipeTugas/$idTugas/batalkan-mandiri');

    final response = await http.post(
        url,
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'alasan_pembatalan': alasan}),
    );

    if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? 'Gagal membatalkan penugasan.');
    }
}



  Future<Map<String, dynamic>> registerCalonPelanggan({
    //
    required Map<String, String> data, //
    required String imagePathKtp, // Diubah namanya agar lebih jelas
    required String imagePathRumah, // TAMBAHKAN INI, nullable
  }) async {
    // Endpoint ini sudah ada di api.php Anda: Route::post('/calon-pelanggan/daftar', ...);
    final url = Uri.parse('$baseUrl/calon-pelanggan/daftar'); //
    var request = http.MultipartRequest(
      'POST',
      url,
    ); // DIUBAH: Registrasi seharusnya POST (membuat data baru)

    // Tambahkan header
    request.headers['Accept'] = 'application/json'; //
    request.fields.addAll(data); //

    // Tambahkan file gambar KTP
    request.files.add(
      //
      await http.MultipartFile.fromPath(
        //
        'foto_ktp', // 'foto_ktp' harus cocok dengan nama field di backend Laravel
        imagePathKtp, //
      ),
    );
    request.files.add(
      //
      await http.MultipartFile.fromPath('foto_rumah', imagePathRumah), //
    );

    try {
      //
      final streamedResponse = await request.send().timeout(
        //
        const Duration(seconds: 60), //
      );
      final response = await http.Response.fromStream(streamedResponse); //
      final responseData = jsonDecode(response.body); //

      if (response.statusCode == 201) {
        //
        // 201 Created
        return responseData; //
      } else if (response.statusCode == 422) {
        //
        // Validation Error
        final errors = responseData['errors']; //
        // Menggabungkan pesan error menjadi satu string
        String errorMessage = "Data tidak valid:\n"; //
        if (errors is Map) {
          //
          errors.forEach((key, value) {
            //
            if (value is List) {
              //
              errorMessage += "- ${value.join(', ')}\n"; //
            }
          });
        }
        throw Exception(errorMessage); //
      } else {
        throw Exception(
          //
          'Gagal mendaftar: ${responseData['message'] ?? 'Terjadi kesalahan server.'}', //
        );
      }
    } catch (e) {
      //
      print('ApiService Error registerCalonPelanggan: $e'); //
      rethrow; //
    }
  }

  Future<bool> checkNomorHpExists(String nomorHp) async {
    // PENTING: Sesuaikan endpoint '/cek-nomor-hp' dengan endpoint di API Anda.
    final url = Uri.parse('$baseUrl/cek-nomor-hp/$nomorHp');
    print('ApiService DEBUG: Checking if phone number exists at $url');

    try {
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      // Jika server merespons 200 OK, artinya nomor HP ditemukan (sudah terdaftar).
      if (response.statusCode == 200) {
        print('ApiService DEBUG: Phone number $nomorHp exists.');
        return true;
      }
      // Jika server merespons 404 Not Found, artinya nomor HP tidak ditemukan (tersedia).
      else if (response.statusCode == 404) {
        print('ApiService DEBUG: Phone number $nomorHp is available.');
        return false;
      }
      // Untuk status code lainnya, kita anggap sebagai error.
      else {
        print(
          'ApiService DEBUG: Failed to check phone number. Status: ${response.statusCode}, Body: ${response.body}',
        );
        // Melempar error agar bisa ditangkap di UI
        throw Exception('Gagal memverifikasi nomor HP ke server.');
      }
    } on TimeoutException {
      print('ApiService DEBUG: Timeout while checking phone number.');
      throw Exception('Server tidak merespons. Periksa koneksi internet Anda.');
    } catch (e) {
      // Melempar ulang error yang sudah ada atau yang baru.
      print('ApiService DEBUG: Error checking phone number: $e');
      rethrow;
    }
  }

  Future<http.Response> submitLaporanFotoWaterMeter({
    //
    required String idPdam, //
    required String imagePath, //
    required int idCabang, // <-- TAMBAHKAN PARAMETER INI
    String? komentar, //
  }) async {
    final token = await getToken(); //
    if (token == null) {
      //
      throw Exception('Otentikasi diperlukan. Silakan login kembali.'); //
    }

    final url = Uri.parse('$baseUrl/lapor-foto-water-meter'); //
    var request = http.MultipartRequest('POST', url); //

    // Tambahkan headers
    request.headers['Authorization'] = 'Bearer $token'; //
    request.headers['Accept'] = 'application/json'; //

    // Tambahkan fields dari form
    request.fields['id_pdam'] = idPdam; //
    request.fields['id_cabang'] = //
        idCabang.toString(); // <-- TAMBAHKAN FIELD INI

    if (komentar != null && komentar.isNotEmpty) {
      //
      request.fields['komentar'] = komentar; //
    }

    // Tambahkan file gambar
    request.files.add(
      //
      await http.MultipartFile.fromPath(
        //
        'foto_meter', // Nama field ini HARUS SAMA dengan di backend Laravel
        imagePath, //
      ),
    );

    try {
      //
      final streamedResponse = await request.send(); //
      return await http.Response.fromStream(streamedResponse); //
    } catch (e) {
      //
      // Handle network error, etc.
      throw Exception('Gagal menghubungi server: $e'); //
    }
  }

  // =======================================================================
  // == METHOD BARU UNTUK MENGAMBIL LAPORAN PENGADUAN PENGGUNA (PELANGGAN) ==
  // =======================================================================
  Future<List<dynamic>> getLaporanPengaduan() async {
    //
    // Atau Future<List<Pengaduan>>
    final token = await getToken(); //
    if (token == null) {
      //
      print('ApiService DEBUG: getLaporanPengaduan - No token found.'); //
      throw Exception('Autentikasi dibutuhkan. Token tidak ditemukan.'); //
    }

    // TENTUKAN ENDPOINT API ANDA DI SINI
    // Misalnya, jika di backend Laravel Anda rutenya adalah Route::get('/pengaduan-saya', [PengaduanController::class, 'indexSaya']);
    // Maka endpointnya adalah '/pengaduan-saya'
    final String endpoint = //
        '/pengaduan-saya'; // <--- CONTOH, GANTI DENGAN ENDPOINT YANG BENAR
    final url = Uri.parse('$baseUrl$endpoint'); //

    print('ApiService DEBUG: getLaporanPengaduan - Memanggil URL: $url'); //

    try {
      //
      final response = await http.get(
        //
        url, //
        headers: {
          //
          'Authorization': 'Bearer $token', //
          'Accept': 'application/json', //
        },
      );

      print(
        //
        'ApiService DEBUG: getLaporanPengaduan - Status Code: ${response.statusCode}', //
      );
      // Hati-hati mencetak body jika responsnya besar
      // print('ApiService DEBUG: getLaporanPengaduan - Body: ${response.body}');

      if (response.statusCode == 200) {
        //
        final dynamic decodedBody = json.decode(response.body); //

        // Periksa apakah respons utama adalah List atau Map yang berisi List di dalam key 'data'
        List<dynamic> responseData; //
        if (decodedBody is List) {
          //
          responseData = decodedBody; //
        } else if (decodedBody is Map<String, dynamic> && //
            decodedBody.containsKey('data') && //
            decodedBody['data'] is List) {
          //
          responseData = decodedBody['data']; //
        } else {
          print(
            //
            'ApiService DEBUG: getLaporanPengaduan - Format respons tidak terduga.', //
          );
          throw Exception(
            'Format respons data laporan tidak sesuai harapan.',
          ); //
        }

        // Pastikan API backend Anda mengembalikan 'id' sebagai integer
        // dan field lainnya sesuai dengan yang diharapkan oleh model Pengaduan.fromJson
        return responseData; // Mengembalikan List<dynamic>
      } else if (response.statusCode == 401) {
        //
        print(
          //
          'ApiService DEBUG: getLaporanPengaduan - Unauthorized (401). Token mungkin tidak valid.', //
        );
        await removeToken(); //
        throw Exception('Sesi Anda telah berakhir. Silakan login kembali.'); //
      } else {
        print(
          //
          'ApiService DEBUG: getLaporanPengaduan - Gagal mengambil laporan. Status: ${response.statusCode}. Body: ${response.body}', //
        );
        throw Exception(
          //
          'Gagal mengambil data laporan dari server (Status: ${response.statusCode})', //
        );
      }
    } catch (e) {
      //
      print(
        //
        'ApiService DEBUG: getLaporanPengaduan - Error saat memanggil API: $e', //
      );
      rethrow; // Melempar ulang error agar bisa ditangkap oleh UI (LacakLaporanSayaPage)
    }
  }
  // =======================================================================
  // == AKHIR METHOD BARU ==
  // =======================================================================

  Future<List<Tugas>> getPetugasSemuaTugas(int idPetugas) async {
    //
    final token = await getToken(); //
    final response = await http.get(
      //
      Uri.parse('$baseUrl/petugas/$idPetugas/tugas'), //
      headers: {
        //
        'Accept': 'application/json', //
        if (token != null) 'Authorization': 'Bearer $token', //
      },
    );

    if (response.statusCode == 200) {
      //
      List<dynamic> body = jsonDecode(response.body); //
      List<Tugas> daftarTugas = //
          body //
              .map(
                //
                (dynamic item) =>
                    Tugas.fromJson(item as Map<String, dynamic>), //
              )
              .toList(); //
      return daftarTugas; //
    } else {
      print('Error Body getPetugasSemuaTugas: ${response.body}'); //
      throw Exception(
        //
        'Gagal memuat daftar tugas (Status Code: ${response.statusCode})', //
      );
    }
  }

  Future<Map<String, dynamic>> postPdamId(
    //
    String idPdam, //
    String idPelanggan, //
  ) async {
    final response = await http.post(
      //
      Uri.parse('$baseUrl/id-pdam'), //
      headers: <String, String>{
        //
        'Content-Type': 'application/json; charset=UTF-8', //
      },
      body: jsonEncode(<String, String>{
        //
        'id_pelanggan': idPelanggan, //
        'nomor': idPdam, //
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      //
      return jsonDecode(response.body); //
    } else {
      throw Exception('Gagal menyimpan ID PDAM ke server'); //
    }
  }

  Future<List<dynamic>> getAllUserPdamIds() async {
    //
    final token = await getToken(); //
    if (token == null) {
      //
      print('ApiService DEBUG: getAllUserPdamIds - No token found.'); //
      return []; //
    }

    final prefs = await SharedPreferences.getInstance(); //
    final userDataString = prefs.getString('user_data'); //
    if (userDataString == null) {
      //
      print('ApiService DEBUG: getAllUserPdamIds - User data not found.'); //
      return []; //
    }

    final userData = jsonDecode(userDataString) as Map<String, dynamic>; //
    // Pastikan userData['id'] ada dan merupakan integer atau string yang bisa di-parse ke int jika perlu
    final String idPelanggan = userData['id'].toString(); //

    try {
      //
      final response = await http.get(
        //
        Uri.parse('$baseUrl/id-pdam/$idPelanggan'), //
        headers: {
          //
          'Authorization': 'Bearer $token', //
          'Accept': 'application/json', //
        },
      );

      print(
        //
        'ApiService DEBUG: getAllUserPdamIds - Status Code: ${response.statusCode}', //
      );
      print('ApiService DEBUG: getAllUserPdamIds - Body: ${response.body}'); //

      if (response.statusCode == 200) {
        //
        final responseData = jsonDecode(response.body); //
        if (responseData is Map<String, dynamic> && //
            responseData['data'] is List) {
          //
          return responseData['data']; //
        } else if (responseData is List) {
          //
          // Jika API langsung mengembalikan List
          return responseData; //
        } else {
          print(
            //
            'ApiService DEBUG: getAllUserPdamIds - Unexpected response format.', //
          );
          return []; //
        }
      } else if (response.statusCode == 401) {
        //
        print('ApiService DEBUG: getAllUserPdamIds - Unauthorized.'); //
        removeToken(); //
        return []; //
      } else {
        print(
          //
          'ApiService DEBUG: getAllUserPdamIds - Failed with status code: ${response.statusCode}', //
        );
        return []; //
      }
    } catch (e) {
      //
      print(
        'ApiService DEBUG: getAllUserPdamIds - Error during API call: $e',
      ); //
      return []; //
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    //
    final token = await getToken(); //
    print(
      //
      'ApiService DEBUG: getUserProfile - Token retrieved: ${token != null ? "Exists" : "Null"}', //
    );

    if (token == null) {
      //
      print(
        //
        'ApiService DEBUG: getUserProfile - No token found, returning null.', //
      );
      return null; //
    }

    final prefs = await SharedPreferences.getInstance(); //
    String? cachedUserData = prefs.getString('user_data'); //

    if (cachedUserData != null) {
      //
      try {
        //
        print(
          //
          'ApiService DEBUG: getUserProfile - Found and parsed cached data.', //
        );
        return jsonDecode(cachedUserData) as Map<String, dynamic>; //
      } catch (e) {
        //
        print(
          //
          'ApiService DEBUG: getUserProfile - Error parsing cached data: $e. Removing cache.', //
        );
        await prefs.remove('user_data'); //
      }
    }

    print(
      'ApiService DEBUG: getUserProfile - Fetching profile from network.',
    ); //
    try {
      //
      final response = await http.get(
        //
        Uri.parse('$baseUrl/user/profile'), //
        headers: {
          //
          'Authorization': 'Bearer $token', //
          'Accept': 'application/json', //
        },
      );

      print(
        //
        'ApiService DEBUG: getUserProfile - API Response Status Code: ${response.statusCode}', //
      );
      print(
        //
        'ApiService DEBUG: getUserProfile - API Response Body: ${response.body}', //
      );

      if (response.statusCode == 200) {
        //
        final data = jsonDecode(response.body) as Map<String, dynamic>; //
        if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
          //
          await prefs.setString('user_data', jsonEncode(data['user'])); //
          print(
            //
            'ApiService DEBUG: getUserProfile - Profile fetched successfully and cached.', //
          );
          return data['user'] as Map<String, dynamic>; //
        } else {
          print(
            //
            'ApiService DEBUG: getUserProfile - 200 OK, but response format unexpected.', //
          );
          return null; //
        }
      } else if (response.statusCode == 401) {
        //
        print(
          //
          'ApiService DEBUG: getUserProfile - Received 401, token is invalid. Removing token and returning null.', //
        );
        await removeToken(); //
        return null; //
      } else {
        print(
          //
          'ApiService DEBUG: getUserProfile - Failed with status code: ${response.statusCode}.', //
        );
        return null; //
      }
    } catch (e) {
      //
      print(
        //
        'ApiService DEBUG: getUserProfile - Exception during network fetch: $e', //
      );
      return null; //
    }
  }

  Future<Map<String, dynamic>?> updateUserProfile(
    //
    Map<String, dynamic> updatedData, { //
    File? profileImage, // <--- TAMBAHKAN PARAMETER INI
  }) async {
    print('ApiService DEBUG: Attempting to update user profile.'); //
    final token = await getToken(); //
    if (token == null) {
      //
      print(
        //
        'ApiService DEBUG: updateUserProfile - No token found, returning null.', //
      );
      throw Exception(
        'Autentikasi diperlukan. Silakan login kembali.',
      ); // <--- LEMPAR EXCEPTION INI
    }

    final url = Uri.parse('$baseUrl/user/profile'); //
    late http.Response response; //

    try {
      //
      if (profileImage != null) {
        // Jika ada gambar, gunakan MultipartRequest (POST + _method: 'PATCH')
        // === PERUBAHAN KUNCI 1 ===
        // Menggunakan POST dan method spoofing _method: 'PATCH' untuk kompatibilitas Laravel
        var request = http.MultipartRequest('POST', url);
        request.fields['_method'] = 'PATCH';

        request.headers['Authorization'] = 'Bearer $token'; //
        request.headers['Accept'] = 'application/json'; //

        updatedData.forEach((key, value) {
          // Tambahkan field data teks
          request.fields[key] = value.toString(); //
        });

        request.files.add(
          // Tambahkan file gambar
          await http.MultipartFile.fromPath(
            //
            'foto_profil', // Ini HARUS cocok dengan nama field di backend Laravel (di AuthController::updateProfile)
            profileImage.path, //
            filename: profileImage.path.split('/').last, //
          ),
        );
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
        ); // Tambah timeout
        response = await http.Response.fromStream(streamedResponse); //
      } else {
        // Jika tidak ada gambar, gunakan PATCH untuk data JSON saja
        response = await http
            .patch(
              url, //
              headers: {
                //
                'Authorization': 'Bearer $token', //
                'Accept': 'application/json', //
                'Content-Type': 'application/json; charset=UTF-8', //
              },
              body: jsonEncode(updatedData), //
            )
            .timeout(const Duration(seconds: 30)); // Tambah timeout
      }

      print(
        //
        'ApiService DEBUG: updateUserProfile - API Response Status Code: ${response.statusCode}', //
      );
      print(
        //
        'ApiService DEBUG: updateUserProfile - API Response Body: ${response.body}', //
      );

      // === PERUBAHAN KUNCI 2 ===
      // Menerima semua status code 2xx (200, 201, etc.) sebagai sukses
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData =
            jsonDecode(response.body) as Map<String, dynamic>; //
        final prefs = await SharedPreferences.getInstance(); //
        await prefs.remove('user_data'); //
        if (responseData.containsKey('user') && //
            responseData['user'] is Map<String, dynamic>) {
          //
          await prefs.setString(
            'user_data',
            jsonEncode(responseData['user']),
          ); //
          print(
            //
            'ApiService DEBUG: updateUserProfile - Profile updated and cache refreshed.', //
          );
          return responseData['user'] as Map<String, dynamic>; //
        } else {
          print(
            //
            'ApiService DEBUG: updateUserProfile - 200 OK, but response format unexpected.', //
          );
          return await getUserProfile(); // Coba ambil profil lagi untuk memastikan data terbaru
        }
      } else if (response.statusCode == 401) {
        //
        print(
          //
          'ApiService DEBUG: updateUserProfile - Received 401, token is invalid. Removing token.', //
        );
        await removeToken(); //
        throw Exception('Sesi Anda telah berakhir. Silakan login kembali.'); //
      } else if (response.statusCode == 422) {
        //
        print(
          //
          'ApiService DEBUG: updateUserProfile - Received 422 Validation Error. Body: ${response.body}', //
        );
        final errorResponse = jsonDecode(response.body); //
        String errorMessage = "Data tidak valid:"; //
        if (errorResponse.containsKey('errors') &&
            errorResponse['errors'] is Map) {
          //
          (errorResponse['errors'] as Map).forEach((key, value) {
            //
            if (value is List && value.isNotEmpty) {
              //
              errorMessage += "\n- ${value[0]}"; //
            }
          });
        } else {
          errorMessage = errorResponse['message'] ?? errorMessage; //
        }
        throw Exception(
          errorMessage,
        ); // <--- LEMPAR EXCEPTION DENGAN PESAN VALIDASI
      } else {
        print(
          //
          'ApiService DEBUG: updateUserProfile - Failed to update profile with status code: ${response.statusCode}. Body: ${response.body}', //
        );
        final errorResponse = jsonDecode(response.body); //
        throw Exception(
          //
          errorResponse['message'] ??
              'Gagal memperbarui profil (Status: ${response.statusCode})', //
        );
      }
    } on TimeoutException {
      //
      print('ApiService DEBUG: updateUserProfile - Timeout'); //
      throw Exception(
        'Server tidak merespons. Periksa koneksi internet Anda.',
      ); //
    } catch (e) {
      //
      print('ApiService DEBUG: Error updating profile: $e'); //
      throw Exception(
        'Terjadi kesalahan jaringan atau sistem: ${e.toString()}',
      ); //
    }
  }

  Future<TemuanKebocoran> trackReport(String trackingCode) async {
    //
    // Endpoint di Laravel Anda, contoh: /api/track/temuan/{trackingCode}
    // Jika endpoint Anda hanya /track/{trackingCode}, sesuaikan di bawah
    final String endpoint = //
        '/track/temuan/$trackingCode'; // Sesuaikan dengan rute Laravel Anda
    final url = Uri.parse('$baseUrl$endpoint'); //

    print('ApiService DEBUG: trackReport - Memanggil URL: $url'); //

    final headers = {
      //
      'Accept': 'application/json', //
      // Tidak perlu token Authorization untuk endpoint publik ini
    };

    try {
      //
      final response = await http //
          .get(url, headers: headers) //
          .timeout(const Duration(seconds: 20)); //

      print(
        //
        'ApiService DEBUG: trackReport - Status Code: ${response.statusCode}', //
      );
      // print('ApiService DEBUG: trackReport - Response Body: ${response.body}'); // Aktifkan jika perlu debug body

      if (response.statusCode == 200) {
        //
        final responseBody = jsonDecode(response.body); //

        // Asumsi backend mengembalikan { "success": true, "data": { ...temuan... } }
        // atau langsung objek temuan jika tidak ada wrapper 'data'
        if (responseBody is Map<String, dynamic>) {
          //
          if (responseBody.containsKey('success') && //
              responseBody['success'] == true && //
              responseBody.containsKey('data')) {
            //
            // Jika ada wrapper 'success' dan 'data'
            if (responseBody['data'] is Map<String, dynamic>) {
              //
              return TemuanKebocoran.fromJson(
                //
                responseBody['data'] as Map<String, dynamic>, //
              );
            } else {
              throw Exception(
                //
                'Format data temuan tidak sesuai (field "data" bukan Map).', //
              );
            }
          } else if (!responseBody.containsKey('success')) {
            //
            // Jika API langsung mengembalikan objek TemuanKebocoran tanpa wrapper 'data'
            // Ini akan terjadi jika controller Laravel Anda langsung return response()->json($temuan);
            return TemuanKebocoran.fromJson(responseBody); //
          } else {
            // Ada 'success' key tapi nilainya false atau tidak ada 'data'
            throw Exception(
              //
              responseBody['message'] ?? //
                  'Laporan tidak ditemukan atau format respons salah.', //
            );
          }
        } else {
          throw Exception(
            //
            'Format respons dari server tidak dikenali (bukan Map).', //
          );
        }
      } else if (response.statusCode == 404) {
        //
        final responseBody = jsonDecode(response.body); //
        throw Exception(
          //
          responseBody['message'] ?? //
              'Laporan dengan kode tracking tersebut tidak ditemukan (404).', //
        );
      } else {
        // Error lainnya
        String errorMessage = //
            'Gagal melacak laporan (Status: ${response.statusCode}).'; //
        try {
          //
          final responseBody = jsonDecode(response.body); //
          errorMessage = //
              responseBody['message'] ?? //
              "$errorMessage Respons: ${response.body}"; //
        } catch (e) {
          // Biarkan error message default jika body tidak bisa di-parse
        }
        throw Exception(errorMessage); //
      }
    } on TimeoutException {
      //
      print(
        'ApiService DEBUG: trackReport - Timeout saat menghubungi server.',
      ); //
      throw Exception(
        'Server tidak merespons. Periksa koneksi internet Anda.',
      ); //
    } catch (e) {
      //
      print('ApiService DEBUG: trackReport - Error: $e'); //
      // Lempar ulang error agar bisa ditangani di UI, atau ubah pesannya
      if (e is Exception && e.toString().contains("FormatException")) {
        //
        throw Exception("Terjadi kesalahan format data dari server."); //
      }
      rethrow; //
    }
  }

  Future<Map<String, String>> getHeaders() async {
    //
    final token = await getToken(); //
    return {
      //
      'Content-Type': 'application/json', //
      'Accept': 'application/json', //
      if (token != null) 'Authorization': 'Bearer $token', //
    };
  }

  Future<http.Response> fetchCabangs() async {
    //
    final headers = {'Accept': 'application/json'}; //
    final url = Uri.parse('$baseUrl/cabangs'); //
    return await http.get(url, headers: headers); //
  }

  Future<http.Response> registerPelanggan({
    //
    required String username, //
    required String email, //
    required String password, //
    required String nomorHp, //
    required int idCabang, //
  }) async {
    final headers = {
      //
      'Content-Type': 'application/json', //
      'Accept': 'application/json', //
    };
    final url = Uri.parse('$baseUrl/auth/register'); //
    final body = jsonEncode({
      //
      'username': username, //
      'email': email, //
      'password': password, //
      'nomor_hp': nomorHp, //
      'id_cabang': idCabang, //
    });
    return await http.post(url, headers: headers, body: body); //
  }

  Future<Map<String, dynamic>> unifiedLogin({
    //
    required String identifier, // Menggunakan 'identifier' generik
    required String password, //
  }) async {
    final url = Uri.parse('$baseUrl/auth/login/unified'); //
    print('ApiService DEBUG: unifiedLogin - URL: $url'); //

    try {
      //
      final response = await http //
          .post(
            //
            url, //
            headers: {
              //
              'Content-Type': 'application/json', //
              'Accept': 'application/json', //
            },
            body: jsonEncode({
              //
              'identifier': identifier, // Mengirim 'identifier'
              'password': password, //
            }),
          )
          .timeout(const Duration(seconds: 25)); //

      print(
        //
        'ApiService DEBUG: unifiedLogin - Status Code: ${response.statusCode}', //
      );

      final responseData = jsonDecode(response.body); //

      if (response.statusCode == 200) {
        //
        if (responseData is Map<String, dynamic> && //
            responseData['success'] == true) {
          //
          if (responseData.containsKey('token') && //
              responseData.containsKey('user_type') && //
              responseData.containsKey('user') && //
              responseData['user'] is Map<String, dynamic>) {
            //
            return responseData; //
          } else {
            throw Exception(
              'Format respons login tidak lengkap dari server.',
            ); //
          }
        } else {
          throw Exception(
            //
            responseData['message'] ?? //
                'Login gagal (format respons tidak dikenal).', //
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        //
        throw Exception(
          //
          responseData['message'] ?? 'ID, Nomor HP, atau password salah.', //
        );
      } else if (response.statusCode == 422) {
        //
        String errorMsg = "Input tidak valid:"; //
        if (responseData.containsKey('errors') && //
            responseData['errors'] is Map) {
          //
          (responseData['errors'] as Map).forEach((key, value) {
            //
            if (value is List && value.isNotEmpty) {
              //
              errorMsg += "\n- ${value[0]}"; //
            }
          });
        } else {
          errorMsg = responseData['message'] ?? errorMsg; //
        }
        throw Exception(errorMsg); //
      } else {
        throw Exception(
          //
          'Gagal login. Status: ${response.statusCode}. Pesan: ${responseData['message'] ?? response.body}', //
        );
      }
    } on TimeoutException {
      //
      print('ApiService DEBUG: unifiedLogin - Timeout'); //
      throw Exception(
        'Server tidak merespons. Periksa koneksi internet Anda.',
      ); //
    } catch (e) {
      //
      print('ApiService DEBUG: unifiedLogin - Error: $e'); //
      if (e is Exception && e.toString().contains("Exception: ")) {
        //
        rethrow; //
      }
      throw Exception('Terjadi kesalahan: ${e.toString()}'); //
    }
  }

  Future<void> logout() async {
    //
    final token = await getToken(); //
    if (token == null) {
      //
      print(
        'ApiService DEBUG: logout - Tidak ada token, hanya hapus lokal.',
      ); //
      await removeToken(); //
      return; //
    }

    final url = Uri.parse('$baseUrl/auth/logout'); //
    print('ApiService DEBUG: logout - URL: $url'); //

    try {
      //
      final response = await http //
          .post(
            //
            url, //
            headers: {
              //
              'Accept': 'application/json', //
              'Authorization': 'Bearer $token', //
            },
          )
          .timeout(const Duration(seconds: 15)); //

      print(
        'ApiService DEBUG: logout - Status Code: ${response.statusCode}',
      ); //
      // print('ApiService DEBUG: logout - Response Body: ${response.body}');
    } catch (e) {
      //
      print(
        //
        'ApiService DEBUG: logout - Error saat request logout ke server: $e', //
      );
      // Abaikan error jaringan saat logout, yang penting token lokal dihapus
    } finally {
      //
      await removeToken(); // Selalu hapus token lokal
      print('ApiService DEBUG: logout - Token lokal berhasil dihapus.'); //
    }
  }

  Future<http.Response> createIdPdam({
    //
    required String nomor, //
    required int idPelanggan, //
  }) async {
    final headers = {
      //
      'Content-Type': 'application/json', //
      'Accept': 'application/json', //
    };
    final url = Uri.parse('$baseUrl/id-pdam'); //
    final body = jsonEncode({'nomor': nomor, 'id_pelanggan': idPelanggan}); //
    return await http.post(url, headers: headers, body: body); //
  }

  Future<Map<String, dynamic>> getTunggakan(String pdamId) async {
    //
    final token = await getToken(); //
    print('Fetching tunggakan untuk ID: $pdamId'); //
    await Future.delayed(const Duration(seconds: 2)); //
    if (pdamId == "PDAM001") {
      //
      return {
        //
        'id_pdam': pdamId, //
        'jumlah': 150000, //
        'bulan': 'April 2025', //
        'jatuh_tempo': '2025-05-20', //
      };
    } else if (pdamId == "PDAM002") {
      //
      return {
        //
        'id_pdam': pdamId, //
        'jumlah': 75000, //
        'bulan': 'April 2025', //
        'jatuh_tempo': '2025-05-20', //
      };
    }
    return {
      //
      'id_pdam': pdamId, //
      'jumlah': 0, //
      'bulan': '-', //
      'error': 'ID Tidak ditemukan atau belum ada tagihan', //
    };
  }

  Future<List<String>> fetchPdamNumbersByPelanggan(String idPelanggan) async {
    //
    print(
      //
      'ApiService DEBUG: Memulai fetchPdamNumbersByPelanggan untuk ID Pelanggan: $idPelanggan', //
    );
    try {
      //
      final url = Uri.parse('$baseUrl/id-pdam/$idPelanggan'); //
      print('ApiService DEBUG: Memanggil URL: $url'); //
      final response = await http.get(url); //

      print('ApiService DEBUG: Status Code: ${response.statusCode}'); //
      print('ApiService DEBUG: Response Body: ${response.body}'); //

      if (response.statusCode == 200) {
        //
        final Map<String, dynamic> responseData = json.decode(response.body); //
        if (responseData.containsKey('data') && responseData['data'] is List) {
          //
          final List<dynamic> data = responseData['data']; //
          final List<String> pdamNumbers = //
              data //
                  .map((item) {
                    //
                    final pdamNum = item['nomor']?.toString(); //
                    print(
                      'ApiService DEBUG: Ditemukan Nomor PDAM: $pdamNum',
                    ); //
                    return pdamNum; //
                  })
                  .whereType<String>() //
                  .toList(); //
          print(
            //
            'ApiService DEBUG: Berhasil mengambil ${pdamNumbers.length} Nomor PDAM.', //
          );
          return pdamNumbers; //
        } else {
          print(
            //
            'ApiService DEBUG: Respons tidak memiliki kunci "data" atau bukan list.', //
          );
          return []; //
        }
      } else {
        print(
          //
          'ApiService DEBUG: Gagal mengambil daftar nomor PDAM untuk ID Pelanggan $idPelanggan: ${response.statusCode} ${response.body}', //
        );
        return []; //
      }
    } catch (e) {
      //
      print(
        //
        'ApiService DEBUG: Error saat mengambil daftar nomor PDAM untuk ID Pelanggan $idPelanggan: $e', //
      );
      return []; //
    }
  }

  Future<http.Response> buatPengaduan(
    //
    Map<String, String> fields, { //
    File? fotoBukti, //
    File? fotoRumah, //
  }) async {
    final uri = Uri.parse('$baseUrl/pengaduan'); //
    final request = http.MultipartRequest('POST', uri); //

    final token = await getToken(); // Ambil token
    if (token != null) {
      //
      request.headers['Authorization'] = //
          'Bearer $token'; // Tambahkan token ke header
    }
    request.headers['Accept'] = 'application/json'; //

    request.fields.addAll(fields); //

    if (fotoBukti != null) {
      //
      request.files.add(
        //
        await http.MultipartFile.fromPath(
          //
          'foto_bukti', //
          fotoBukti.path, //
          filename: fotoBukti.path.split('/').last, //
        ),
      );
    }
    if (fotoRumah != null) {
      //
      request.files.add(
        //
        await http.MultipartFile.fromPath(
          //
          'foto_rumah', //
          fotoRumah.path, //
          filename: fotoRumah.path.split('/').last, //
        ),
      );
    }
    return await http.Response.fromStream(await request.send()); //
  }

  Future<List<Pengaduan>> getPetugasAssignments(int idPetugas) async {
    //
    final token = await getToken(); // Ambil token
    final response = await http.get(
      //
      Uri.parse('$baseUrl/petugas/$idPetugas/assignments'), //
      headers: {
        //
        'Accept': 'application/json', //
        if (token != null) //
          'Authorization': //
              'Bearer $token', // Tambahkan token ke header jika ada
      },
    );

    if (response.statusCode == 200) {
      //
      List<dynamic> body = jsonDecode(response.body); //
      // Jika data ada di dalam key 'data' atau 'assignments'
      // if (body is Map<String, dynamic> && body.containsKey('data')) {
      //   body = body['data'];
      // }
      List<Pengaduan> assignments = //
          body //
              .map(
                //
                (dynamic item) => //
                    Pengaduan.fromJson(item as Map<String, dynamic>), //
              )
              .toList(); //
      return assignments; //
    } else {
      throw Exception(
        //
        'Failed to load assignments (Status Code: ${response.statusCode})', //
      );
    }
  }

  Future<Map<String, dynamic>> updateStatusTugas({
    //
    required int idTugas, //
    required String tipeTugas, //
    required String newStatus, //
    String? keterangan, // <--- TAMBAHKAN PARAMETER INI
  }) async {
    final token = await getToken(); //
    final url = Uri.parse(
      '$baseUrl/tugas/$tipeTugas/$idTugas/update-status',
    ); //
    print('Calling updateStatusTugas: $url with status: $newStatus'); //

    final Map<String, String> bodyData = {'status': newStatus}; //
    if (keterangan != null && keterangan.isNotEmpty) {
      // <--- KIRIM KETERANGAN JIKA ADA
      bodyData['keterangan'] = keterangan; //
    }

    final response = await http.post(
      //
      url, //
      headers: {
        //
        'Accept': 'application/json', //
        if (token != null) 'Authorization': 'Bearer $token', //
      },
      body: bodyData, // <--- GUNAKAN bodyData
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      //
      return jsonDecode(response.body) as Map<String, dynamic>; //
    } else {
      print(
        //
        'Error updateStatusTugas (${response.statusCode}): ${response.body}', //
      );
      final errorBody = jsonDecode(response.body); // Ambil body error
      throw Exception(
        //
        errorBody['message'] ??
            'Gagal update status tugas: ${response.body}', // Tampilkan pesan dari backend
      );
    }
  }

  Future<Map<String, dynamic>> uploadFotoTugas({
    //
    required int idTugas, //
    required String tipeTugas, //
    required String jenisFoto, //
    required String imagePath, //
    String? newStatus, //
  }) async {
    final token = await getToken(); //
    final url = Uri.parse(
      //
      '$baseUrl/petugas/tugas/$tipeTugas/$idTugas/upload-foto', //
    );
    print('Calling uploadFotoTugas: $url for $jenisFoto'); //

    var request = http.MultipartRequest('POST', url); //
    if (token != null) {
      //
      request.headers['Authorization'] = 'Bearer $token'; //
    }
    request.headers['Accept'] = 'application/json'; //

    request.fields['jenis_foto'] = jenisFoto; //
    if (newStatus != null) {
      //
      request.fields['status'] = newStatus; //
    }
    request.files.add(await http.MultipartFile.fromPath('foto', imagePath)); //

    final streamedResponse = await request.send(); //
    final response = await http.Response.fromStream(streamedResponse); //

    if (response.statusCode == 200 || response.statusCode == 201) {
      //
      return jsonDecode(response.body) as Map<String, dynamic>; //
    } else {
      print(
        'Error uploadFotoTugas (${response.statusCode}): ${response.body}',
      ); //
      throw Exception('Gagal upload foto tugas: ${response.body}'); //
    }
  }

  Future<Petugas> getPetugasProfile() async {
    //
    final token = await getToken(); //
    if (token == null) {
      //
      throw Exception('Token tidak ditemukan, silakan login ulang.'); //
    }

    final response = await http.get(
      //
      Uri.parse('$baseUrl/user/profile'), //
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }, //
    );

    if (response.statusCode == 200) {
      //
      final responseData = jsonDecode(response.body); //
      // Periksa apakah data ada di dalam key 'user'
      if (responseData.containsKey('user') &&
          responseData['user'] is Map<String, dynamic>) {
        return Petugas.fromJson(responseData['user']);
      }
      // Fallback jika 'user' tidak ada (meski seharusnya ada berdasarkan AuthController)
      return Petugas.fromJson(responseData);
    } else {
      throw Exception('Gagal mengambil data profil: ${response.body}'); //
    }
  }

  Future<Map<String, dynamic>> submitRating({
    //
    required String tipeLaporan, // 'pengaduan' atau 'temuan_kebocoran'
    int? idLaporan, // Wajib jika tipeLaporan == 'pengaduan'
    String? trackingCode, // Wajib jika tipeLaporan == 'temuan_kebocoran'
    // DIUBAH: Menerima tiga parameter rating
    required int ratingKecepatan, //
    required int ratingPelayanan, //
    required int ratingHasil, //
    String? komentar, //
    String? token, // Akan dikirim jika tipeLaporan == 'pengaduan'
  }) async {
    final String endpointPath; //
    // DIUBAH: Body sekarang berisi tiga field rating
    Map<String, dynamic> body = {
      //
      'rating_kecepatan': ratingKecepatan, //
      'rating_pelayanan': ratingPelayanan, //
      'rating_hasil': ratingHasil, //
    };

    if (tipeLaporan == 'pengaduan') {
      //
      if (idLaporan == null) {
        //
        throw ArgumentError("id_laporan wajib untuk tipe pengaduan."); //
      }
      endpointPath = '/rating/pengaduan'; //
      body['id_laporan'] = idLaporan; //
    } else if (tipeLaporan == 'temuan_kebocoran') {
      //
      if (trackingCode == null) {
        //
        throw ArgumentError(
          "tracking_code wajib untuk tipe temuan_kebocoran.",
        ); //
      }
      endpointPath = '/rating/temuan-kebocoran'; //
      body['tracking_code'] = trackingCode; //
    } else {
      throw ArgumentError("tipe_laporan tidak valid."); //
    }

    if (komentar != null && komentar.isNotEmpty) {
      //
      // Backend Anda sepertinya menerima 'komentar' bukan 'komentar_rating' saat submit
      body['komentar_rating'] = komentar; //
    }

    final url = Uri.parse('$baseUrl$endpointPath'); //

    final Map<String, String> headers = {
      //
      'Content-Type': 'application/json', //
      'Accept': 'application/json', //
      if (token != null) 'Authorization': 'Bearer $token', //
    };

    print('ApiService DEBUG: submitRating - URL: $url'); //
    print('ApiService DEBUG: submitRating - Headers: $headers'); //
    print('ApiService DEBUG: submitRating - Body: ${jsonEncode(body)}'); //

    final response = await http.post(
      //
      url, //
      headers: headers, //
      body: jsonEncode(body), //
    );

    print(
      //
      'ApiService DEBUG: submitRating - Status Code: ${response.statusCode}', //
    );
    print(
      'ApiService DEBUG: submitRating - Response Body: ${response.body}',
    ); //

    final responseBody = jsonDecode(response.body); //
    if (response.statusCode == 200 || response.statusCode == 201) {
      //
      if (responseBody is Map<String, dynamic> && //
          responseBody.containsKey('success') && //
          responseBody['success'] == true) {
        //
        return responseBody; //
      } else if (responseBody is Map<String, dynamic>) {
        //
        return responseBody; //
      } else {
        throw Exception(
          //
          'Format respons tidak diharapkan setelah submit rating.', //
        );
      }
    } else if (response.statusCode == 401) {
      //
      throw Exception(responseBody['message'] ?? 'Autentikasi gagal (401).'); //
    } else if (response.statusCode == 403) {
      //
      throw Exception(responseBody['message'] ?? 'Akses ditolak (403).'); //
    } else if (response.statusCode == 422) {
      //
      final errors = responseBody['errors']; //
      throw Exception(
        //
        'Data tidak valid (422): ${errors?.toString() ?? response.body}', //
      );
    } else {
      throw Exception(
        //
        'Gagal mengirim penilaian. Status: ${response.statusCode}. Pesan: ${responseBody['message'] ?? response.body}', //
      );
    }
  }

  Future<Map<String, dynamic>> respondToComplaint(
    int laporanId,
    String choice,
  ) async {
    final token = await getToken();
    if (token == null) throw Exception('Autentikasi diperlukan.');

    final url = Uri.parse('$baseUrl/pengaduan/$laporanId/respon-pelanggan');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'choice': choice}),
          )
          .timeout(const Duration(seconds: 30));

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Gagal mengirim respon.');
      }
    } on TimeoutException {
      throw Exception('Server tidak merespons. Periksa koneksi Anda.');
    } catch (e) {
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  // === PERUBAHAN FUNGSI updatePetugasProfile ===
  Future<Petugas> updatePetugasProfile({
    required Map<String, String> data, // Menggunakan Map untuk fleksibilitas
    File? profileImage,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Token tidak ditemukan, silakan login ulang.');
    }

    final url = Uri.parse('$baseUrl/user/profile');
    late http.Response response;

    try {
      if (profileImage != null) {
        // Logika untuk upload file foto (Multipart)
        var request = http.MultipartRequest('POST', url);
        request.fields['_method'] = 'PATCH'; // Method spoofing untuk Laravel
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';

        // Tambahkan semua data teks ke request.fields
        data.forEach((key, value) {
          request.fields[key] = value;
        });

        // Tambahkan file foto
        request.files.add(
          await http.MultipartFile.fromPath('foto_profil', profileImage.path),
        );

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // Logika untuk update data teks saja
        response = await http.patch(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(data),
        );
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Asumsi respons selalu ada di dalam key 'user'
        if (responseData.containsKey('user')) {
          return Petugas.fromJson(responseData['user']);
        } else {
          // Fallback jika tidak ada key 'user', meskipun seharusnya ada
          return Petugas.fromJson(responseData);
        }
      } else {
        // Tangani error dengan lebih baik
        String errorMessage = 'Gagal memperbarui profil.';
        if (responseData.containsKey('message')) {
          errorMessage += ' Pesan: ${responseData['message']}';
        }
        if (responseData.containsKey('errors') &&
            responseData['errors'] is Map) {
          (responseData['errors'] as Map).forEach((key, value) {
            if (value is List) {
              errorMessage += '\n- ${value.join(', ')}';
            }
          });
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Tangkap semua jenis error dan lempar ulang dengan pesan yang lebih jelas
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateStatusCalonPelanggan({
    //
    required int idCalon, //
    required String newStatus, //
    String? imagePath, // Path ke file foto, nullable
  }) async {
    final token = await getToken(); //
    final url = Uri.parse(
      //
      '$baseUrl/petugas/calon-pelanggan/$idCalon/update-status', //
    );

    var request = http.MultipartRequest('POST', url); //
    if (token != null) {
      //
      request.headers['Authorization'] = 'Bearer $token'; //
    }
    request.headers['Accept'] = 'application/json'; //

    request.fields['status'] = newStatus; //

    // Tambahkan file foto jika ada path-nya
    if (imagePath != null && imagePath.isNotEmpty) {
      //
      request.files.add(
        await http.MultipartFile.fromPath('foto', imagePath),
      ); //
    }

    final streamedResponse = await request.send(); //
    final response = await http.Response.fromStream(streamedResponse); //

    if (response.statusCode == 200 || response.statusCode == 201) {
      //
      return jsonDecode(response.body) as Map<String, dynamic>; //
    } else {
      print(
        //
        'Error updateStatusCalonPelanggan (${response.statusCode}): ${response.body}', //
      );
      final errorBody = jsonDecode(response.body); //
      throw Exception(
        //
        errorBody['message'] ??
            'Gagal update status tugas: ${response.body}', //
      );
    }
  }
}

  // Di dalam class ApiService
