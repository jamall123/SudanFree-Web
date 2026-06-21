import 'package:cloud_firestore/cloud_firestore.dart';

enum VerificationRequestStatus { pending, approved, rejected }

class VerificationRequest {
  final String id;
  final String userId;
  final VerificationRequestStatus status;
  final Map<String, dynamic> submittedData;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  VerificationRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.submittedData,
    required this.createdAt,
    this.reviewedAt,
  });

  factory VerificationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VerificationRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      status: VerificationRequestStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => VerificationRequestStatus.pending,
      ),
      submittedData: Map<String, dynamic>.from(data['submittedData'] ?? {}),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reviewedAt: data['reviewedAt'] is Timestamp
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status.name,
      'submittedData': submittedData,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
    };
  }
}
