import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/request_model.dart';

class RequestFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create request
  Future<String> createRequest(RequestModel request) async {
    final docRef = _firestore.collection('requests').doc();
    final data = request.toMap();
    data['id'] = docRef.id;
    await docRef.set(data);
    return docRef.id;
  }

  // Get user requests
  Stream<List<RequestModel>> getUserRequests(String userId) {
    return _firestore
        .collection('requests')
        .where('clientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get request
  Future<RequestModel?> getRequest(String requestId) async {
    final doc = await _firestore.collection('requests').doc(requestId).get();
    if (doc.exists) {
      return RequestModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Delete request
  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).delete();
  }

  // Get global requests
  Stream<List<RequestModel>> getGlobalRequests() {
    return _firestore
        .collection('requests')
        .where('isFulfilled', isEqualTo: false)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: true)
        .limit(100) // Performance fix: Prevent pulling all documents
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
