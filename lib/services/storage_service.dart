import 'package:universal_io/io.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'image_compress_service.dart';

/// خدمة رفع الصور إلى Firebase Storage
/// بديل موثوق تماماً عن Cloudinary
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  // ─── رفع أي صورة إلى مجلد محدد ───────────────────────────────────────────
  Future<String?> uploadImage(File imageFile, {required String folder}) async {
    try {
      // استخراج الامتداد من المسار
      final filePath = imageFile.path;
      final dotIndex = filePath.lastIndexOf('.');
      final ext =
          dotIndex != -1 ? filePath.substring(dotIndex).toLowerCase() : '.jpg';

      final fileName = '${_uuid.v4()}$ext';
      final ref = _storage.ref().child('$folder/$fileName');

      debugPrint('StorageService: uploading → $folder/$fileName');

      // ضغط الصورة محلياً إذا كانت كبيرة لتوفير البيانات وتسريع الرفع
      File fileToUpload = imageFile;
      if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
        if (await ImageCompressService.needsCompression(imageFile,
            maxSizeKB: 300)) {
          debugPrint('StorageService: compressing image before upload...');
          fileToUpload = await ImageCompressService.compressImage(imageFile);
        }
      }

      final task = await ref.putFile(
        fileToUpload,
        SettableMetadata(contentType: _contentType(ext)),
      );

      final url = await task.ref.getDownloadURL();
      debugPrint('StorageService: ✅ success → $url');
      return url;
    } catch (e) {
      debugPrint('StorageService: ❌ uploadImage error: $e');
      return null;
    }
  }

  // ─── حذف صورة باستخدام رابطها ─────────────────────────────────────────────
  Future<void> deleteFileByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
      debugPrint('StorageService: ✅ deleted $url');
    } catch (e) {
      debugPrint('StorageService: ⚠️ deleteFileByUrl: $e');
    }
  }

  // ─── دوال مختصرة لكل نوع ──────────────────────────────────────────────────
  Future<String> uploadProfileImage(String userId, File file) async {
    final url = await uploadImage(file, folder: 'users/profile/$userId');
    if (url == null) throw Exception('فشل رفع صورة الملف الشخصي');
    return url;
  }

  Future<String> uploadPortfolioImage(String userId, File file) async {
    final url = await uploadImage(file, folder: 'users/portfolio/$userId');
    if (url == null) throw Exception('فشل رفع صورة المعرض');
    return url;
  }

  Future<String> uploadPortfolioVideo(String userId, File file) async {
    final url =
        await uploadImage(file, folder: 'users/portfolio_videos/$userId');
    if (url == null) throw Exception('فشل رفع فيديو المعرض');
    return url;
  }

  Future<String> uploadPaymentReceipt(String paymentId, File file) async {
    final url = await uploadImage(file, folder: 'payments/$paymentId');
    if (url == null) throw Exception('فشل رفع إيصال الدفع');
    return url;
  }

  Future<String> uploadJobAttachment(String jobId, File file) async {
    final url = await uploadImage(file, folder: 'jobs/$jobId');
    if (url == null) throw Exception('فشل رفع مرفق الوظيفة');
    return url;
  }

  Future<String> uploadIdCard(String userId, File file) async {
    final url =
        await uploadImage(file, folder: 'users/verifications/$userId/id');
    if (url == null) throw Exception('فشل رفع صورة الهوية');
    return url;
  }

  Future<String> uploadVerificationSelfie(String userId, File file) async {
    final url =
        await uploadImage(file, folder: 'users/verifications/$userId/selfie');
    if (url == null) throw Exception('فشل رفع الصورة الشخصية');
    return url;
  }

  Future<String> uploadChatAttachment(
      String chatId, File file, String type) async {
    final url = await uploadImage(file, folder: 'chats/$chatId');
    if (url == null) throw Exception('فشل رفع مرفق المحادثة');
    return url;
  }

  Future<void> deleteFolder(String folderPath) async {
    // Firebase Storage لا يدعم حذف المجلدات من العميل
    // يمكن تنفيذها عبر Cloud Functions لاحقاً
  }

  String _contentType(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.m4a':
        return 'audio/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
