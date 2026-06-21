import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج تأييد المهارة — يمثل شهادة من مستخدم آخر بمهارة معينة
class EndorsementModel {
  final String id;
  final String endorserId; // من أيّد هذه المهارة
  final String endorserName;
  final String? endorserImageUrl;
  final String skill; // المهارة المُؤيَّدة
  final String? comment; // تعليق اختياري
  final DateTime createdAt;
  final bool isVerifiedPurchase; // هل أتم صفقة مع هذا الحرفي؟

  EndorsementModel({
    required this.id,
    required this.endorserId,
    required this.endorserName,
    this.endorserImageUrl,
    required this.skill,
    this.comment,
    required this.createdAt,
    this.isVerifiedPurchase = false,
  });

  factory EndorsementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EndorsementModel(
      id: doc.id,
      endorserId: data['endorserId'] ?? '',
      endorserName: data['endorserName'] ?? '',
      endorserImageUrl: data['endorserImageUrl'],
      skill: data['skill'] ?? '',
      comment: data['comment'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isVerifiedPurchase: data['isVerifiedPurchase'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'endorserId': endorserId,
      'endorserName': endorserName,
      'endorserImageUrl': endorserImageUrl,
      'skill': skill,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVerifiedPurchase': isVerifiedPurchase,
    };
  }
}
