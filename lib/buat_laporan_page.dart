import 'dart:convert';
import 'dart:io'; // Import for File type
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // For geolocation
import 'package:image_picker/image_picker.dart'; // For image picking
import 'package:pdam_app/api_service.dart'; // Ensure your ApiService import is correct
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences

// This PdamIdManager is a dummy and might not be needed if all customer IDs are fetched from API.
// You can remove or adapt it based on your application's actual needs.
class PdamIdManager {
  static Future<List<String>> getPdamIds() async {
    await Future.delayed(const Duration(seconds: 1));
    return ['CUST001', 'CUST002', 'CUST003'];
  }
}

class BuatLaporanPage extends StatefulWidget {
  const BuatLaporanPage({super.key});

  @override
  State<BuatLaporanPage> createState() => _BuatLaporanPageState();
}

class _BuatLaporanPageState extends State<BuatLaporanPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _lokasiMapsController =
      TextEditingController(); // For automatic coordinates
  final TextEditingController _deskripsiLokasiManualController =
      TextEditingController(); // For manual location description

  String? _selectedJenisLaporan;
  final List<Map<String, String>> _jenisLaporanOptions = [
    {'value': 'air_tidak_mengalir', 'label': 'Kebocoran Pipa'},
    {'value': 'air_keruh', 'label': 'Air Keruh'},
    {'value': 'water_meter_rusak', 'label': 'Meteran Rusak'},
    {'value': 'angka_meter_tidak_sesuai', 'label': 'Angka Meter Tidak Sesuai'},
    {'value': 'water_meter_tidak_sesuai', 'label': 'Water Meter Tidak Sesuai'},
    {'value': 'tagihan_membengkak', 'label': 'Tagihan Membengkak'},
    // Jika Anda memutuskan untuk menambahkan 'lainnya' di backend, tambahkan di sini juga:
    // {'value': 'lainnya', 'label': 'Lainnya'},
  ];

  String? _loggedInPelangganId; // Customer ID from login data (internal use)
  List<String> _pdamIdNumbersList =
      []; // List of PDAM numbers for the logged-in customer
  String? _selectedPdamIdNumber; // Selected PDAM number from the dropdown
  int? _selectedCabangId; // Branch ID determined automatically

  File? _fotoBuktiFile; // File for foto_bukti
  File? _fotoRumahFile; // File for foto_rumah
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Load initial data when the page is initialized
  }

  // Function to load initial data: Customer ID from login, list of PDAM IDs, and current location
  Future<void> _loadInitialData() async {
    print('BuatLaporanPage DEBUG: Memulai _loadInitialData');
    setState(() => _isLoading = true);
    await _getLoggedInPelangganId(); // Get Customer ID from SharedPreferences
    await _getCurrentLocation();
    setState(() => _isLoading = false);
    print(
      'BuatLaporanPage DEBUG: _loadInitialData selesai. _loggedInPelangganId: $_loggedInPelangganId, _pdamIdNumbersList: $_pdamIdNumbersList',
    );
  }

  // Function to get Customer ID from SharedPreferences
  Future<void> _getLoggedInPelangganId() async {
    print('BuatLaporanPage DEBUG: Memulai _getLoggedInPelangganId');
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      try {
        final userData = jsonDecode(userDataString) as Map<String, dynamic>;
        // Assuming 'id' in user_data is the customer_id
        final pelangganId = userData['id']?.toString();
        print(
          'BuatLaporanPage DEBUG: User data ditemukan. ID Pelanggan: $pelangganId',
        );
        if (mounted) {
          setState(() {
            _loggedInPelangganId = pelangganId;
          });
          if (_loggedInPelangganId != null) {
            await _fetchPdamIdsAndSetDefault(
              _loggedInPelangganId!,
            ); // Load list of PDAM IDs
          } else {
            _showSnackbar('ID Pelanggan tidak ditemukan di data login.');
            print('BuatLaporanPage DEBUG: ID Pelanggan null dari user_data.');
          }
        }
      } catch (e) {
        _showSnackbar('Gagal memuat data pengguna dari penyimpanan lokal: $e');
        print('BuatLaporanPage DEBUG: Error parsing user_data: $e');
      }
    } else {
      _showSnackbar('Data pengguna tidak ditemukan. Harap login kembali.');
      print(
        'BuatLaporanPage DEBUG: user_data tidak ditemukan di SharedPreferences.',
      );
      // Optional: Navigasi ke halaman login
      // Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  // Function to fetch list of PDAM numbers and set default selection
  Future<void> _fetchPdamIdsAndSetDefault(String idPelanggan) async {
    print(
      'BuatLaporanPage DEBUG: Memulai _fetchPdamIdsAndSetDefault untuk ID Pelanggan: $idPelanggan',
    );
    setState(() => _isLoading = true);
    try {
      final pdamNumbers = await _apiService.fetchPdamNumbersByPelanggan(
        idPelanggan,
      );
      if (mounted) {
        setState(() {
          _pdamIdNumbersList = pdamNumbers;
          print(
            'BuatLaporanPage DEBUG: Daftar Nomor PDAM dari API: $_pdamIdNumbersList',
          );
          if (_pdamIdNumbersList.isNotEmpty) {
            _selectedPdamIdNumber =
                _pdamIdNumbersList.first; // Select the first PDAM ID as default
            _otomatisPilihCabang(
              _selectedPdamIdNumber,
            ); // Determine branch based on the selected PDAM ID
            print(
              'BuatLaporanPage DEBUG: Nomor PDAM default: $_selectedPdamIdNumber',
            );
          } else {
            _selectedPdamIdNumber = null;
            _selectedCabangId = null;
            print('BuatLaporanPage DEBUG: Daftar Nomor PDAM kosong.');
          }
        });
      }
    } catch (e) {
      _showSnackbar('Gagal mengambil daftar nomor PDAM: $e');
      print('BuatLaporanPage DEBUG: Error mengambil daftar nomor PDAM: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Function to automatically get current GPS location
  Future<void> _getCurrentLocation() async {
    print('BuatLaporanPage DEBUG: Memulai _getCurrentLocation');
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackbar('Layanan lokasi dinonaktifkan. Harap aktifkan.');
      print('BuatLaporanPage DEBUG: Layanan lokasi dinonaktifkan.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackbar(
          'Izin lokasi ditolak. Tidak dapat mengisi lokasi otomatis.',
        );
        print('BuatLaporanPage DEBUG: Izin lokasi ditolak.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackbar(
        'Izin lokasi ditolak secara permanen. Harap izinkan dari pengaturan aplikasi.',
      );
      print('BuatLaporanPage DEBUG: Izin lokasi ditolak permanen.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _lokasiMapsController.text =
              '${position.latitude}, ${position.longitude}';
          print(
            'BuatLaporanPage DEBUG: Lokasi otomatis terisi: ${_lokasiMapsController.text}',
          );
        });
      }
    } catch (e) {
      _showSnackbar('Gagal mendapatkan lokasi otomatis: $e');
      print('BuatLaporanPage DEBUG: Error mendapatkan lokasi otomatis: $e');
    }
  }

  // Function to automatically determine Branch ID based on the first 2 digits of PDAM ID
  void _otomatisPilihCabang(String? idPdam) {
    print(
      'BuatLaporanPage DEBUG: Memulai _otomatisPilihCabang dengan ID PDAM: $idPdam',
    );
    if (idPdam != null && idPdam.length >= 2) {
      final duaDigit = idPdam.substring(0, 2);
      switch (duaDigit) {
        case '10':
          _selectedCabangId = 1;
          break;
        case '12':
          _selectedCabangId = 2;
          break;
        case '15':
          _selectedCabangId = 3;
          break;
        case '20':
          _selectedCabangId = 4;
          break;
        case '30':
          _selectedCabangId = 5;
          break;
        case '40':
          _selectedCabangId = 6;
          break;
        case '50':
          _selectedCabangId = 7;
          break;
        case '60':
          _selectedCabangId = 8;
          break;
        default:
          _selectedCabangId = null;
          break;
      }
    } else {
      _selectedCabangId = null;
    }
    print(
      'BuatLaporanPage DEBUG: Cabang ID Otomatis: $_selectedCabangId',
    ); // For console debugging
  }

  // Function to pick an image from gallery or camera
  Future<void> _pickImage(ImageSource source, String type) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        if (type == 'bukti') {
          _fotoBuktiFile = File(pickedFile.path);
        } else if (type == 'rumah') {
          _fotoRumahFile = File(pickedFile.path);
        }
        print('BuatLaporanPage DEBUG: Foto $type terpilih: ${pickedFile.path}');
      });
    }
  }

  @override
  void dispose() {
    _deskripsiController.dispose();
    _lokasiMapsController.dispose();
    _deskripsiLokasiManualController.dispose();
    super.dispose();
  }

  // Function to display a Snackbar
  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
    print('BuatLaporanPage DEBUG: Snackbar: $message');
  }

  // Function to submit the complaint report to the API
  Future<void> _submitLaporan() async {
    print('BuatLaporanPage DEBUG: Memulai _submitLaporan');
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Harap lengkapi semua field yang dibutuhkan.');
      return;
    }
    if (_selectedJenisLaporan == null) {
      _showSnackbar('Pilih jenis laporan terlebih dahulu.');
      return;
    }
    if (_loggedInPelangganId == null) {
      _showSnackbar('ID Pelanggan tidak tersedia. Harap login kembali.');
      return;
    }
    if (_selectedPdamIdNumber == null) {
      _showSnackbar('Pilih Nomor PDAM terlebih dahulu.');
      return;
    }
    if (_selectedCabangId == null) {
      _showSnackbar(
        'Cabang tidak dapat ditentukan. Harap periksa Nomor PDAM yang dipilih.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Prepare report data in Map<String, String> format
      Map<String, String> dataLaporan = {
        'id_pelanggan': _loggedInPelangganId!, // Customer ID from login data
        'id_pdam': _selectedPdamIdNumber!, // Selected PDAM number from dropdown
        'id_cabang': _selectedCabangId.toString(),
        'kategori':
            _selectedJenisLaporan!, // <-- PASTIKAN INI ADALAH NILAI ENUM LARAVEL YANG BENAR
        'lokasi_maps': _lokasiMapsController.text,
        'deskripsi_lokasi': _deskripsiLokasiManualController.text,
        'deskripsi': _deskripsiController.text,
        // tanggal_pengaduan and status will be filled in the backend
        // id_petugas_pelapor will be null or ignored in the backend
      };
      print(
        'BuatLaporanPage DEBUG: Data Laporan yang akan dikirim: $dataLaporan',
      );
      print('BuatLaporanPage DEBUG: Foto Bukti: ${_fotoBuktiFile?.path}');
      print('BuatLaporanPage DEBUG: Foto Rumah: ${_fotoRumahFile?.path}');

      // Call API service to submit report with photos
      final response = await _apiService.buatPengaduan(
        dataLaporan,
        fotoBukti: _fotoBuktiFile,
        fotoRumah: _fotoRumahFile,
      );

      if (!mounted) return;

      print(
        'BuatLaporanPage DEBUG: Status Code Pengiriman Laporan: ${response.statusCode}',
      );
      print(
        'BuatLaporanPage DEBUG: Response Body Pengiriman Laporan: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        jsonDecode(response.body);
        _showSnackbar('Laporan berhasil dikirim!', isError: false);
        _formKey.currentState?.reset(); // Reset form
        _deskripsiController.clear();
        _lokasiMapsController.clear();
        _deskripsiLokasiManualController.clear();
        setState(() {
          _selectedJenisLaporan = null;
          _fotoBuktiFile = null;
          _fotoRumahFile = null;
          _selectedPdamIdNumber = null; // Reset PDAM number selected
          _selectedCabangId = null; // Reset branch
          _pdamIdNumbersList = []; // Clear PDAM numbers list
        });
        _loadInitialData(); // Reload location and PDAM/Branch IDs data
      } else {
        final responseData = jsonDecode(response.body);
        _showSnackbar(
          'Gagal mengirim laporan: ${responseData['message'] ?? response.reasonPhrase}',
        );
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan: $e');
      print('BuatLaporanPage DEBUG: Error saat mengirim laporan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Laporan Pengaduan'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading // Show loading indicator if initial data is being loaded
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Formulir Pengaduan Pelanggan',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Dropdown untuk Nomor PDAM
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Pilih Nomor PDAM',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: const Icon(
                            Icons.numbers,
                            color: Colors.blueAccent,
                          ),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                        value: _selectedPdamIdNumber,
                        items:
                            _pdamIdNumbersList.map((pdamNum) {
                              return DropdownMenuItem(
                                value: pdamNum,
                                child: Text(pdamNum),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPdamIdNumber = value;
                            _otomatisPilihCabang(
                              value,
                            ); // Determine branch based on the selected PDAM ID
                          });
                        },
                        validator:
                            (value) =>
                                value == null ? 'Pilih Nomor PDAM' : null,
                      ),
                      const SizedBox(height: 16),

                      // Tampilkan ID Cabang Otomatis (Read-only)
                      TextFormField(
                        controller: TextEditingController(
                          text:
                              _selectedCabangId?.toString() ??
                              'Memuat ID Cabang...',
                        ),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'ID Cabang (Otomatis)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: const Icon(
                            Icons.apartment,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Jenis Laporan (Kategori)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Jenis Laporan (Kategori)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            color: Colors.blueAccent,
                          ),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                        value: _selectedJenisLaporan,
                        items:
                            _jenisLaporanOptions.map((option) {
                              return DropdownMenuItem<String>(
                                value: option['value'],
                                child: Text(option['label']!),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedJenisLaporan = value);
                        },
                        validator:
                            (value) =>
                                value == null ? 'Pilih jenis laporan' : null,
                      ),
                      const SizedBox(height: 16),

                      // Lokasi Maps (Otomatis)
                      TextFormField(
                        controller: _lokasiMapsController,
                        readOnly: true, // Cannot be manually edited
                        decoration: InputDecoration(
                          labelText: 'Lokasi Maps (Otomatis)',
                          hintText: 'Latitude, Longitude',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: const Icon(
                            Icons.map_outlined,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Lokasi maps tidak boleh kosong'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Deskripsi Lokasi (Manual)
                      TextFormField(
                        controller: _deskripsiLokasiManualController,
                        decoration: InputDecoration(
                          labelText: 'Deskripsi Lokasi Kejadian (Manual)',
                          hintText:
                              'Contoh: Depan rumah, dekat tiang listrik, dll.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: const Icon(
                            Icons.location_city_outlined,
                            color: Colors.blueAccent,
                          ),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                        maxLines: 2,
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Deskripsi lokasi tidak boleh kosong'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Main Report Description
                      TextFormField(
                        controller: _deskripsiController,
                        decoration: InputDecoration(
                          labelText: 'Deskripsi Lengkap Laporan',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: const Icon(
                            Icons.description_outlined,
                            color: Colors.blueAccent,
                          ),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                        maxLines: 4,
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Deskripsi laporan tidak boleh kosong'
                                    : null,
                      ),
                      const SizedBox(height: 24),

                      // Photo Proof Upload Button
                      _buildPhotoPickerButton(
                        label: 'Unggah Foto Bukti',
                        file: _fotoBuktiFile,
                        onPressed:
                            () => _showImageSourceActionSheet(
                              context,
                              (source) => _pickImage(source, 'bukti'),
                            ),
                      ),
                      if (_fotoBuktiFile != null) ...[
                        const SizedBox(height: 8),
                        Image.file(
                          _fotoBuktiFile!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),

                      // House Photo Upload Button
                      _buildPhotoPickerButton(
                        label: 'Unggah Foto Rumah',
                        file: _fotoRumahFile,
                        onPressed:
                            () => _showImageSourceActionSheet(
                              context,
                              (source) => _pickImage(source, 'rumah'),
                            ),
                      ),
                      if (_fotoRumahFile != null) ...[
                        const SizedBox(height: 8),
                        Image.file(
                          _fotoRumahFile!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 30),

                      // Submit Report Button
                      ElevatedButton.icon(
                        icon:
                            _isLoading
                                ? const SizedBox.shrink()
                                : const Icon(
                                  Icons.send_outlined,
                                  color: Colors.white,
                                ),
                        label:
                            _isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Kirim Laporan',
                                  style: TextStyle(color: Colors.white),
                                ),
                        onPressed: _isLoading ? null : _submitLaporan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  // Helper widget for photo selection buttons
  Widget _buildPhotoPickerButton({
    required String label,
    required File? file,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        file != null ? Icons.check_circle_outline : Icons.camera_alt_outlined,
        color: file != null ? Colors.green : Colors.black87,
      ),
      label: Text(
        file != null ? 'Foto Terpilih: ${file.path.split('/').last}' : label,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            file != null ? Colors.green.shade100 : Colors.grey[200],
        foregroundColor: file != null ? Colors.green.shade800 : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        elevation: 2,
      ),
    );
  }

  // Displays an action sheet for image source selection (Camera/Gallery)
  void _showImageSourceActionSheet(
    BuildContext context,
    Function(ImageSource) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
