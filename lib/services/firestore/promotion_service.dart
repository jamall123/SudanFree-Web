import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';

/// Promotion model - represents a promoted user card on the home screen
class PromotedUser {
  final String id;
  final String userId;
  final String promoText;
  final DateTime createdAt;
  final DateTime expiryDate;
  final bool isActive;

  // User data (fetched separately)
  UserModel? user;

  PromotedUser({
    required this.id,
    required this.userId,
    required this.promoText,
    required this.createdAt,
    required this.expiryDate,
    required this.isActive,
    this.user,
  });

  factory PromotedUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromotedUser(
      id: doc.id,
      userId: data['userId'] ?? '',
      promoText: data['promoText'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate:
          (data['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }
}

/// Service to fetch promoted users from Firestore
class PromotionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all active promotions (not expired)
  Future<List<PromotedUser>> getActivePromotions() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final snap = await _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .where('expiryDate', isGreaterThan: now)
          .orderBy('expiryDate')
          .limit(10)
          .get();

      if (snap.docs.isEmpty) return [];

      final promotions =
          snap.docs.map((d) => PromotedUser.fromFirestore(d)).toList();

      // Fetch user data for each promotion
      for (final promo in promotions) {
        try {
          final userDoc =
              await _firestore.collection('users').doc(promo.userId).get();
          if (userDoc.exists) {
            promo.user = UserModel.fromFirestore(userDoc);
          }
        } catch (e) {
          debugPrint('Error fetching promoted user data: $e');
        }
      }

      // Remove promotions where user data couldn't be loaded
      promotions.removeWhere((p) => p.user == null);

      return promotions;
    } catch (e) {
      debugPrint('Error fetching promotions: $e');
      return [];
    }
  }
}
