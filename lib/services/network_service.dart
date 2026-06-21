import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service that monitors network connectivity and provides an easy API
/// for other services/providers to check connectivity before making requests.
///
/// This addresses the report's recommendation for better offline handling.
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));

  /// Initialize and start monitoring
  Future<void> initialize() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = !results.contains(ConnectivityResult.none);

      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        final connected = !results.contains(ConnectivityResult.none);
        if (_isConnected != connected) {
          _isConnected = connected;
          debugPrint(
              '🌐 [Network] ${connected ? "Connected" : "Disconnected"}');
        }
      });
    } catch (e) {
      debugPrint('NetworkService init error: $e');
      _isConnected = true; // Assume connected on error
    }
  }

  /// Check current connectivity — use before critical network operations
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = !results.contains(ConnectivityResult.none);
      return _isConnected;
    } catch (e) {
      return true; // Assume connected on error
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
