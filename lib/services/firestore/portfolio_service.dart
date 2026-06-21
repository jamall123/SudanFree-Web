import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/portfolio_project_model.dart';

class PortfolioFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add project
  Future<String> addProject(PortfolioProjectModel project) async {
    final docRef = await _firestore
        .collection('users')
        .doc(project.userId)
        .collection('portfolio')
        .add(project.toFirestore());
    return docRef.id;
  }

  // Get user projects
  Stream<List<PortfolioProjectModel>> getUserProjects(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('portfolio')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => PortfolioProjectModel.fromFirestore(d)).toList());
  }

  // Delete project
  Future<void> deleteProject(String userId, String projectId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('portfolio')
        .doc(projectId)
        .delete();
  }

  // Update project
  Future<void> updateProject(
      String userId, String projectId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('portfolio')
        .doc(projectId)
        .update(data);
  }
}
