/// ─────────────────────────────────────────────────────────────────────────────
/// SafeParse — Centralized Defensive Data Parsing Utilities
/// ─────────────────────────────────────────────────────────────────────────────
/// All models must use these helpers instead of direct casts.
/// Every method has a fallback default and never throws.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SafeParse {
  SafeParse._();

  // ── Primitives ─────────────────────────────────────────────────────────────

  static String string(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static String? nullableString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static int integer(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double decimal(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static double? nullableDecimal(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static bool boolean(dynamic v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return fallback;
  }

  // ── Collections ────────────────────────────────────────────────────────────

  /// Converts any list-like value to List<String> safely.
  /// Filters out nulls and converts non-strings via .toString()
  static List<String> stringList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Converts any map to Map<String, String> safely.
  static Map<String, String> stringMap(dynamic v) {
    if (v == null) return {};
    if (v is Map) {
      try {
        return Map.fromEntries(
          v.entries
              .where((e) => e.key != null && e.value != null)
              .map((e) => MapEntry(e.key.toString(), e.value.toString())),
        );
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  /// Converts any map to Map<String, int> safely (e.g. ratingCounts).
  static Map<String, int> intMap(dynamic v) {
    if (v == null) return {};
    if (v is Map) {
      try {
        return Map.fromEntries(
          v.entries
              .where((e) => e.key != null && e.value != null)
              .map((e) => MapEntry(e.key.toString(), integer(e.value))),
        );
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  /// Converts any map to Map<String, bool> safely (e.g. notificationSettings).
  static Map<String, bool> boolMap(dynamic v, {Map<String, bool>? fallback}) {
    if (v == null) return fallback ?? {};
    if (v is Map) {
      try {
        return Map.fromEntries(
          v.entries
              .where((e) => e.key != null)
              .map((e) => MapEntry(e.key.toString(), boolean(e.value))),
        );
      } catch (_) {
        return fallback ?? {};
      }
    }
    return fallback ?? {};
  }

  /// Converts a list of maps (e.g. vouchedBy) safely.
  static List<Map<String, dynamic>> mapList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) {
            try {
              return Map<String, dynamic>.from(e);
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }
    return [];
  }

  // ── Timestamps ─────────────────────────────────────────────────────────────

  /// Parses a Firestore Timestamp, ISO string, or millisecondsSinceEpoch int.
  static DateTime dateTime(dynamic v, [DateTime? fallback]) {
    fallback ??= DateTime.now();
    if (v == null) return fallback;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return fallback;
      }
    }
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return fallback;
  }

  static DateTime? nullableDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  // ── Enum ───────────────────────────────────────────────────────────────────

  /// Parses an enum value from a string, returns [fallback] if not found.
  static T enumValue<T extends Enum>(
    List<T> values,
    dynamic raw,
    T fallback,
  ) {
    if (raw == null) return fallback;
    final name = raw.toString().trim();
    try {
      return values.firstWhere((e) => e.name == name);
    } catch (_) {
      return fallback;
    }
  }

  // ── Cache Sanitization ─────────────────────────────────────────────────────

  /// Converts a Map for safe Hive storage:
  /// replaces all Timestamp values with ISO strings.
  static Map<String, dynamic> sanitizeForCache(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      result[entry.key] = _sanitizeValue(entry.value);
    }
    return result;
  }

  static dynamic _sanitizeValue(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) {
      return Map.fromEntries(
        v.entries
            .map((e) => MapEntry(e.key.toString(), _sanitizeValue(e.value))),
      );
    }
    if (v is List) return v.map(_sanitizeValue).toList();
    return v;
  }

  // ── Logging ────────────────────────────────────────────────────────────────

  static void logParseError(
      String model, String field, dynamic value, Object error) {
    if (kDebugMode) {
      debugPrint(
          '⚠️ [SafeParse] $model.$field: value=$value (${value.runtimeType}) → $error');
    }
  }
}
