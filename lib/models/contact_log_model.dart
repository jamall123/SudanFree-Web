import 'package:cloud_firestore/cloud_firestore.dart';

/// سجل تواصل بين عميل وحرفي
/// يُستخدم لربط التقييمات بتواصل حقيقي عبر واتساب أو اتصال
class ContactLogModel {
  final String id;
  final String contacterId; // من تواصل (العميل)
  final String contacterName;
  final String freelancerId; // مع من (الحرفي/المتجر)
  final String freelancerName;
  final String contactType; // 'whatsapp' | 'call'
  final DateTime createdAt;
  final bool hasReviewed; // هل تم التقييم؟
  final DateTime? reviewedAt;

  ContactLogModel({
    required this.id,
    required this.contacterId,
    required this.contacterName,
    required this.freelancerId,
    required this.freelancerName,
    required this.contactType,
    required this.createdAt,
    this.hasReviewed = false,
    this.reviewedAt,
  });

  factory ContactLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContactLogModel(
      id: doc.id,
      contacterId: data['contacterId'] ?? '',
      contacterName: data['contacterName'] ?? '',
      freelancerId: data['freelancerId'] ?? '',
      freelancerName: data['freelancerName'] ?? '',
      contactType: data['contactType'] ?? 'whatsapp',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      hasReviewed: data['hasReviewed'] ?? false,
      reviewedAt: data['reviewedAt'] is Timestamp
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'contacterId': contacterId,
      'contacterName': contacterName,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'contactType': contactType,
      'createdAt': Timestamp.fromDate(createdAt),
      'hasReviewed': hasReviewed,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }
}
