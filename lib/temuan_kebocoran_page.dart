import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart'; // Import ApiService untuk memanggil API

class TemuanKebocoranPage extends StatefulWidget {
  const TemuanKebocoranPage({super.key});

  @override
  State<TemuanKebocoranPage> createState() => _TemuanKebocoranPageState();
}

class _TemuanKebocoranPageState extends State<TemuanKebocoranPage> {
  final _formKey = GlobalKey<FormState>();
  // Base URL API diambil dari ApiService
  final ApiService _apiService = ApiService(); // Inisialisasi ApiService
  late String _apiUrlSubmit;

  final TextEditingController _lokasiMapsController = TextEditingController();
  final TextEditingController _deskripsiLokasiController =
      TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nomorHpController = TextEditingController();

  // --- State untuk Dropdown Cabang (dari API) ---
  int? _selectedCabangId;
  // Struktur data cabang kini menyertakan lokasi_maps
  List<Map<String, dynamic>> _cabangOptionsApi = [];
  bool _isCabangLoading = true;
  String? _cabangError;

  // State untuk menyimpan lokasi pengguna setelah didapatkan
  Position? _currentPosition;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false; // Status loading untuk submit form
  bool _isFetchingLocation = false; // Status loading untuk get location

  @override
  void initState() {
    super.initState();
    // URL API Submit dan Cabang diambil dari ApiService
    _apiUrlSubmit = '${_apiService.baseUrl}/temuan-kebocoran';

    // Panggil fungsi untuk mengambil data cabang
    _fetchCabangOptions().then((_) {
      // Setelah data cabang didapat, jika lokasi sudah ada (misal dari sesi sebelumnya
      // atau jika lokasi sudah didapat sebelum cabang selesai load),
      // coba temukan cabang terdekat. Ini dipanggil di sini sebagai fallback
      // jika _getCurrentLocation selesai lebih dulu dari _fetchCabangOptions.
      if (_currentPosition != null) {
        _findNearestBranch();
      }
    });

    // Panggil fungsi untuk mendapatkan lokasi saat ini secara otomatis saat halaman dimuat
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _lokasiMapsController.dispose();
    _deskripsiLokasiController.dispose();
    _namaController.dispose(); // Don't forget to dispose
    _nomorHpController.dispose(); // Don't forget to dispose
    super.dispose();
  }

