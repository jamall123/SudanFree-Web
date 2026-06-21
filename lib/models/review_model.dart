import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerImageUrl;
  final String freelancerId;
  final String? jobId;
  final String? jobTitle;
  final double rating; // 1-5 stars
  final bool isNegative; // Fraud/Scam report
  final String? comment;
  final DateTime createdAt;

  // === نظام الضمان الاجتماعي (Trust System) ===
  // سؤال مهم للسوق السوداني: "هل ستتعامل معه مرة أخرى؟"
  final bool? wouldWorkAgain;

  ReviewModel({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerImageUrl,
    required this.freelancerId,
    this.jobId,
    this.jobTitle,
    required this.rating,
    this.isNegative = false,
    this.comment,
    required this.createdAt,
    this.wouldWorkAgain,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      reviewerId: data['reviewerId'] ?? '',
      reviewerName: data['reviewerName'] ?? '',
      reviewerImageUrl: data['reviewerImageUrl'],
      freelancerId: data['freelancerId'] ?? data['targetId'] ?? '',
      jobId: data['jobId'],
      jobTitle: data['jobTitle'],
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      isNegative: data['isNegative'] ?? false,
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      wouldWorkAgain: data['wouldWorkAgain'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerImageUrl': reviewerImageUrl,
      'freelancerId': freelancerId,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'rating': rating,
      'isNegative': isNegative,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'wouldWorkAgain': wouldWorkAgain,
    };
  }
}
