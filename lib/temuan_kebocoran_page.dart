import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (!_formKey.currentState!.validate()) {
      _showSnackbar(
        'Harap perbaiki error pada form sebelum mengirim.',
        isError: true,
      );
      return;
    }
    if (_selectedCabangId == null) {
      _showSnackbar('Silakan pilih cabang terlebih dahulu.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // _apiUrlSubmit adalah '${_apiService.baseUrl}/temuan-kebocoran'
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrlSubmit));

      // Untuk endpoint publik submit temuan kebocoran, kita TIDAK mengirim token.
      // Header Accept disarankan untuk API yang merespons JSON.
      request.headers['Accept'] = 'application/json';

      // Menambahkan field data ke request
      request.fields['nama_pelapor'] = _namaController.text;
      request.fields['nomor_hp_pelapor'] = _nomorHpController.text;
      request.fields['id_cabang'] = _selectedCabangId.toString();
      request.fields['lokasi_maps'] = _lokasiMapsController.text;
      request.fields['deskripsi_lokasi'] = _deskripsiLokasiController.text;
      // Status dan tanggal_temuan akan di-generate oleh backend.

      // Menambahkan file gambar jika ada
      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_bukti', // Nama field di backend Laravel
            _imageFile!.path,
            filename:
                _imageFile!.path
                    .split('/')
                    .last, // Opsional, tapi baik untuk ada
          ),
        );
      }

      print(
        "TemuanKebocoranPage: Mengirim data temuan kebocoran ke $_apiUrlSubmit...",
      );
      // Menambahkan timeout untuk request
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          // Timeout sedikit lebih lama untuk upload file
          throw TimeoutException(
            'Waktu pengiriman habis, server tidak merespons dalam 45 detik.',
          );
        },
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return; // Cek jika widget masih ada di tree

      final responseData = jsonDecode(response.body);
      print(
        "TemuanKebocoranPage: Respons dari server (${response.statusCode}): $responseData",
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 201: Created, 200: OK
        // Mengambil tracking_code dari dalam objek 'data'
        final String? trackingCode =
            responseData['data']?['tracking_code'] as String?;

        _showSnackbar(
          responseData['message'] ??
              'Laporan temuan kebocoran berhasil dikirim!',
          isError: false,
        );

        // Reset form setelah berhasil
        _formKey.currentState?.reset();
        setState(() {
          _namaController.clear();
          _nomorHpController.clear();
          _selectedCabangId = null;
          _imageFile = null;
          _lokasiMapsController.clear();
          _deskripsiLokasiController.clear();
          _currentPosition =
              null; // Reset juga lokasi pengguna agar bisa fetch ulang
        });

        // Menampilkan tracking code kepada pengguna dengan opsi salin
        if (trackingCode != null && trackingCode.isNotEmpty) {
          print(
            "TemuanKebocoranPage: Laporan Berhasil. Tracking Code: $trackingCode",
          );
          // ignore: use_build_context_synchronously
          await showDialog(
            context: context,
            barrierDismissible:
                false, // User harus menekan tombol untuk menutup
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                title: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.green,
                      size: 28,
                    ),
                    SizedBox(width: 10),
                    Text('Laporan Terkirim!'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terima kasih, laporan Anda telah kami terima. Mohon simpan kode pelacakan berikut:',
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: SelectableText(
                              trackingCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy_all_rounded,
                              color: Theme.of(context).primaryColor,
                            ),
                            tooltip: 'Salin Kode Pelacakan',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: trackingCode),
                              );
                              ScaffoldMessenger.of(
                                dialogContext,
                              ).hideCurrentSnackBar(); // Sembunyikan snackbar sebelumnya jika ada
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Kode Pelacakan disalin ke clipboard!',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Anda dapat menggunakan kode ini untuk melacak status progres laporan Anda melalui fitur "Lacak Laporan" (biasanya ada di halaman login atau menu utama).',
                    ),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('OK', style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Tutup dialog
                      // Setelah dialog ditutup, Anda bisa mengarahkan user, misalnya kembali ke halaman login atau home
                      // if (mounted) {
                      //   Navigator.of(context).pushNamedAndRemoveUntil('/nama_rute_halaman_login_anda', (Route<dynamic> route) => false);
                      // }
                    },
                  ),
                ],
              );
            },
          );
        } else {
          print(
            'TemuanKebocoranPage: Peringatan! Kode pelacakan tidak diterima dari backend.',
          );
          _showSnackbar(
            'Laporan berhasil dikirim, namun kode pelacakan tidak tersedia saat ini.',
            isError: true,
          );
        }
      } else {
        // Handle error dari server (status code bukan 200/201)
        String errorMessage =
            'Gagal mengirim data (Status: ${response.statusCode})';
        if (responseData != null && responseData['message'] != null) {
          errorMessage = responseData['message'] as String;
          if (responseData['errors'] != null && responseData['errors'] is Map) {
            // Menampilkan error validasi dari Laravel jika ada
            final errors = responseData['errors'] as Map<String, dynamic>;
            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                errorMessage +=
                    '\n- ${value[0]}'; // Ambil pesan error pertama untuk setiap field
              }
            });
          }
        } else if (responseData != null) {
          errorMessage +=
              '. Detail: ${responseData.toString().substring(0, 100)}...'; // Potong jika terlalu panjang
        } else {
          errorMessage += '. Tidak ada detail tambahan dari server.';
        }
        _showSnackbar(errorMessage, isError: true);
        print("TemuanKebocoranPage: Error dari server: $responseData");
      }
    } catch (e) {
      if (mounted) {
        String errorMsgToShow = 'Terjadi kesalahan saat mengirim laporan.';
        if (e is TimeoutException) {
          errorMsgToShow =
              'Server tidak merespons. Periksa koneksi internet Anda.';
        } else if (e.toString().isNotEmpty) {
          errorMsgToShow = e.toString();
          // Hapus prefix "Exception: " jika ada
          if (errorMsgToShow.startsWith("Exception: ")) {
            errorMsgToShow = errorMsgToShow.substring("Exception: ".length);
          }
        }
        _showSnackbar(errorMsgToShow, isError: true);
      }
      print("TemuanKebocoranPage: Error saat _submitForm: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
