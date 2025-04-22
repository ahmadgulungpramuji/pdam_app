import 'package:flutter/material.dart';

class PetugasPage extends StatelessWidget {
  const PetugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Halaman Petugas')),
      body: Center(child: Text('Selamat datang, petugas!')),
    );
  }
}
