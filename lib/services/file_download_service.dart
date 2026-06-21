import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// خدمة تحميل الملفات بأسلوب تيليغرام:
/// - تحميل مباشر داخل التطبيق
/// - شريط تقدم مرئي
/// - حفظ في مجلد التنزيلات
/// - فتح الملف مباشرة بعد التحميل
class FileDownloadService {
  /// تحميل ملف مع إظهار شريط التقدم
  static Future<void> downloadAndOpen({
    required BuildContext context,
    required String url,
    required String fileName,
  }) async {
    if (Platform.isAndroid) {
      // For Android 13+ or saving to app-specific dirs, we don't strictly need storage permissions,
      // but we will request basic storage permission just in case for older Android versions.
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      // We no longer require manageExternalStorage to avoid "All files access" prompt.
    }

    // 2. إظهار نافذة التقدم
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        url: url,
        fileName: fileName,
      ),
    );
  }

  /// حفظ الملف إلى مجلد التنزيلات
  static Future<String> _getSavePath(String fileName) async {
    if (Platform.isAndroid) {
      try {
        final dirs = await getExternalStorageDirectories(
            type: StorageDirectory.downloads);
        if (dirs != null && dirs.isNotEmpty) {
          return '${dirs.first.path}/$fileName';
        }
      } catch (e) {
        debugPrint('Failed to get external storage directory: $e');
      }
    }
    // fallback: مجلد مؤقت داخل التطبيق
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$fileName';
  }

  static Future<String> getSavePath(String fileName) => _getSavePath(fileName);

  static Future<bool> fileExists(String fileName) async {
    final path = await _getSavePath(fileName);
    return File(path).exists();
  }

  static Future<void> openFile(String fileName) async {
    final path = await _getSavePath(fileName);
    if (await File(path).exists()) {
      await OpenFile.open(path);
    }
  }
}

/// نافذة التقدم (مثل تيليغرام تماماً)
class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  final String fileName;

  const _DownloadProgressDialog({
    required this.url,
    required this.fileName,
  });

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _status = 'جاري التحميل...';
  bool _isDone = false;

  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final savePath = await FileDownloadService.getSavePath(widget.fileName);

      // إنشاء طلب HTTP مع متابعة التقدم
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('فشل الاتصال بالسيرفر (${response.statusCode})');
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() {
            _progress = receivedBytes / totalBytes;
            _status =
                '${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}';
          });
        }
      }

      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _status = 'اكتمل التحميل ✓';
          _isDone = true;
        });
      }

      // فتح الملف تلقائياً
      if (mounted) {
        Navigator.of(context).pop();
        await OpenFile.open(savePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _status = 'حدث خطأ: ${e.toString()}';
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم الملف
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _hasError
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasError
                      ? Icons.error_outline
                      : _isDone
                          ? Icons.check_circle
                          : Icons.downloading,
                  color: _hasError
                      ? Colors.red
                      : _isDone
                          ? Colors.green
                          : Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // شريط التقدم
          if (!_hasError) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isDone ? Colors.green : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // نص الحالة
          Text(
            _status,
            style: TextStyle(
              fontSize: 12,
              color: _hasError
                  ? Colors.red
                  : _isDone
                      ? Colors.green
                      : Colors.grey[600],
            ),
          ),

          // زر إلغاء
          if (!_isDone) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child:
                    const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
