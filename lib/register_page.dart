import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  TextEditingController usernameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nomorHpController = TextEditingController();

  String? selectedCabang;

  // Daftar nama cabang (sementara hardcoded, bisa diganti ambil dari API)
  List<Map<String, dynamic>> cabangList = [
    {'id': 1, 'nama': 'Indramayu'},
    {'id': 2, 'nama': 'Losarang'},
    {'id': 3, 'nama': 'Sindang'},
    {'id': 4, 'nama': 'Jatibarang'},
    {'id': 5, 'nama': 'Kertasmaya'},
    {'id': 6, 'nama': 'Kandanghaur'},
    {'id': 7, 'nama': 'Lohbener'},
    {'id': 8, 'nama': 'Karangampel'},
  ];

  Future<void> register() async {
    var response = await http.post(
      Uri.parse(registerUrl),
      body: {
        'username': usernameController.text,
        'email': emailController.text,
        'password': passwordController.text,
        'nomor_hp': nomorHpController.text,
        'id_cabang': selectedCabang ?? '', // Tambahkan id_cabang
      },
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registrasi berhasil, silakan login')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registrasi gagal, coba lagi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: nomorHpController,
              decoration: InputDecoration(labelText: 'Nomor HP'),
            ),
            SizedBox(height: 10),

            // Dropdown untuk memilih cabang
            DropdownButtonFormField<String>(
              value: selectedCabang,
              decoration: InputDecoration(labelText: 'Pilih Cabang'),
              items:
                  cabangList.map((cabang) {
                    return DropdownMenuItem<String>(
                      value: cabang['id'].toString(),
                      child: Text(cabang['nama']),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCabang = value;
                });
              },
            ),

            SizedBox(height: 20),
            ElevatedButton(onPressed: register, child: Text('Register')),
          ],
        ),
      ),
    );
  }
}
