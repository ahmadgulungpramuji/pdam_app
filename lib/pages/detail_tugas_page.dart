// lib/pages/petugas/detail_tugas_page.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pdam_app/services/chat_service.dart';
import 'package:pdam_app/pages/shared/reusable_chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailTugasPage extends StatefulWidget {
  final Tugas tugas;
  const DetailTugasPage({super.key, required this.tugas});

  @override
  State<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  // Warna Tema (Selaras dengan Home Petugas)
  final Color _primaryNavy = const Color(0xFF1565C0);
  final Color _slateText = const Color(0xFF1E293B);
  final Color _subText = const Color(0xFF64748B);
  final Color _bgGrey = const Color(0xFFF8F9FA);

  late Tugas _tugasSaatIni;
  late Tugas _currentTugas;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final DateFormat _dateFormatter = DateFormat('EEEE, dd MMM yyyy', 'id_ID');
  final DateFormat _timeFormatter = DateFormat('HH:mm', 'id_ID');

  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _currentUserData;

  @override
  void initState() {
    super.initState();
    _tugasSaatIni = widget.tugas;
    _currentTugas = widget.tugas;
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_data');
    if (jsonString != null && mounted) {
      setState(() {
        _currentUserData = jsonDecode(jsonString);
      });
    }
  }

  void _setLoading(bool loading) {
    if (mounted) setState(() => _isLoading = loading);
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatPhoneNumberForWhatsApp(String phone) {
    String cleanedPhone = phone.replaceAll(RegExp(r'[\s\-+]'), '');
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '62${cleanedPhone.substring(1)}';
    }
    return cleanedPhone;
  }

  // --- LOGIKA API (Status & Upload) ---
  Future<void> _updateStatus(String targetNewStatus, {String? keterangan}) async {
    _setLoading(true);
    try {
      final responseData = await _apiService.updateStatusTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        newStatus: targetNewStatus,
        keterangan: keterangan,
      );

      final Map<String, dynamic>? tugasTerbaruJson = responseData['tugas_terbaru'] as Map<String, dynamic>?;

      if (mounted) {
        if (targetNewStatus == 'dibatalkan') {
          await _showSuccessAndNavigateHome();
        } else if (tugasTerbaruJson != null) {
          setState(() {
            _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
          });
          _showSnackbar('Status berhasil diperbarui', isError: false);
        }
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal mengubah status: ${e.toString()}');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _pickAndUploadImage(String jenisFoto, String statusBaru) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1080,
    );

    if (pickedFile == null) return;

    _setLoading(true);
    try {
      final responseData = await _apiService.uploadFotoTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        jenisFoto: jenisFoto,
        imagePath: pickedFile.path,
        newStatus: statusBaru,
      );

      final Map<String, dynamic>? tugasTerbaruJson = responseData['tugas_terbaru'] as Map<String, dynamic>?;

      if (mounted && tugasTerbaruJson != null) {
        setState(() {
          _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
        });
        _showSnackbar('Foto berhasil diupload!', isError: false);
      }
    } catch (e) {
      _showSnackbar('Gagal upload foto: ${e.toString()}');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _batalkanTugas(String alasan) async {
    _setLoading(true);
    try {
      await _apiService.batalkanPenugasanMandiri(
        idTugas: _currentTugas.idTugas,
        tipeTugas: _currentTugas.tipeTugas,
        alasan: alasan,
      );
      if (mounted) await _showSuccessAndNavigateHome();
    } catch (e) {
      if (mounted) _showSnackbar('Gagal membatalkan tugas: ${e.toString()}');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        title: Text(
          'Detail Tugas',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                FadeInDown(child: _buildHeaderCard()),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 100), child: _buildLocationCard()),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 200), child: _buildDescriptionCard()),
                const SizedBox(height: 16),
                if (_tugasSaatIni.infoKontakPelapor != null)
                  FadeInUp(delay: const Duration(milliseconds: 300), child: _buildContactCard(_tugasSaatIni.infoKontakPelapor!)),
                const SizedBox(height: 24),
                
                // Bagian Foto & Aksi
                if (_tugasSaatIni.isPetugasPelapor) ...[
                  FadeInUp(delay: const Duration(milliseconds: 400), child: _buildActionSection()),
                  const SizedBox(height: 24),
                ],
                
                FadeInUp(delay: const Duration(milliseconds: 500), child: _buildFotoProgresSection()),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // 1. Header Card (Status & Kategori)
  Widget _buildHeaderCard() {
    final statusColor = _getColorForStatus(_tugasSaatIni.status);
    final DateTime waktuLokal = _tugasSaatIni.tanggalDibuatPenugasan.toLocal();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryNavy.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Text(
                  _tugasSaatIni.friendlyStatus.toUpperCase(),
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
              Text(
                '#ID-${_tugasSaatIni.idTugas}',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: _subText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _tugasSaatIni.kategoriDisplay,
            style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: _slateText),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Ionicons.calendar_outline, size: 16, color: _subText),
              const SizedBox(width: 8),
              Text(
                _dateFormatter.format(waktuLokal),
                style: GoogleFonts.manrope(fontSize: 13, color: _subText, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              Icon(Ionicons.time_outline, size: 16, color: _subText),
              const SizedBox(width: 8),
              Text(
                _timeFormatter.format(waktuLokal),
                style: GoogleFonts.manrope(fontSize: 13, color: _subText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Location Card (Peta Modern)
  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryNavy.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Ionicons.location, color: _primaryNavy, size: 20),
              const SizedBox(width: 10),
              Text('Lokasi Tugas', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: _slateText)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _tugasSaatIni.deskripsiLokasi,
            style: GoogleFonts.manrope(fontSize: 14, color: _slateText, height: 1.5),
          ),
          const SizedBox(height: 16),
          
          // Tombol Peta Modern
          if (_tugasSaatIni.lokasiMaps.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchURL(_tugasSaatIni.lokasiMaps),
                icon: const Icon(Ionicons.map_outline, size: 18),
                label: Text("Buka Google Maps", style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryNavy,
                  side: BorderSide(color: _primaryNavy.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue.shade50.withOpacity(0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 3. Description Card
  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryNavy.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Detail Laporan", style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: _slateText)),
          const SizedBox(height: 12),
          Text(
            _tugasSaatIni.deskripsi,
            style: GoogleFonts.manrope(fontSize: 14, color: _slateText, height: 1.6),
          ),
          if (_tugasSaatIni.alasanPembatalan != null && _tugasSaatIni.alasanPembatalan!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Alasan Pembatalan:", style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  Text(_tugasSaatIni.alasanPembatalan!, style: GoogleFonts.manrope(fontSize: 13, color: Colors.red.shade900)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 4. Contact Card
  Widget _buildContactCard(KontakInfo kontak) {
    bool isChatActive = _tugasSaatIni.tipeTugas == 'pengaduan' &&
        _currentUserData != null &&
        (kontak.firebaseUid != null && kontak.firebaseUid!.isNotEmpty);
    
    bool isReadOnly = !_tugasSaatIni.isPetugasPelapor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryNavy.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tugasSaatIni is PengaduanTugas ? "Data Pelanggan" : "Data Pelapor",
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: _slateText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _primaryNavy.withOpacity(0.1),
                child: Icon(Ionicons.person, color: _primaryNavy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kontak.nama, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: _slateText)),
                    Text(kontak.nomorHp, style: GoogleFonts.manrope(fontSize: 13, color: _subText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildContactAction(
                  icon: Ionicons.call,
                  color: Colors.blue.shade600,
                  label: "Telp",
                  onTap: () => _launchURL('tel:${kontak.nomorHp}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildContactAction(
                  icon: Ionicons.logo_whatsapp,
                  color: Colors.green.shade600,
                  label: "WA",
                  onTap: () {
                    final phone = _formatPhoneNumberForWhatsApp(kontak.nomorHp);
                    _launchURL('https://wa.me/$phone');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildContactAction(
                  icon: Ionicons.chatbubble_ellipses,
                  color: isChatActive ? _primaryNavy : Colors.grey,
                  label: "Chat",
                  isBadgeVisible: _getUnreadChatCount(kontak) > 0, // Helper logic below
                  onTap: isChatActive ? () => _handleChatPress(kontak, isReadOnly) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactAction({required IconData icon, required Color color, required String label, VoidCallback? onTap, bool isBadgeVisible = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
              ],
            ),
            if (isBadgeVisible)
              Positioned(
                top: -8,
                right: -8,
                child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              )
          ],
        ),
      ),
    );
  }

  // 5. Action Section (Tombol Update Status)
  Widget _buildActionSection() {
    List<Widget> buttons = [];

    switch (_tugasSaatIni.status) {
      case 'menunggu_konfirmasi':
        buttons.add(_buildBigButton("Terima Tugas", Ionicons.checkmark_circle, Colors.green.shade600, () => _updateStatus('diterima')));
        buttons.add(const SizedBox(height: 12));
        buttons.add(_buildBigButton("Tolak / Batalkan", Ionicons.close_circle, Colors.red.shade600, _showCancelDialog, isOutline: true));
        break;
      case 'diterima':
        buttons.add(_buildBigButton("Mulai Perjalanan", Ionicons.navigate, _primaryNavy, () => _updateStatus('dalam_perjalanan')));
        break;
      case 'dalam_perjalanan':
        buttons.add(_buildBigButton("Sampai & Proses (Foto Awal)", Ionicons.camera, Colors.orange.shade700, () => _pickAndUploadImage('foto_sebelum', 'diproses')));
        break;
      case 'diproses':
        buttons.add(_buildBigButton("Selesaikan (Foto Akhir)", Ionicons.checkmark_done_circle, Colors.teal.shade600, () => _pickAndUploadImage('foto_sesudah', 'selesai')));
        break;
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tindakan Diperlukan", style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: _subText)),
        const SizedBox(height: 12),
        ...buttons,
      ],
    );
  }

  Widget _buildBigButton(String label, IconData icon, Color color, VoidCallback onTap, {bool isOutline = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onTap,
        icon: Icon(icon, color: isOutline ? color : Colors.white),
        label: Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15, color: isOutline ? color : Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutline ? Colors.white : color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: isOutline ? 0 : 4,
          side: isOutline ? BorderSide(color: color, width: 2) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: color.withOpacity(0.4),
        ),
      ),
    );
  }

  // 6. Photo Progress Section
  Widget _buildFotoProgresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Dokumentasi", style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: _slateText)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildPhotoItem("Sebelum", _tugasSaatIni.fotoSebelumUrl)),
            const SizedBox(width: 16),
            Expanded(child: _buildPhotoItem("Sesudah", _tugasSaatIni.fotoSesudahUrl)),
          ],
        ),
        // Foto Bukti Awal (Tambahan)
        if (_tugasSaatIni.fotoBuktiUrl != null) ...[
          const SizedBox(height: 16),
          Text("Bukti Laporan Awal", style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: _subText)),
          const SizedBox(height: 8),
          _buildPhotoItem("Bukti Awal", _tugasSaatIni.fotoBuktiUrl, isWide: true),
        ]
      ],
    );
  }

  Widget _buildPhotoItem(String label, String? url, {bool isWide = false}) {
    bool hasImage = url != null && url.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isWide) Text(label, style: GoogleFonts.manrope(fontSize: 12, color: _subText, fontWeight: FontWeight.w600)),
        if (!isWide) const SizedBox(height: 6),
        GestureDetector(
          onTap: hasImage ? () => _showImageDialog(url) : null,
          child: Container(
            height: isWide ? 180 : 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              image: hasImage ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
            ),
            child: !hasImage
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Ionicons.image_outline, color: Colors.grey.shade400, size: 30),
                      if (isWide) Text("Tidak ada foto", style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500))
                    ],
                  )
                : null,
          ),
        ),
      ],
    );
  }

  // --- HELPERS & DIALOGS ---

  int _getUnreadChatCount(KontakInfo kontak) {
    // Note: This is a placeholder for direct access. 
    // In a real StreamBuilder scenario within the button, we handle it there.
    // For simplicity in this layout, we just return 0 or rely on the Badge widget logic if needed separately.
    return 0; 
  }

  Future<void> _handleChatPress(KontakInfo kontak, bool isReadOnly) async {
    final cabangData = _tugasSaatIni.cabang as Map<String, dynamic>?;
    final int? cabangId = cabangData?['id'] as int?;

    if (cabangId == null) {
      _showSnackbar('Info cabang tidak valid.');
      return;
    }

    _setLoading(true);
    try {
      final pelangganInfo = {'id': kontak.id, 'nama': kontak.nama, 'firebase_uid': kontak.firebaseUid};
      final threadId = await _chatService.getOrCreateTugasChatThread(
        tipeTugas: _tugasSaatIni.tipeTugas,
        idTugas: _tugasSaatIni.idTugas,
        currentUser: _currentUserData!,
        otherUsers: [pelangganInfo],
        cabangId: cabangId,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReusableChatPage(
              threadId: threadId,
              chatTitle: "Chat #${_tugasSaatIni.idTugas}",
              currentUser: _currentUserData!,
              isReadOnly: isReadOnly,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackbar('Gagal membuka chat');
    } finally {
      _setLoading(false);
    }
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Batalkan Tugas?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'Masukkan alasan pembatalan...',
              hintStyle: GoogleFonts.manrope(fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: GoogleFonts.manrope(color: _subText)),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alasan wajib diisi")));
                  return;
                }
                Navigator.pop(context);
                _batalkanTugas(reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Konfirmasi', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessAndNavigateHome() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Ionicons.checkmark_circle, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text("Berhasil!", style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Status tugas telah diperbarui.", style: GoogleFonts.manrope(color: _subText), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Back to Home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Kembali ke Daftar", style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'selesai': return Colors.teal;
      case 'dibatalkan': return Colors.red;
      case 'diproses': return Colors.blue;
      case 'diterima': return _primaryNavy;
      case 'dalam_perjalanan': return Colors.orange.shade800;
      default: return Colors.grey;
    }
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackbar('Tidak dapat membuka link');
    }
  }
}