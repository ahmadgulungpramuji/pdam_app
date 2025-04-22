import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PengaduanStatusPage extends StatefulWidget {
  const PengaduanStatusPage({super.key});

  @override
  State<PengaduanStatusPage> createState() => _PengaduanStatusPageState();
}

class _PengaduanStatusPageState extends State<PengaduanStatusPage> {
  List<dynamic> pengaduanList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPengaduanStatus();
  }

  Future<void> fetchPengaduanStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userType = prefs.getString('userType');

    if (token == null || userType != 'pelanggan') return;

    final response = await http.get(
      Uri.parse('http://10.0.168.221:8000/api/pengaduans'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        pengaduanList = data;
        isLoading = false;
      });
    } else {
      // Handle error
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status Pengaduan')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: pengaduanList.length,
                itemBuilder: (context, index) {
                  final item = pengaduanList[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.report),
                      title: Text("Status: ${item['status']}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Kategori: ${item['kategori_pengaduan'] ?? '-'}",
                          ),
                          Text("Tanggal: ${item['tanggal_pengaduan']}"),
                          Text("Deskripsi: ${item['deskripsi']}"),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
