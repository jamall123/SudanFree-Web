import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// خدمة ضغط الصور قبل الرفع
/// تقلل حجم الصورة لتسريع الرفع وتوفير البيانات
class ImageCompressService {
  /// ضغط صورة وإرجاع ملف جديد مضغوط
  /// [maxWidth] الحد الأقصى للعرض (الافتراضي 1080)
  /// [quality] جودة الصورة (0-100، الافتراضي 85)
  static Future<File> compressImage(
    File file, {
    int maxWidth = 800, // Reduced from 1080 to save more data
    int quality = 75, // Reduced from 85 for better compression
  }) async {
    try {
      // قراءة الصورة
      final bytes = await file.readAsBytes();

      // فك تشفير الصورة
      final image = await compute(_decodeImage, bytes);
      if (image == null) {
        debugPrint('ImageCompress: فشل في فك تشفير الصورة');
        return file; // إرجاع الأصلية في حالة الفشل
      }

      // تحديد الأبعاد الجديدة
      int newWidth = image.width;
      int newHeight = image.height;

      if (image.width > maxWidth) {
        newWidth = maxWidth;
        newHeight = (image.height * maxWidth / image.width).round();
      }

      // تصغير الصورة
      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Force JPG encoding for optimal size/compatibility
      final compressedBytes = img.encodeJpg(resized, quality: quality);

      // حفظ الملف المضغوط
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('${tempDir.path}/compressed_$timestamp.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      // طباعة معلومات الضغط
      final originalSize = await file.length();
      final compressedSize = await compressedFile.length();
      final reduction = ((originalSize - compressedSize) / originalSize * 100)
          .toStringAsFixed(1);
      debugPrint(
          'ImageCompress: $originalSize -> $compressedSize bytes ($reduction% reduction)');

      return compressedFile;
    } catch (e) {
      debugPrint('ImageCompress Error: $e');
      return file; // إرجاع الأصلية في حالة الخطأ
    }
  }

  /// فك تشفير الصورة في Isolate منفصل
  static img.Image? _decodeImage(Uint8List bytes) {
    return img.decodeImage(bytes);
  }

  /// التحقق مما إذا كانت الصورة تحتاج ضغط
  static Future<bool> needsCompression(File file, {int maxSizeKB = 500}) async {
    final size = await file.length();
    return size > maxSizeKB * 1024;
  }

  /// الحصول على حجم الملف بتنسيق قابل للقراءة
  static String getReadableFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
