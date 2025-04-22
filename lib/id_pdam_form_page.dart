import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class IdPdamFormPage extends StatefulWidget {
  const IdPdamFormPage({super.key});

  @override
  State<IdPdamFormPage> createState() => _IdPdamFormPageState();
}

class _IdPdamFormPageState extends State<IdPdamFormPage> {
  final TextEditingController _idPdamController = TextEditingController();

  Future<void> _simpanIdPdam() async {
    final idPdam = _idPdamController.text.trim();
    if (idPdam.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID PDAM tidak boleh kosong')),
      );
      return;
    }

    // Ambil ID pelanggan yang sudah login dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idPelanggan = prefs.getString('id_pelanggan');

    if (idPelanggan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID pelanggan tidak ditemukan')),
      );
      return;
    }

    // Kirim ID PDAM ke backend API
    try {
      final response = await http.post(
        Uri.parse(
          'http://10.0.168.221:8000/api/id-pdam', // Ganti dengan URL API kamu
        ),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer $token', // Jika perlu token
        },
        body: jsonEncode({
          'id_pelanggan': idPelanggan, // Menggunakan id_pelanggan yang login
          'nomor_id_pdam': idPdam,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID PDAM berhasil disimpan ke server')),
        );
        Navigator.pop(context); // Kembali ke halaman sebelumnya
      } else {
        final responseBody = jsonDecode(response.body);
        String errorMessage =
            responseBody['message'] ?? 'Gagal mengirim data ke server';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim ID PDAM ke server')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Isi ID PDAM")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _idPdamController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Masukkan ID PDAM',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _simpanIdPdam,
              child: const Text("Simpan ID PDAM"),
            ),
          ],
        ),
      ),
    );
  }
}
