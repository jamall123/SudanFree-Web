import 'package:flutter/material.dart';
import '../models/story_model.dart';
import '../services/firestore_service.dart';

class StoryProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<StoryModel> _stories = [];
  bool _isLoading = false;

  List<StoryModel> get stories => _stories;
  bool get isLoading => _isLoading;

  void fetchStories() {
    _isLoading = true;
    _firestoreService.getActiveStories().listen((fetchedStories) {
      _stories = fetchedStories;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint('StoryProvider: Error fetching stories: $error');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addStory(StoryModel story) async {
    await _firestoreService.addStory(story);
  }

  Future<void> viewStory(String storyId, String userId) async {
    await _firestoreService.addStoryViewer(storyId, userId);
  }
}
