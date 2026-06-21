import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reportedUserId;
  final String reportedUserName;
  final String? reportedUserPhone;
  final String reason;
  final String? imageUrl;
  final DateTime createdAt;
  final String status; // 'pending', 'resolved'

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reportedUserId,
    required this.reportedUserName,
    this.reportedUserPhone,
    required this.reason,
    this.imageUrl,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      if (reportedUserPhone != null) 'reportedUserPhone': reportedUserPhone,
      'reason': reason,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      reportedUserName: data['reportedUserName'] ?? '',
      reportedUserPhone: data['reportedUserPhone'],
      reason: data['reason'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }
}
