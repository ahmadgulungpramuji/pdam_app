// lib/pages/detail_tugas_page.dart
// import 'dart:convert'; // Dihapus karena tidak terpakai setelah print di-comment
import 'dart:io'; // Untuk File
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart'; // Untuk Ionicons
import 'package:image_picker/image_picker.dart'; // Untuk memilih gambar
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:pdam_app/api_service.dart';
import 'package:url_launcher/url_launcher.dart'; // Untuk membuka URL

import 'package:pdam_app/models/tugas_model.dart'; // Model Tugas Anda

class DetailTugasPage extends StatefulWidget {
  final Tugas tugas;

  const DetailTugasPage({super.key, required this.tugas});

  @override
  State<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  late Tugas _tugasSaatIni;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  File? _pickedFotoSebelum;
  File? _pickedFotoSesudah;

  final DateFormat _dateFormatter = DateFormat(
    'EEEE, dd MMMM yyyy',
    'id_ID',
  ); // yyyy untuk tahun 4 digit
  final DateFormat _timeFormatter = DateFormat('HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    _tugasSaatIni = widget.tugas;
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'menunggu_konfirmasi':
        return Colors.orange.shade700;
      case 'diterima':
        return Colors.blue.shade700;
      case 'dalam_perjalanan':
        return Colors.lightBlue.shade600;
      case 'diproses':
        return Colors.green.shade700;
      case 'selesai':
        return Colors.teal.shade600;
      case 'dibatalkan':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Map<String, dynamic> _prepareJsonForLocalUpdate(
    Tugas currentTask, {
    String? newStatus,
    String? newFotoUrl,
    String? jenisFotoForUrlUpdate,
  }) {
    Map<String, dynamic> json = {
      'id_penugasan_internal': currentTask.idPenugasanInternal,
      'tipe_tugas': currentTask.tipeTugas,
      'is_petugas_pelapor': currentTask.isPetugasPelapor,
      'id_tugas': currentTask.idTugas,
      'deskripsi': currentTask.deskripsi,
      'deskripsi_lokasi': currentTask.deskripsiLokasi,
      'lokasi_maps': currentTask.lokasiMaps,
      'status': newStatus ?? currentTask.status,
      'tanggal_tugas': currentTask.tanggalTugas,
      'foto_bukti': currentTask.fotoBukti,
      'tanggal_dibuat_penugasan':
          currentTask.tanggalDibuatPenugasan.toIso8601String(),
      'detail_tugas_lengkap': Map<String, dynamic>.from(
        currentTask.detailTugasLengkap ?? {},
      ),
    };

    if (currentTask is PengaduanTugas) {
      json['kategori'] =
          (currentTask.detailTugasLengkap?['kategori'] as String?) ??
          currentTask.kategoriDisplay;
      json['pelanggan'] =
          currentTask.pelanggan != null
              ? {
                'nama': currentTask.pelanggan!.nama,
                'nomor_hp': currentTask.pelanggan!.nomorHp,
              }
              : null;
    } else if (currentTask is TemuanTugas) {
      json['pelapor_temuan'] =
          currentTask.pelaporTemuan != null
              ? {
                'nama': currentTask.pelaporTemuan!.nama,
                'nomor_hp': currentTask.pelaporTemuan!.nomorHp,
              }
              : null;
    }

    if (jenisFotoForUrlUpdate != null && newFotoUrl != null) {
      if (json['detail_tugas_lengkap'] is! Map<String, dynamic>) {
        json['detail_tugas_lengkap'] = <String, dynamic>{};
      }
      (json['detail_tugas_lengkap']
              as Map<String, dynamic>)['${jenisFotoForUrlUpdate}_url'] =
          newFotoUrl;
    }
    return json;
  }

  Future<void> _updateStatus(String targetNewStatus) async {
    _setLoading(true);
    try {
      final responseData = await _apiService.updateStatusTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        newStatus: targetNewStatus,
      );
      if (mounted) {
        setState(() {
          final Map<String, dynamic>? tugasTerbaruJson =
              responseData['tugas_terbaru'] as Map<String, dynamic>?;

          if (tugasTerbaruJson != null) {
            _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
          } else {
            Map<String, dynamic> fallbackJson = _prepareJsonForLocalUpdate(
              _tugasSaatIni,
              newStatus:
                  responseData['status_baru'] as String? ?? targetNewStatus,
            );
            _tugasSaatIni = Tugas.fromJson(fallbackJson);
          }
        });
        _showSnackbar(
          'Status berhasil diubah ke: ${_tugasSaatIni.friendlyStatus}',
          isError: false,
        );
      }
    } catch (e) {
      _showSnackbar('Gagal mengubah status: $e');
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  Future<void> _pickAndUploadImage(
    String jenisFotoUntukUpload,
    String statusSetelahUpload,
  ) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedFile == null) {
      _showSnackbar('Pemilihan gambar dibatalkan.', isError: true);
      return;
    }

    File imageFile = File(pickedFile.path);
    if (jenisFotoUntukUpload == 'foto_sebelum') {
      setState(() => _pickedFotoSebelum = imageFile);
    } else if (jenisFotoUntukUpload == 'foto_sesudah') {
      setState(() => _pickedFotoSesudah = imageFile);
    }

    _setLoading(true);
    try {
      final responseData = await _apiService.uploadFotoTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        jenisFoto: jenisFotoUntukUpload,
        imagePath: pickedFile.path,
        newStatus: statusSetelahUpload,
      );

      if (mounted) {
        setState(() {
          final Map<String, dynamic>? tugasTerbaruJson =
              responseData['tugas_terbaru'] as Map<String, dynamic>?;

          if (tugasTerbaruJson != null) {
            _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
          } else {
            String? newFotoUrl =
                responseData['url_foto_$jenisFotoUntukUpload'] as String?;
            Map<String, dynamic> fallbackJson = _prepareJsonForLocalUpdate(
              _tugasSaatIni,
              newStatus:
                  responseData['status_baru'] as String? ?? statusSetelahUpload,
              newFotoUrl: newFotoUrl,
              jenisFotoForUrlUpdate: jenisFotoUntukUpload,
            );
            _tugasSaatIni = Tugas.fromJson(fallbackJson);
          }

          if (jenisFotoUntukUpload == 'foto_sebelum') {
            _pickedFotoSebelum = null;
          }
          if (jenisFotoUntukUpload == 'foto_sesudah') {
            _pickedFotoSesudah = null;
          }
        });
        _showSnackbar(
          'Foto ${jenisFotoUntukUpload.replaceAll("_", " ")} berhasil diupload & status diperbarui!',
          isError: false,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Gagal upload ${jenisFotoUntukUpload.replaceAll("_", " ")}: $e',
      );
      if (mounted) {
        setState(() {
          if (jenisFotoUntukUpload == 'foto_sebelum') {
            _pickedFotoSebelum = null;
          }
          if (jenisFotoUntukUpload == 'foto_sesudah') {
            _pickedFotoSesudah = null;
          }
        });
      }
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Tugas',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(),
                const SizedBox(height: 20),
                if (_tugasSaatIni.isPetugasPelapor) _buildActionSection(),
                const SizedBox(height: 20),
                _buildFotoProgresSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: const Color.fromRGBO(0, 0, 0, 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // --- DEFINISI _buildInfoRow DITAMBAHKAN KEMBALI DI SINI ---
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue[600]),
          const SizedBox(width: 12),
          Text(
            '$label ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child:
                isLink && label.toLowerCase().contains('peta')
                    ? InkWell(
                      onTap:
                          value.isNotEmpty
                              ? () async {
                                // Asumsi 'value' berisi "latitude,longitude" atau URL Google Maps lengkap
                                String mapsUrl;
                                // Hapus spasi jika ada dari input koordinat
                                String cleanValue = value.replaceAll(" ", "");

                                if (cleanValue.startsWith('http')) {
                                  mapsUrl =
                                      cleanValue; // Jika sudah URL, gunakan langsung
                                } else if (cleanValue.contains(',')) {
                                  // Jika formatnya adalah "latitude,longitude"
                                  // Gunakan skema URL Google Maps yang lebih universal
                                  mapsUrl =
                                      'https://maps.google.com/?q=$cleanValue';
                                  // Alternatif menggunakan skema 'geo:' yang lebih umum untuk semua aplikasi peta
                                  // mapsUrl = 'geo:$cleanValue';
                                  // Atau untuk navigasi langsung di Google Maps:
                                  // mapsUrl = 'google.navigation:q=$cleanValue&mode=d';
                                } else {
                                  _showSnackbar(
                                    'Format data peta tidak dikenali: $value',
                                    isError: true,
                                  );
                                  return;
                                }

                                final Uri targetUri = Uri.parse(mapsUrl);

                                try {
                                  if (await canLaunchUrl(targetUri)) {
                                    await launchUrl(
                                      targetUri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    // Jika canLaunchUrl gagal, coba dengan format URL yang sedikit berbeda atau fallback
                                    // Ini bisa terjadi jika skema geo tidak terdaftar dengan baik di beberapa emulator
                                    // atau jika format http maps.google.com tidak langsung dikenali sebagai map intent
                                    Uri fallbackUri = Uri.parse(
                                      'https://www.google.com/maps/search/?api=1&query=latitude,longitude',
                                    );
                                    if (await canLaunchUrl(fallbackUri)) {
                                      await launchUrl(
                                        fallbackUri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } else {
                                      _showSnackbar(
                                        'Tidak bisa membuka aplikasi peta untuk: $value',
                                        isError: true,
                                      );
                                    }
                                  }
                                } catch (e) {
                                  _showSnackbar(
                                    'Error saat mencoba membuka peta: $e',
                                    isError: true,
                                  );
                                }
                              }
                              : null,
                      child: Text(
                        value.isNotEmpty ? value : "Data peta tidak tersedia",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color:
                              value.isNotEmpty
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade600,
                          decoration:
                              value.isNotEmpty
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                        ),
                      ),
                    )
                    : Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      softWrap: isMultiline,
                      overflow:
                          isMultiline
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                    ),
          ),
        ],
      ),
    );
  }
  // --- AKHIR DEFINISI _buildInfoRow ---

  Widget _buildInfoSection() {
    String formattedTanggalTugas = "N/A";
    String formattedWaktuPenugasan = "N/A";
    String formattedTanggalPenugasan = "N/A";

    try {
      if (_tugasSaatIni.tanggalTugas.isNotEmpty) {
        DateTime parsedDate = DateTime.parse(_tugasSaatIni.tanggalTugas);
        formattedTanggalTugas = _dateFormatter.format(parsedDate);
      }
      formattedTanggalPenugasan = _dateFormatter.format(
        _tugasSaatIni.tanggalDibuatPenugasan,
      );
      formattedWaktuPenugasan = _timeFormatter.format(
        _tugasSaatIni.tanggalDibuatPenugasan,
      );
    } catch (e) {
      /* biarkan default "N/A" */
    }

    KontakInfo? kontak = _tugasSaatIni.infoKontakPelapor;
    List<Widget> infoWidgets = [
      Text(
        _tugasSaatIni.kategoriDisplay,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.blue[700],
        ),
      ),
      const Divider(height: 24, thickness: 0.5),
      _buildInfoRow(
        Ionicons.calendar_outline,
        'Tgl Kejadian:',
        formattedTanggalTugas,
      ),
      _buildInfoRow(
        Ionicons.time_outline,
        'Ditugaskan:',
        '$formattedTanggalPenugasan, $formattedWaktuPenugasan',
      ),
      _buildInfoRow(
        Ionicons.locate_outline,
        'Deskripsi Lokasi:',
        _tugasSaatIni.deskripsiLokasi,
        isMultiline: true,
      ),
      _buildInfoRow(
        Ionicons.map_outline,
        'Link Peta:',
        _tugasSaatIni.lokasiMaps,
        isLink: true,
      ),
      _buildInfoRow(
        Ionicons.document_text_outline,
        'Deskripsi Laporan:',
        _tugasSaatIni.deskripsi,
        isMultiline: true,
      ),
    ];

    if (kontak != null) {
      infoWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Ionicons.person_outline, size: 18, color: Colors.blue[600]),
              const SizedBox(width: 12),
              Text(
                _tugasSaatIni is PengaduanTugas
                    ? 'Pelanggan: '
                    : 'Pelapor Temuan: ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Expanded(
                child: Text(
                  '${kontak.nama ?? "N/A"}${kontak.nomorHp != null && kontak.nomorHp!.isNotEmpty ? " (${kontak.nomorHp})" : ""}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (kontak.nomorHp != null && kontak.nomorHp!.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Ionicons.logo_whatsapp,
                    color: Colors.green.shade700,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Chat via WhatsApp',
                  onPressed: () async {
                    String phoneNumber = kontak.nomorHp!;
                    if (phoneNumber.startsWith('0')) {
                      phoneNumber = '62${phoneNumber.substring(1)}';
                    } else if (!phoneNumber.startsWith('62') &&
                        !phoneNumber.startsWith('+')) {
                      phoneNumber = '62$phoneNumber';
                    }
                    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

                    final Uri whatsappUri = Uri.parse(
                      'https://wa.me/$phoneNumber',
                    );

                    try {
                      if (await canLaunchUrl(whatsappUri)) {
                        await launchUrl(
                          whatsappUri,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        _showSnackbar(
                          'Tidak bisa membuka WhatsApp untuk nomor: ${kontak.nomorHp}',
                          isError: true,
                        );
                      }
                    } catch (e) {
                      _showSnackbar(
                        'Error membuka WhatsApp: $e',
                        isError: true,
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      );
    }

    infoWidgets.add(const SizedBox(height: 12));
    infoWidgets.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Ionicons.cellular_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Text(
            'Status Saat Ini: ',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              _tugasSaatIni.friendlyStatus,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _getColorForStatus(_tugasSaatIni.status),
              ),
            ),
          ),
        ],
      ),
    );

    if (_tugasSaatIni.fotoBukti != null &&
        _tugasSaatIni.fotoBukti!.isNotEmpty) {
      infoWidgets.addAll([
        const SizedBox(height: 16),
        Text(
          'Foto Bukti Awal:',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () {
              /* TODO: Implement view full image (misalnya, buka dialog atau halaman baru) */
              _showSnackbar(
                "Lihat gambar penuh: ${_tugasSaatIni.fotoBukti}",
                isError: false,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _tugasSaatIni.fotoBukti!,
                height: 220,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return Container(
                    height: 220,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                    ),
                  );
                },
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      height: 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Ionicons.image_outline,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gagal memuat',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ),
      ]);
    }

    if (_tugasSaatIni is PengaduanTugas) {
      final String? fotoRumahUrl =
          _tugasSaatIni.detailTugasLengkap?['foto_rumah_url'] as String?;
      if (fotoRumahUrl != null && fotoRumahUrl.isNotEmpty) {
        infoWidgets.addAll([
          const SizedBox(height: 16),
          Text(
            'Foto Rumah Pelanggan:',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () {
                /* TODO: Implement view full image */
                _showSnackbar(
                  "Lihat gambar penuh: $fotoRumahUrl",
                  isError: false,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  fotoRumahUrl,
                  height: 220,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return Container(
                      height: 220,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                      ),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        height: 180,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Ionicons.image_outline,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gagal memuat',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ),
        ]);
      }
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: infoWidgets,
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    List<Widget> actionButtons = [];
    if (!_tugasSaatIni.isPetugasPelapor) {
      return Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Anda bukan pelapor progres untuk tugas ini.',
            style: GoogleFonts.poppins(
              fontStyle: FontStyle.italic,
              color: Colors.grey[700],
            ),
          ),
        ),
      );
    }
    switch (_tugasSaatIni.status) {
      case 'menunggu_konfirmasi':
        actionButtons.add(
          _buildActionButton(
            label: 'Terima Laporan',
            icon: Ionicons.checkmark_circle_outline,
            onPressed: () => _updateStatus('diterima'),
            color: Colors.green[600],
          ),
        );
        break;
      case 'diterima':
        actionButtons.add(
          _buildActionButton(
            label: 'Mulai Perjalanan',
            icon: Ionicons.paper_plane_outline,
            onPressed: () => _updateStatus('dalam_perjalanan'),
            color: Colors.blue[600],
          ),
        );
        break;
      case 'dalam_perjalanan':
        actionButtons.add(
          Text(
            'Upload Foto Sebelum Pengerjaan:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        );
        if (_pickedFotoSebelum != null) {
          actionButtons.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Image.file(
                _pickedFotoSebelum!,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          );
        }
        actionButtons.add(
          _buildActionButton(
            label:
                _pickedFotoSebelum == null
                    ? 'Ambil Foto Sebelum'
                    : 'Upload Foto Sebelum',
            icon:
                _pickedFotoSebelum == null
                    ? Ionicons.camera_outline
                    : Ionicons.cloud_upload_outline,
            onPressed: () => _pickAndUploadImage('foto_sebelum', 'diproses'),
            color: Colors.orange[700],
          ),
        );
        break;
      case 'diproses':
        actionButtons.add(
          Text(
            'Upload Foto Sesudah Pengerjaan:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        );
        if (_pickedFotoSesudah != null) {
          actionButtons.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Image.file(
                _pickedFotoSesudah!,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          );
        }
        actionButtons.add(
          _buildActionButton(
            label:
                _pickedFotoSesudah == null
                    ? 'Ambil Foto Sesudah'
                    : 'Upload Foto Sesudah',
            icon:
                _pickedFotoSesudah == null
                    ? Ionicons.camera_outline
                    : Ionicons.cloud_upload_outline,
            onPressed: () => _pickAndUploadImage('foto_sesudah', 'selesai'),
            color: Colors.teal[600],
          ),
        );
        break;
      case 'selesai':
        actionButtons.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Ionicons.checkmark_done_circle,
                color: Colors.teal[600],
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Pekerjaan Telah Selesai',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.teal[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        break;
      case 'dibatalkan':
        actionButtons.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Ionicons.close_circle, color: Colors.red[700], size: 22),
              const SizedBox(width: 8),
              Text(
                'Tugas Dibatalkan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        break;
      default:
        actionButtons.add(
          Text(
            'Status tugas saat ini: ${_tugasSaatIni.friendlyStatus}',
            style: GoogleFonts.poppins(fontStyle: FontStyle.italic),
          ),
        );
    }
    if (actionButtons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aksi Petugas Pelapor',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const Divider(height: 24, thickness: 0.5),
            ...actionButtons,
          ],
        ),
      ),
    );
  }

  Widget _buildFotoProgresSection() {
    String? fotoSebelumUrl =
        _tugasSaatIni.detailTugasLengkap?['foto_sebelum_url'] as String?;
    String? fotoSesudahUrl =
        _tugasSaatIni.detailTugasLengkap?['foto_sesudah_url'] as String?;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dokumentasi Progres',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const Divider(height: 24, thickness: 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Foto Sebelum',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child:
                            _pickedFotoSebelum != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _pickedFotoSebelum!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 160,
                                  ),
                                )
                                : (fotoSebelumUrl != null &&
                                        fotoSebelumUrl.isNotEmpty
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        fotoSebelumUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 160,
                                        errorBuilder:
                                            (c, e, s) => Icon(
                                              Ionicons.image_outline,
                                              size: 50,
                                              color: Colors.grey[400],
                                            ),
                                      ),
                                    )
                                    : Icon(
                                      Ionicons.image_outline,
                                      size: 50,
                                      color: Colors.grey[400],
                                    )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Foto Sesudah',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child:
                            _pickedFotoSesudah != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _pickedFotoSesudah!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 160,
                                  ),
                                )
                                : (fotoSesudahUrl != null &&
                                        fotoSesudahUrl.isNotEmpty
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        fotoSesudahUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 160,
                                        errorBuilder:
                                            (c, e, s) => Icon(
                                              Ionicons.image_outline,
                                              size: 50,
                                              color: Colors.grey[400],
                                            ),
                                      ),
                                    )
                                    : Icon(
                                      Ionicons.image_outline,
                                      size: 50,
                                      color: Colors.grey[400],
                                    )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}
