import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../models/review_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import 'user_service.dart';

class ReviewFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create review — anti-double-count design:
  // 1. Flutter writes: ratings doc (anti-duplicate guard) + reviews doc + notification
  // 2. Cloud Function onReviewCreated handles: rating/reviewsCount/ratingCounts update
  // This prevents double-counting since both Flutter AND the CF were updating stats.
  Future<String> createReview(ReviewModel review,
      {bool isJobCompleted = false}) async {
    final uniqueDocId =
        '${review.reviewerId}_${review.jobId ?? review.freelancerId}';
    final ratingRef = _firestore.collection('ratings').doc(uniqueDocId);
    final reviewRef = _firestore.collection('reviews').doc(uniqueDocId);
    final freelancerRef =
        _firestore.collection('users').doc(review.freelancerId);

    debugPrint(
        'ReviewService: Starting createReview for $uniqueDocId, rating=${review.rating}');

    // ✅ Phase 1: Fast pre-check for duplicate BEFORE the transaction
    final existingRating = await ratingRef.get();
    if (existingRating.exists) {
      debugPrint(
          'ReviewService: Rating already exists for $uniqueDocId — skipping (pre-check)');
      return uniqueDocId;
    }

    // ✅ Phase 2: Atomic transaction — writes only (no stat calculation here)
    await _firestore.runTransaction((tx) async {
      // Double-check inside transaction for simultaneous submissions
      final ratingSnap = await tx.get(ratingRef);
      if (ratingSnap.exists) {
        debugPrint(
            'ReviewService: Rating already exists for $uniqueDocId — skipping (in-tx check)');
        return;
      }

      // Write anti-duplicate guard document in `ratings/`
      tx.set(ratingRef, {
        'reviewerId': review.reviewerId,
        'freelancerId': review.freelancerId,
        'rating': review.rating,
        'comment': review.comment,
        'wouldWorkAgain': review.wouldWorkAgain,
        'isNegative': review.isNegative,
        'jobId': review.jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write the full review record — Cloud Function listens here and updates stats
      tx.set(reviewRef, review.toFirestore());

      // ✅ completedJobs still updated here since CF doesn't handle it
      if (isJobCompleted) {
        tx.update(freelancerRef, {
          'completedJobs': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Create notification for the freelancer
      final notifRef = _firestore.collection('notifications').doc();
      tx.set(notifRef, {
        'id': notifRef.id,
        'userId': review.freelancerId,
        'type': review.isNegative
            ? NotificationType.fraudWarning.name
            : NotificationType.rating.name,
        'title': review.isNegative ? 'تحذير احتيال' : 'تقييم جديد',
        'message': review.isNegative
            ? 'تم الإبلاغ عن حسابك كاحتيال/سلبي بواسطة ${review.reviewerName}'
            : 'قام ${review.reviewerName} بتقييمك بـ ${review.rating} نجوم',
        'createdAt': FieldValue.serverTimestamp(),
        'relatedId': reviewRef.id,
      });
    });

    debugPrint(
        'ReviewService: Completed createReview — CF will update stats for $uniqueDocId');

    // ✅ Phase 3: Guarantor Penalization Logic (المنطق الديناميكي لنظام الضامن)
    // إذا حصل الحرفي على تقييم سيء (أقل من 3)، يتم معاقبة من زكّاه تلقائياً!
    if (review.rating < 3.0) {
      try {
        final freelancerDoc =
            await _firestore.collection('users').doc(review.freelancerId).get();
        if (freelancerDoc.exists) {
          final userData = freelancerDoc.data()!;
          final vouchedByList = userData['vouchedBy'] as List<dynamic>? ?? [];
          if (vouchedByList.isNotEmpty) {
            // استيراد الخدمة محلياً لتجنب مشكلة الاعتماد الدائري
            final userService = UserFirestoreService();

            // قراءة الموديل كامل
            userData['id'] = freelancerDoc.id;
            // نستورد UserModel من فوق (مستورد بالفعل)
            final userModel = UserModel.fromMap(userData);

            // معاقبة الضامنين في الخلفية حتى لا يؤخر استجابة الواجهة
            userService.penalizeGuarantors(userModel, 1).then((_) {
              debugPrint(
                  'Guarantors penalized successfully for bad review on ${userModel.name}');
            }).catchError((e) {
              debugPrint('Failed to penalize guarantors: $e');
            });
          }
        }
      } catch (e) {
        debugPrint('Error in Guarantor penalization phase: $e');
      }
    }

    return uniqueDocId;
  }

  // Stream reviews
  Stream<List<ReviewModel>> getFreelancerReviews(String freelancerId) {
    return _firestore
        .collection('reviews')
        .where('freelancerId', isEqualTo: freelancerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromFirestore(doc))
            .toList());
  }
}
