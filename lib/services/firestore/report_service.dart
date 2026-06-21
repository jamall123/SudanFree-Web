import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/report_model.dart';

class ReportFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitReport(ReportModel report) async {
    await _firestore.collection('reports').add(report.toFirestore());
  }
}
