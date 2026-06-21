import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/story_model.dart';

class StoryFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add story
  Future<String> addStory(StoryModel story) async {
    final docRef =
        await _firestore.collection('stories').add(story.toFirestore());
    return docRef.id;
  }

  // Get active stories
  Stream<List<StoryModel>> getActiveStories() {
    final twentyFourHoursAgo =
        DateTime.now().subtract(const Duration(hours: 24));
    return _firestore
        .collection('stories')
        .where('createdAt',
            isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => StoryModel.fromFirestore(d)).toList());
  }

  // Add viewer
  Future<void> addViewer(String storyId, String userId) async {
    await _firestore.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([userId])
    });
  }

  // Delete story
  Future<void> deleteStory(String storyId) async {
    await _firestore.collection('stories').doc(storyId).delete();
  }
}
