import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/sudan_locations.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for locations
  Map<String, List<String>>? _cachedLocations;

  Future<Map<String, List<String>>> getLocations() async {
    if (_cachedLocations != null) return _cachedLocations!;

    try {
      // Try to fetch from Firestore
      // Structure: Collection 'locations' -> Doc 'sudan' -> Field 'states' (Map<String, List<dynamic>>)
      final doc =
          await _firestore.collection('settings').doc('locations').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('states')) {
          final Map<String, dynamic> statesMap = data['states'];

          // Convert to typed map
          final Map<String, List<String>> locations = {};
          statesMap.forEach((key, value) {
            locations[key] = List<String>.from(value);
          });

          _cachedLocations = locations;
          return locations;
        }
      }
    } catch (e) {
      // Fail silently and use fallback
      debugPrint('Error fetching locations: $e');
    }

    // Fallback to static constants
    return SudanLocations.statesWithLocalities;
  }
}
