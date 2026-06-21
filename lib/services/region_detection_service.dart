import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Result of region detection
enum RegionResult {
  /// User is confirmed inside Sudan
  insideSudan,

  /// User is confirmed outside Sudan
  outsideSudan,

  /// Detection failed entirely (all APIs failed, no GPS)
  unknown,
}

/// Source of the detection result
enum DetectionSource {
  ipApi,
  gps,
  fallback,
}

/// Holds the detection result with metadata
class RegionDetectionResult {
  final RegionResult result;
  final DetectionSource source;
  final String? countryName;
  final String? countryCode;
  final String? errorMessage;

  const RegionDetectionResult({
    required this.result,
    required this.source,
    this.countryName,
    this.countryCode,
    this.errorMessage,
  });

  bool get isInSudan => result == RegionResult.insideSudan;
  bool get isOutsideSudan =>
      result == RegionResult.outsideSudan || result == RegionResult.unknown;
}

/// Multi-layered region detection service.
/// Uses cascading IP APIs with GPS fallback.
/// Defaults to "outside Sudan" on total failure (fail-closed for security).
class RegionDetectionService {
  static const Duration _apiTimeout = Duration(seconds: 8);

  /// Run IP-based detection with cascading fallback across multiple APIs.
  /// Returns [RegionDetectionResult] with the detection outcome.
  static Future<RegionDetectionResult> detectByIP() async {
    // Try each API in order. First success wins.
    final detectors = <Future<RegionDetectionResult?> Function()>[
      _detectViaIpApi, // ip-api.com (fast, reliable)
      _detectViaIpWhoIs, // ipwho.is  (good fallback)
      _detectViaFreeIpApi, // freeipapi.com (original, kept as last resort)
    ];

    for (final detector in detectors) {
      try {
        final result = await detector();
        if (result != null) {
          debugPrint(
              'RegionDetection: Success via ${result.source.name} → ${result.result.name} (${result.countryCode})');
          return result;
        }
      } catch (e) {
        debugPrint('RegionDetection: Detector failed: $e');
        continue;
      }
    }

    // ALL APIs failed → fail-closed (assume outside for security)
    debugPrint(
        'RegionDetection: All IP APIs failed → defaulting to outsideSudan');
    return const RegionDetectionResult(
      result: RegionResult.unknown,
      source: DetectionSource.fallback,
      errorMessage: 'All detection APIs failed',
    );
  }

  /// Verify location using device GPS.
  /// Returns [RegionDetectionResult] or null if GPS is unavailable.
  static Future<RegionDetectionResult?> detectByGPS() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 15));

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final countryCode = place.isoCountryCode?.toUpperCase() ?? '';
        final country = place.country?.toLowerCase() ?? '';

        final isSudan = countryCode == 'SD' || country.contains('sudan');

        return RegionDetectionResult(
          result:
              isSudan ? RegionResult.insideSudan : RegionResult.outsideSudan,
          source: DetectionSource.gps,
          countryName: place.country,
          countryCode: countryCode,
        );
      }
      return null;
    } catch (e) {
      debugPrint('RegionDetection: GPS detection failed: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────
  // Private API detectors
  // ──────────────────────────────────────────────────

  /// ip-api.com — fast, reliable, 45 req/min free tier
  static Future<RegionDetectionResult?> _detectViaIpApi() async {
    try {
      final response = await http
          .get(Uri.parse(
              'http://ip-api.com/json/?fields=status,countryCode,country'))
          .timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final code = data['countryCode']?.toString().toUpperCase() ?? '';
          final name = data['country']?.toString() ?? '';
          return RegionDetectionResult(
            result: _isSudanCode(code, name)
                ? RegionResult.insideSudan
                : RegionResult.outsideSudan,
            source: DetectionSource.ipApi,
            countryName: name,
            countryCode: code,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('RegionDetection: ip-api.com failed: $e');
      return null;
    }
  }

  /// ipwho.is — no rate limit, reliable
  static Future<RegionDetectionResult?> _detectViaIpWhoIs() async {
    try {
      final response =
          await http.get(Uri.parse('https://ipwho.is/')).timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final code = data['country_code']?.toString().toUpperCase() ?? '';
          final name = data['country']?.toString() ?? '';
          return RegionDetectionResult(
            result: _isSudanCode(code, name)
                ? RegionResult.insideSudan
                : RegionResult.outsideSudan,
            source: DetectionSource.ipApi,
            countryName: name,
            countryCode: code,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('RegionDetection: ipwho.is failed: $e');
      return null;
    }
  }

  /// freeipapi.com — original API, kept as last resort
  static Future<RegionDetectionResult?> _detectViaFreeIpApi() async {
    try {
      final response = await http
          .get(Uri.parse('https://freeipapi.com/api/json/'))
          .timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final code = data['countryCode']?.toString().toUpperCase() ?? '';
        final name = data['countryName']?.toString() ?? '';
        if (code.isNotEmpty || name.isNotEmpty) {
          return RegionDetectionResult(
            result: _isSudanCode(code, name)
                ? RegionResult.insideSudan
                : RegionResult.outsideSudan,
            source: DetectionSource.ipApi,
            countryName: name,
            countryCode: code,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('RegionDetection: freeipapi.com failed: $e');
      return null;
    }
  }

  /// Check if the country code or name matches Sudan
  static bool _isSudanCode(String code, String name) {
    return code == 'SD' || name.toLowerCase() == 'sudan';
  }
}
