import 'package:pdam_app/models/tugas_model.dart';

class PaginatedTugasResponse {
  final List<Tugas> tugasList;
  final bool hasMorePages;

  PaginatedTugasResponse({required this.tugasList, required this.hasMorePages});
}
