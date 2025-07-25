// File: lib/detail_calon_pelanggan_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class DetailCalonPelangganPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const DetailCalonPelangganPage({super.key, required this.data});

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    status = status.toLowerCase();
    if (status.contains('terpasang')) {
      return Colors.green.shade700;
    }
    if (status.contains('pemasangan') || status.contains('survey')) {
      return Colors.blue.shade700;
    }
    if (status.contains('menunggu')) {
      return Colors.orange.shade700;
    }
    if (status.contains('diterima')) {
      return Colors.lightBlue.shade600;
    }
    if (status.contains('ditolak') || status.contains('dibatalkan')) {
      return Colors.red.shade700;
    }
    return Colors.grey.shade600;
  }

  IconData _getStatusIcon(String? status) {
    if (status == null) return Ionicons.help_circle_outline;
    status = status.toLowerCase();
    if (status.contains('terpasang')) {
      return Ionicons.checkmark_circle_outline;
    }
    if (status.contains('pemasangan')) {
      return Ionicons.construct_outline;
    }
    if (status.contains('survey')) {
      return Ionicons.search_circle_outline;
    }
    if (status.contains('menunggu')) {
      return Ionicons.time_outline;
    }
    if (status.contains('diterima')) {
      return Ionicons.shield_checkmark_outline;
    }
    if (status.contains('ditolak') || status.contains('dibatalkan')) {
      return Ionicons.close_circle_outline;
    }
    return Ionicons.information_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final String status = data['status'] ?? 'Status Tidak Diketahui';
    final String namaLengkap = data['nama_lengkap'] ?? 'Nama Tidak Tersedia';
    final String tglDaftar = data['tanggal_pendaftaran'] ?? '-';
    final String namaCabang = data['nama_cabang'] ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Pendaftaran'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail Pendaftaran Anda',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              namaLengkap,
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
            const Divider(height: 30),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 70,
                      color: _getStatusColor(status),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Status Terkini',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow(
              icon: Ionicons.calendar_outline,
              label: 'Tanggal Pendaftaran',
              value: tglDaftar,
            ),
            _buildInfoRow(
              icon: Ionicons.business_outline,
              label: 'Cabang Pendaftaran',
              value: namaCabang,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Harap hubungi cabang terkait atau datang langsung ke kantor cabang untuk informasi lebih lanjut mengenai status pendaftaran Anda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
