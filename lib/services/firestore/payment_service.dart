import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/payment_model.dart';

class PaymentFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create payment
  Future<String> createPayment(PaymentModel payment) async {
    final docRef =
        await _firestore.collection('payments').add(payment.toFirestore());
    return docRef.id;
  }

  // Get payment
  Future<PaymentModel?> getPayment(String paymentId) async {
    final doc = await _firestore.collection('payments').doc(paymentId).get();
    if (doc.exists) {
      return PaymentModel.fromFirestore(doc);
    }
    return null;
  }

  // Stream job payments
  Stream<List<PaymentModel>> getJobPayments(String jobId) {
    return _firestore
        .collection('payments')
        .where('jobId', isEqualTo: jobId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  // Stream user payments
  Stream<List<PaymentModel>> getUserPayments(String userId,
      {bool isClient = true}) {
    final field = isClient ? 'clientId' : 'freelancerId';
    return _firestore
        .collection('payments')
        .where(field, isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  // Update payment status
  Future<void> updatePaymentStatus(
      String paymentId, PaymentStatus status) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
