import 'package:flutter/foundation.dart';

/// Global in-memory cache layer for expensive Firestore operations
/// Reduces redundant reads across the app by maintaining singleton instances
/// with configurable TTL (time-to-live) for each data type
class GlobalDataCache with ChangeNotifier {
  static final GlobalDataCache _instance = GlobalDataCache._internal();

  factory GlobalDataCache() {
    return _instance;
  }

  GlobalDataCache._internal();

  /// In-memory cache entries with timestamps
  final Map<String, _CacheEntry> _cache = {};

  /// Get or fetch cache entry
  dynamic getCacheEntry(String key) {
    if (!_cache.containsKey(key)) return null;
    final entry = _cache[key]!;

    // Check if expired
    if (DateTime.now().difference(entry.timestamp).inSeconds >
        entry.ttlSeconds) {
      _cache.remove(key);
      return null;
    }

    return entry.data;
  }

  /// Set cache entry with TTL
  void setCacheEntry(String key, dynamic data, {required Duration ttl}) {
    _cache[key] = _CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttlSeconds: ttl.inSeconds,
    );
    notifyListeners();
  }

  /// Clear specific cache key
  void clearCacheKey(String key) {
    _cache.remove(key);
    notifyListeners();
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
    notifyListeners();
  }

  /// Check if cache entry exists and is valid
  bool isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;
    final entry = _cache[key]!;
    return DateTime.now().difference(entry.timestamp).inSeconds <
        entry.ttlSeconds;
  }

  /// Get cache statistics for monitoring
  Map<String, dynamic> getCacheStats() {
    int validEntries = 0;
    int expiredEntries = 0;

    for (final entry in _cache.values) {
      if (DateTime.now().difference(entry.timestamp).inSeconds <
          entry.ttlSeconds) {
        validEntries++;
      } else {
        expiredEntries++;
      }
    }

    return {
      'total': _cache.length,
      'valid': validEntries,
      'expired': expiredEntries,
      'keys': _cache.keys.toList(),
    };
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final int ttlSeconds;

  _CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttlSeconds,
  });
}
