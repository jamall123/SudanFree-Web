import 'package:flutter/material.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  Map<String, List<String>> _locations = {};
  bool _isLoading = false;
  String? _error;

  Map<String, List<String>> get locations => _locations;
  List<String> get states => _locations.keys.toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<String> getLocalities(String? state) {
    if (state == null) return [];
    return _locations[state] ?? [];
  }

  Future<void> loadLocations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _locations = await _locationService.getLocations();
    } catch (e) {
      _error = e.toString();
      // Keep empty or fallback logic handled in service
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