  // --- Fungsi utilitas untuk menampilkan SnackBar ---
  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- Fungsi untuk mengambil data Cabang dari API ---
  // Modifikasi untuk menyimpan lokasi_maps
  Future<void> _fetchCabangOptions() async {
    setState(() {
      _isCabangLoading = true;
      _cabangError = null;
    });

    try {
      // Menggunakan ApiService untuk fetch cabangs
      final response = await _apiService.fetchCabangs().timeout(
        const Duration(seconds: 15),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Map<String, dynamic>> options = [];

        for (var item in data) {
          // Pastikan item memiliki semua key yang dibutuhkan
          if (item is Map<String, dynamic> &&
              item.containsKey('id') &&
              item.containsKey('nama_cabang') &&
              item.containsKey('lokasi_maps')) {
            // Ambil lokasi_maps juga
            options.add({
              'id': item['id'] as int,
              'nama_cabang': item['nama_cabang'] as String,
              'lokasi_maps': item['lokasi_maps'] as String?, // Bisa null
            });
          } else {
            print("Invalid item format from API: $item");
          }
        }

        setState(() {
          _cabangOptionsApi = options;
          // Tidak perlu mereset _selectedCabangId di sini lagi
        });

        // Setelah data cabang berhasil dimuat, coba temukan cabang terdekat
        // hanya jika lokasi pengguna sudah tersedia
        if (_currentPosition != null) {
          _findNearestBranch();
        }
      } else {
        setState(() {
          _cabangError = 'Gagal memuat cabang: Status ${response.statusCode}';
        });
        print(
          'Failed to load cabang: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cabangError = 'Terjadi kesalahan saat memuat data cabang.';
      });
      print('Error fetching cabang: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCabangLoading = false;
        });
      }
    }
  }

  // --- Fungsi untuk mendapatkan lokasi saat ini ---
  // Modifikasi untuk menyimpan Position object dan memanggil _findNearestBranch
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _currentPosition = null; // Reset lokasi sebelumnya
      _lokasiMapsController.clear(); // Kosongkan input saat fetch
      _selectedCabangId = null; // Reset pilihan cabang saat mencari lokasi baru
    });

    LocationPermission permission;
    bool serviceEnabled;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('Layanan lokasi tidak aktif. Silakan aktifkan.');
        // ignore: use_build_context_synchronously
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Izin lokasi ditolak.');
          // ignore: use_build_context_synchronously
          if (mounted) setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackbar(
          'Izin lokasi ditolak permanen. Aktifkan di pengaturan aplikasi.',
        );
        // ignore: use_build_context_synchronously
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        // Menambahkan timeout agar tidak menunggu terlalu lama jika sinyal jelek
        // Jika timeout, catch block akan menangkapnya
        timeLimit: const Duration(seconds: 10),
      );

      String locationString = '${position.latitude}, ${position.longitude}';
      if (mounted) {
        setState(() {
          _currentPosition = position; // Simpan objek Position
          _lokasiMapsController.text = locationString; // Set text field
        });
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi berhasil didapatkan!')),
        );

        // Setelah lokasi didapat, coba temukan cabang terdekat
        _findNearestBranch();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal mendapatkan lokasi: ${e.toString()}');
      }
      print("Error getting location: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  // --- Fungsi untuk menemukan cabang terdekat ---
  void _findNearestBranch() {
    // Jalankan hanya jika data cabang sudah dimuat DAN lokasi pengguna sudah didapat
    if (_cabangOptionsApi.isEmpty || _currentPosition == null) {
      print(
        "Tidak bisa menemukan cabang terdekat: data cabang kosong atau lokasi pengguna belum didapat.",
      );
      // Jika data cabang ada tapi tidak ada lokasi pengguna, pastikan pilihan cabang direset jika sebelumnya terisi otomatis
      if (_cabangOptionsApi.isNotEmpty &&
          _currentPosition == null &&
          _selectedCabangId != null) {
        setState(() {
          _selectedCabangId = null; // Reset pilihan otomatis jika lokasi hilang
        });
      }
      return;
    }

    int? nearestBranchId;
    double minDistance =
        double.infinity; // Jarak minimum diinisialisasi sangat besar
    String nearestBranchName =
        "Tidak Ditemukan"; // Nama cabang terdekat untuk pesan

    for (var cabang in _cabangOptionsApi) {
      // Pastikan cabang memiliki lokasi_maps dan tidak null/kosong
      if (cabang['lokasi_maps'] != null &&
          (cabang['lokasi_maps'] as String).isNotEmpty) {
        try {
          // Parse koordinat cabang
          final List<String> latLng = (cabang['lokasi_maps'] as String).split(
            ',',
          );
          if (latLng.length == 2) {
            final double branchLat = double.parse(latLng[0].trim());
            final double branchLng = double.parse(latLng[1].trim());

            // Hitung jarak menggunakan geolocator (dalam meter)
            final double distanceInMeters = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              branchLat,
              branchLng,
            );

            // Perbarui cabang terdekat jika jarak saat ini lebih pendek
            if (distanceInMeters < minDistance) {
              minDistance = distanceInMeters;
              nearestBranchId = cabang['id'] as int;
              nearestBranchName = cabang['nama_cabang'] as String;
            }
          } else {
            print(
              "Invalid location maps format for branch ID ${cabang['id']}: ${cabang['lokasi_maps']}",
            );
          }
        } catch (e) {
          print(
            "Error parsing location maps or calculating distance for branch ID ${cabang['id']}: $e",
          );
          // Lanjutkan ke cabang berikutnya jika terjadi error
        }
      } else {
        print("Branch ID ${cabang['id']} has no location maps data.");
      }
    }

    // Jika ada cabang terdekat ditemukan, update state
    if (nearestBranchId != null) {
      print(
        "Cabang terdekat ditemukan: ID $nearestBranchId, Nama: $nearestBranchName",
      );
      if (mounted) {
        setState(() {
          _selectedCabangId = nearestBranchId;
        });
        // Tampilkan pesan ke user
        _showSnackbar(
          'Cabang terdekat ($nearestBranchName) otomatis dipilih.',
          isError: false,
        );
      }
    } else {
      print(
        "Tidak ada cabang yang valid dengan data lokasi ditemukan atau dihitung.",
      );
      // Jika tidak ada cabang terdekat yang ditemukan (misal semua cabang tanpa data lokasi),
      // pastikan pilihan cabang direset
      if (mounted && _selectedCabangId != null) {
        setState(() {
          _selectedCabangId = null;
        });
      }
      _showSnackbar('Tidak ada cabang terdekat yang dapat dihitung.');
    }
  }

  // --- Fungsi untuk memilih gambar ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Gagal memilih gambar: $e');
    }
  }

  // --- Fungsi untuk menampilkan pilihan sumber gambar ---
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Ambil Foto'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Fungsi untuk mengirim data ke API ---
  // Termasuk penambahan logika untuk mengambil tracking_code dan navigasi
  // --- Fungsi untuk mengirim data ke API ---
  // Termasuk penambahan logika untuk mengambil tracking_code dan navigasi
  Future<void> _submitForm() async {
    // Validasi form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCabangId == null) {
      _showSnackbar('Silakan pilih cabang terlebih dahulu.');
      return;
    }
    // Validasi lokasi_maps dan deskripsi_lokasi sudah di handle validator TextFormField

    setState(() {
      _isLoading = true; // Loading untuk proses submit
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrlSubmit));

      // --- START: Bagian yang perlu diubah/dihapus ---
      // Dapatkan token dari storage untuk otentikasi (jika diperlukan oleh endpoint submit)
      // Jika endpoint submit membutuhkan token (misal menggunakan auth:sanctum)
      // Anda perlu menambahkan header Authorization
      final token =
          await _apiService
              .getToken(); // Masih bisa ambil token, tapi tidak diwajibkan
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        // Tambahkan header lain jika diperlukan oleh backend, misal Accept/Content-Type
        request.headers['Accept'] = 'application/json';
      }
      // Hapus blok ELSE ini yang MENGHENTIKAN submit jika token == null
      /*
   else {
    // Handle case where user is not logged in but accessing this page (shouldn't happen if route is protected)
    print("Warning: Submitting form without authentication token.");
    // Mungkin beri tahu user untuk login dulu atau batalkan submit
    _showSnackbar(
     'Anda harus login untuk mengirim laporan.',
     isError: true,
    );
    if (mounted) {
     setState(() {
      _isLoading = false;
     }); // Hentikan loading
    }
    return; // Hentikan proses submit
   }
        */
      // --- END: Bagian yang perlu diubah/dihapus ---

      // Tambahkan field data (bagian ini tetap)
      // Add new fields for nama and nomor_hp
      request.fields['nama_pelapor'] = _namaController.text;
      request.fields['nomor_hp_pelapor'] = _nomorHpController.text;
      request.fields['id_cabang'] = _selectedCabangId.toString();
      request.fields['lokasi_maps'] = _lokasiMapsController.text;
      request.fields['deskripsi_lokasi'] = _deskripsiLokasiController.text;

      // Tambahkan foto bukti (bagian ini tetap)
      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('foto_bukti', _imageFile!.path),
        );
      }

      // Kirim request (bagian ini tetap)
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      // Proses respons (bagian ini tetap)
      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String? trackingCode =
            responseData['tracking_code']; // <<< Ambil tracking_code dari respons

        _showSnackbar(
          responseData['message'] ?? 'Data temuan berhasil dikirim!',
          isError: false,
        );

        // Reset form setelah berhasil (bagian ini tetap)
        _formKey.currentState?.reset();
        setState(() {
          _namaController.clear();
          _nomorHpController.clear();
          _selectedCabangId = null;
          _imageFile = null;
          _lokasiMapsController.clear();
          _deskripsiLokasiController.clear();
          _currentPosition = null; // Reset juga lokasi pengguna
        });

        // <<< Navigasi ke halaman tracking jika kode tracking didapat (bagian ini tetap)
        if (trackingCode != null && trackingCode.isNotEmpty) {
          // Menggunakan pushReplacementNamed agar user tidak bisa kembali ke form submit setelah submit
          // Jika ingin user bisa kembali ke form (misal untuk submit laporan lain), gunakan Navigator.pushNamed
          Navigator.pushReplacementNamed(
            context,
            '/tracking_page', // Ganti dengan route halaman tracking Anda
            arguments: trackingCode, // Kirim kode tracking sebagai argumen
          );
        } else {
          // Jika tidak ada kode tracking dari backend
          print(
            'Warning: No tracking code received from backend. Staying on form page.',
          );
          // Anda bisa tambahkan navigasi ke halaman home atau lain jika diperlukan
          // Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // Handle error status codes (bagian ini tetap)
        String errorMessage =
            'Gagal mengirim data. Status: ${response.statusCode}';
        try {
          var responseBody = jsonDecode(response.body);
          if (responseBody['message'] != null) {
            errorMessage = '${responseBody['message']}';
          }
          // Cek jika ada detail error validasi dari Laravel (jika dikembalikan)
          if (responseBody['errors'] != null) {
            print("Errors from backend: ${responseBody['errors']}");
            // Anda bisa menambahkan logika untuk menampilkan error validasi spesifik
          }
        } catch (e) {
          print('Failed to parse error body: $e');
          errorMessage += '. Body: ${response.body}';
        }
        _showSnackbar(errorMessage);
      }
    } catch (e) {
      _showSnackbar(
        'Terjadi kesalahan saat mengirim data: ${e.toString()}',
        isError: true,
      ); // Tampilkan error E
      print("Error submitting form: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Selesai loading submit
        });
      }
    }
  }

  // --- Helper Widget untuk membangun bagian Dropdown Cabang ---
  Widget _buildCabangDropdown() {
    if (_isCabangLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 15),
            Text("Memuat data cabang...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_cabangError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 30),
            const SizedBox(height: 8),
            Text(
              _cabangError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              onPressed: _fetchCabangOptions, // Tombol untuk retry
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    // Tampilan dropdown jika data berhasil dimuat dan tidak ada error
    return DropdownButtonFormField<int>(
      value: _selectedCabangId,
      hint: const Text('Pilih Cabang'),
      isExpanded: true,
      items:
          _cabangOptionsApi.isEmpty
              ? [
                const DropdownMenuItem<int>(
                  value: null,
                  // Disable dropdown item jika tidak ada data cabang
                  enabled: false,
                  child: Text(
                    "Tidak ada data cabang tersedia",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ]
              : _cabangOptionsApi.map((cabang) {
                return DropdownMenuItem<int>(
                  value: cabang['id'] as int,
                  child: Text(cabang['nama_cabang'] as String),
                );
              }).toList(),
      onChanged:
          _cabangOptionsApi.isEmpty ||
                  _isLoading // Disable onChanged jika list kosong atau sedang loading
              ? null
              : (value) {
                setState(() {
                  _selectedCabangId = value;
                });
              },
      validator: (value) {
        // Validasi hanya jika tidak sedang loading, tidak ada error cabang,
        // ada options cabang, dan value masih null
        if (!_isCabangLoading &&
            _cabangError == null &&
            _cabangOptionsApi.isNotEmpty &&
            value == null) {
          return 'Cabang tidak boleh kosong';
        }
        return null;
      },
      decoration: const InputDecoration(
        labelText: 'Cabang Pelaporan',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_city),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form Temuan Kebocoran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Gunakan Helper Widget untuk Dropdown Cabang ---
              _buildCabangDropdown(),
              const SizedBox(height: 16.0),
              // --- Input Nama Pelapor ---
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pelapor',
                  hintText: 'Masukkan nama Anda',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama pelapor tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // --- Input Nomor HP Pelapor ---
              TextFormField(
                controller: _nomorHpController,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  hintText: 'Contoh: 081234567890',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone, // Set keyboard type to phone
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nomor HP tidak boleh kosong';
                  }
                  // Optional: Add more robust phone number validation if needed
                  if (value.length < 10 || value.length > 15) {
                    return 'Nomor HP harus antara 10 sampai 15 digit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // --- Input Lokasi Maps ---
              TextFormField(
                controller: _lokasiMapsController,
                // Lokasi maps ini bisa diisi otomatis atau manual,
                // tapi otomatisasi cabang terdekat hanya berjalan jika lokasi didapat otomatis
                readOnly: _isFetchingLocation, // Jadikan readOnly saat fetching
                decoration: InputDecoration(
                  labelText: 'Lokasi Maps (Otomatis/Manual)',
                  hintText:
                      'Tekan ikon untuk mengisi otomatis & cari cabang terdekat',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.map),
                  suffixIcon:
                      _isFetchingLocation
                          ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                          : IconButton(
                            icon: const Icon(Icons.my_location),
                            tooltip:
                                'Dapatkan Lokasi Saat Ini & Cari Cabang Terdekat',
                            // Disable tombol jika cabang masih loading atau error, atau jika sudah fetching lokasi
                            onPressed:
                                (_isCabangLoading ||
                                        _cabangError != null ||
                                        _isFetchingLocation)
                                    ? null
                                    : _getCurrentLocation,
                          ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lokasi maps tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // --- Input Deskripsi Lokasi ---
              TextFormField(
                controller: _deskripsiLokasiController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Detail Lokasi',
                  hintText: 'Contoh: Depan toko X, dekat tiang listrik Y',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Deskripsi lokasi tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),

              // --- Input Foto Bukti ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto Bukti Kebocoran:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8.0),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child:
                              _imageFile == null
                                  ? const Center(
                                    child: Text('Belum ada gambar dipilih'),
                                  )
                                  : ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const Center(
                                          child: Text('Gagal memuat gambar'),
                                        );
                                      },
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 12.0),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Pilih/Ambil Foto Bukti'),
                          onPressed: () => _showImageSourceActionSheet(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                        // Karena foto_bukti nullable di backend, tidak perlu validator di sini
                        // untuk memastikan file dipilih. Namun, Anda bisa tambahkan jika ingin
                        // validasi frontend yang lebih ketat dari backend.
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // --- Tombol Submit ---
              ElevatedButton(
                // Disable jika sedang loading submit ATAU loading cabang ATAU fetching lokasi
                // Disable juga jika _cabangOptionsApi kosong (kecuali ada error load cabang)
                // Disable juga jika _cabangError != null
                onPressed:
                    _isLoading ||
                            _isCabangLoading ||
                            _isFetchingLocation ||
                            (_cabangOptionsApi.isEmpty && _cabangError == null)
                        ? null
                        : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text('Kirim Laporan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
