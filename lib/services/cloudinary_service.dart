import 'package:universal_io/io.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// خدمة رفع الصور إلى Cloudinary عبر HTTP مباشرة مع التوقيع الآمن (Signed Upload)
class CloudinaryService {
  static const String cloudName = 'dmuc5x843';
  static const int maxRetries = 3;

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// جلب التوقيع الآمن من Cloud Functions
  Future<Map<String, dynamic>?> _getSignature(String folder) async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('generateCloudinarySignature');
      final results = await callable.call({'folder': folder});
      return Map<String, dynamic>.from(results.data);
    } catch (e) {
      debugPrint('Cloudinary Signature Error: $e');
      return null;
    }
  }

  /// رفع صورة مع التوقيع الآمن وإعادة المحاولة (مع ضغط ذكي قبل الرفع)
  Future<String?> uploadImage(File imageFile, {String? folder}) async {
    final targetFolder = folder ?? 'general';

    // ✅ ضغط الصورة قبل الرفع
    File fileToUpload = imageFile;
    if (!kIsWeb) {
      try {
        final dir = await getTemporaryDirectory();
        final targetPath = p.join(
            dir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          targetPath,
          quality: 70,
          minWidth: 1080,
          format: CompressFormat.jpeg,
        );
        
        if (compressedFile != null) {
          fileToUpload = File(compressedFile.path);
          debugPrint('Cloudinary: تم الضغط بنجاح. الحجم قبل: ${await imageFile.length()} -> الحجم بعد: ${await fileToUpload.length()}');
        }
      } catch (e) {
        debugPrint('Cloudinary: خطأ أثناء ضغط الصورة، سيتم رفع الأصلية. الخطأ: $e');
      }
    }

    final signatureData = await _getSignature(targetFolder);

    if (signatureData == null) {
      debugPrint('Cloudinary: ❌ فشل في جلب التوقيع للرفع');
      return null;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Cloudinary: محاولة $attempt/$maxRetries...');

        final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

        // إرفاق بيانات التوقيع للرفع الآمن
        request.fields['api_key'] = signatureData['apiKey'];
        request.fields['timestamp'] = signatureData['timestamp'].toString();
        request.fields['signature'] = signatureData['signature'];
        request.fields['folder'] = signatureData['folder'];

        if (kIsWeb) {
          final xfile = XFile(fileToUpload.path);
          final bytes = await xfile.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: 'upload.jpg'),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', fileToUpload.path),
          );
        }

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 60));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final url = json['secure_url'] as String?;
          debugPrint('Cloudinary: ✅ تم الرفع → $url');
          return url;
        } else {
          debugPrint(
              'Cloudinary: ❌ status ${response.statusCode} → ${response.body}');
        }
      } catch (e) {
        debugPrint('Cloudinary: ❌ محاولة $attempt فشلت → $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
    debugPrint('Cloudinary: ❌ فشل بعد $maxRetries محاولات');
    return null;
  }

  /// رفع فيديو مع إعادة المحاولة
  Future<String?> uploadVideo(File videoFile, {String? folder}) async {
    const videoUrl = 'https://api.cloudinary.com/v1_1/$cloudName/video/upload';

    final targetFolder = folder ?? 'general';
    final signatureData = await _getSignature(targetFolder);

    if (signatureData == null) {
      debugPrint('Cloudinary Video: ❌ فشل في جلب التوقيع للرفع');
      return null;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Cloudinary Video: محاولة $attempt/$maxRetries...');

        final request = http.MultipartRequest('POST', Uri.parse(videoUrl));

        request.fields['api_key'] = signatureData['apiKey'];
        request.fields['timestamp'] = signatureData['timestamp'].toString();
        request.fields['signature'] = signatureData['signature'];
        request.fields['folder'] = signatureData['folder'];

        if (kIsWeb) {
          final xfile = XFile(videoFile.path);
          final bytes = await xfile.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: 'upload.mp4'),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', videoFile.path),
          );
        }

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 120));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final url = json['secure_url'] as String?;
          debugPrint('Cloudinary Video: ✅ → $url');
          return url;
        } else {
          debugPrint(
              'Cloudinary Video: ❌ ${response.statusCode} → ${response.body}');
        }
      } catch (e) {
        debugPrint('Cloudinary Video: ❌ محاولة $attempt → $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    return null;
  }

  /// تحسين رابط الصورة لتقليل حجم البيانات وتجنب أخطاء فك التشفير
  static String getOptimizedUrl(
    String url, {
    int? width,
    int? height,
    String quality = 'auto',
    List<String>? extraTransformations,
  }) {
    if (url.isEmpty || !url.contains('cloudinary.com')) return url;
    
    // عدم تطبيق تحسينات الصور على الفيديوهات
    if (url.contains('/video/')) return url;

    // 1. استبدال أي إعدادات قديمة تسبب تجمداً
    String optimized = url;
    if (kIsWeb) {
      optimized = optimized.replaceAll('f_auto', 'f_jpg')
                           .replaceAll('f_avif', 'f_jpg')
                           .replaceAll('f_webp', 'f_jpg');
    } else {
      optimized = optimized.replaceAll('f_auto', 'f_webp')
                           .replaceAll('f_avif', 'f_webp');
    }

    // إذا كان الرابط يحتوي مسبقاً على تحسينات
    if (optimized.contains('q_') || optimized.contains(kIsWeb ? 'f_jpg' : 'f_webp')) {
      return optimized;
    }

    // 2. إذا لم يكن يحتوي على تحسينات، نقوم بإدراجها بالطريقة الصحيحة
    try {
      final uri = Uri.parse(optimized);
      final pathSegments = List<String>.from(uri.pathSegments);
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1) return optimized;

      final transformations = <String>[];
      if (width != null) transformations.add('w_$width');
      if (height != null) transformations.add('h_$height');
      if (width != null || height != null) transformations.add('c_limit');
      transformations.add('q_$quality');
      
      // Use JPG instead of WebP to prevent EncodingError in Flutter Web (CanvasKit)
      if (kIsWeb) {
        transformations.add('f_jpg');
      } else {
        transformations.add('f_webp'); 
      }
      if (extraTransformations != null) {
        transformations.addAll(extraTransformations);
      }

      pathSegments.insert(uploadIndex + 1, transformations.join(','));
      return uri.replace(pathSegments: pathSegments).toString();
    } catch (_) {
      return optimized;
    }
  }
}
