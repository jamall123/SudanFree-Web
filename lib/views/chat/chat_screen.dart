import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:timeago/timeago.dart' as timeago;
import '../../services/firestore_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../profile/profile_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/job_provider.dart';
import '../../views/jobs/active_job_tracking_screen.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/linkable_text.dart';
import 'package:any_link_preview/any_link_preview.dart';
import '../../widgets/common/internal_link_preview.dart';
import '../../widgets/common/full_screen_image_viewer.dart';
import '../../services/file_download_service.dart';
import '../../services/smart_guide_service.dart';
import '../../widgets/common/glass_container.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chat;
  final bool autoOpenContractDialog;

  const ChatScreen(
      {super.key, required this.chat, this.autoOpenContractDialog = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  DateTime? _recordStartTime;
  Timer? _typingTimer;
  bool _isMeTyping = false;

  MessageModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<ChatProvider>().openChat(widget.chat, userId);
      }
      SmartGuideService.showMicroTip(
        context,
        messageAr:
            'لضمان حقوقك، وثّق عملك بإنشاء "اتفاق رسمي" عبر أيقونة المصافحة بالأعلى 🤝',
        messageEn:
            'Protect your rights by creating an "Official Agreement" via the handshake icon 🤝',
        tipId: 'chat_contract_tip',
        icon: Icons.handshake_rounded,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTypingChanged(String value) {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    if (value.isEmpty) {
      if (_isMeTyping) {
        _isMeTyping = false;
        context.read<ChatProvider>().setTypingStatus(userId, false);
      }
      _typingTimer?.cancel();
      return;
    }

    if (!_isMeTyping) {
      _isMeTyping = true;
      context.read<ChatProvider>().setTypingStatus(userId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isMeTyping) {
        _isMeTyping = false;
        context.read<ChatProvider>().setTypingStatus(userId, false);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final otherId = widget.chat.getOtherParticipantId(user.id);

    _messageController.clear();
    _onTypingChanged('');

    String finalContent = text;
    if (_replyingTo != null) {
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      String quote = _replyingTo!.content.replaceAll('\n', ' ');
      if (quote.length > 50) quote = '${quote.substring(0, 50)}...';
      final replyPrefix = isRtl ? '╭ الرد على ' : '╭ Replying to ';
      finalContent =
          '$replyPrefix${_replyingTo!.senderName}\n│ $quote\n╰───────────────\n$text';
      setState(() => _replyingTo = null);
    }

    await context.read<ChatProvider>().sendMessage(
          senderId: user.id,
          senderName: user.name,
          receiverId: otherId,
          content: finalContent,
        );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null && mounted) {
      final auth = context.read<AuthProvider>();
      final chatProv = context.read<ChatProvider>();
      final user = auth.user;
      if (user == null) return;

      final otherId = widget.chat.getOtherParticipantId(user.id);

      // fire & forget — لا ننتظر، الرسالة تظهر فوراً
      chatProv.sendImageMessage(
        senderId: user.id,
        senderName: user.name,
        receiverId: otherId,
        imageFile: File(image.path),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'rtf',
          'xls',
          'xlsx',
          'csv',
          'ppt',
          'pptx',
          'odt',
          'ods',
          'odp',
        ],
      );

      if (result != null && result.files.single.path != null && mounted) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;

        // Max 10 MB
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('حجم الملف كبير جداً، الحد الأقصى 10 ميجابايت'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final auth = context.read<AuthProvider>();
        final chatProv = context.read<ChatProvider>();
        final user = auth.user;
        if (user == null) return;

        final otherId = widget.chat.getOtherParticipantId(user.id);

        // fire & forget — لا ننتظر، الرسالة تظهر فوراً
        chatProv.sendFileMessage(
          senderId: user.id,
          senderName: user.name,
          receiverId: otherId,
          file: file,
          fileName: fileName,
        );
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اختيار الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            noiseSuppress: true,
            echoCancel: true,
            autoGain: true,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordStartTime = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null && _recordStartTime != null && mounted) {
        final duration = DateTime.now().difference(_recordStartTime!).inSeconds;
        if (duration < 1) return; // Ignore very short recordings

        final auth = context.read<AuthProvider>();
        final chatProv = context.read<ChatProvider>();
        final user = auth.user;
        if (user == null) return;

        final otherId = widget.chat.getOtherParticipantId(user.id);

        // fire & forget — لا ننتظر، الرسالة تظهر فوراً
        chatProv.sendAudioMessage(
          senderId: user.id,
          senderName: user.name,
          receiverId: otherId,
          audioFile: File(path),
          duration: duration,
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final user = authProvider.user;
    final messages = chatProvider.messages;
    final liveChat = chatProvider.chats
        .firstWhere((c) => c.id == widget.chat.id, orElse: () => widget.chat);
    final otherName = liveChat.getOtherParticipantName(user?.id ?? '');
    final otherImage = liveChat.getOtherParticipantImage(user?.id ?? '');
    final otherId = liveChat.getOtherParticipantId(user?.id ?? '');
    final isOtherTyping = liveChat.isTyping(otherId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: otherId)),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: otherImage != null
                    ? CachedNetworkImageProvider(otherImage)
                    : null,
                child: otherImage == null
                    ? Text(
                        otherName.isNotEmpty ? otherName[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(otherName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    if (isOtherTyping)
                      const Text('يكتب الآن...',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.primary))
                    else
                      _buildOnlineStatus(otherId),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showContractBottomSheet(context),
            icon: const Icon(Icons.handshake, size: 22),
            tooltip: 'إنشاء اتفاق',
          ),
        ],
      ),
      body: Column(
        children: [
          // Warning Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يفضل استخدام واتساب أو الاتصال المباشر للتواصل، الدردشة هنا فقط لإنشاء وتنسيق الاتفاقات لضمان حقوقك.',
                    style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty && chatProvider.isLoading
                ? const LoadingIndicator()
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == user?.id;
                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                        chat: widget.chat,
                        onReply: (msg) => setState(() => _replyingTo = msg),
                      );
                    },
                  ),
          ),
          if (isOtherTyping) _buildTypingIndicatorBubble(otherImage),
          if (chatProvider.isSending)
            const LinearProgressIndicator(minHeight: 2),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicatorBubble(String? imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage:
                imageUrl != null ? CachedNetworkImageProvider(imageUrl) : null,
            child: imageUrl == null ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  BorderRadius.circular(16).copyWith(bottomRight: Radius.zero),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _TypingDot(delay: 0),
                SizedBox(width: 4),
                _TypingDot(delay: 150),
                SizedBox(width: 4),
                _TypingDot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                      width: 3,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_replyingTo!.senderName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primary)),
                        Text(_replyingTo!.content.replaceAll('\n', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),
          ),
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          blur: 20,
          opacity: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.8,
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.zero,
          child: SafeArea(
            child: Row(
              children: [
                if (!_isRecording) ...[
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.primary),
                    onPressed: _showAttachmentOptions,
                  ),
                ],
                Expanded(
                  child: _isRecording
                      ? _buildRecordingIndicator()
                      : Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white10
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            onChanged: _onTypingChanged,
                            decoration: const InputDecoration(
                              hintText: 'اكتب رسالة...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            maxLines: null,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (context, value, child) {
                    final hasText = value.text.trim().isNotEmpty;
                    return GestureDetector(
                      onLongPressStart: (_) {
                        if (!hasText && !_isRecording) {
                          _startRecording();
                        }
                      },
                      onLongPressEnd: (_) {
                        if (_isRecording) {
                          _stopRecording();
                        }
                      },
                      child: FloatingActionButton(
                        onPressed: () {
                          if (_isRecording) {
                            _stopRecording();
                          } else if (hasText) {
                            _sendMessage();
                          } else {
                            _startRecording();
                          }
                        },
                        mini: true,
                        elevation: 2,
                        backgroundColor:
                            _isRecording ? Colors.red : AppColors.primary,
                        child: Icon(
                          _isRecording
                              ? Icons.send
                              : (hasText ? Icons.send : Icons.mic),
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator() {
    return Row(
      children: [
        // Cancel recording button
        GestureDetector(
          onTap: () async {
            await _audioRecorder.stop();
            setState(() => _isRecording = false);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
        const SizedBox(width: 6),
        const Text('جاري التسجيل...',
            style: TextStyle(
                color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        StreamBuilder<Duration>(
          stream: Stream.periodic(const Duration(seconds: 1),
              (tick) => Duration(seconds: tick + 1)),
          builder: (context, snapshot) {
            final seconds = snapshot.data?.inSeconds ?? 0;
            return Text(
              '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        color: Theme.of(context).cardColor,
        blur: 15,
        opacity: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.6,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('صورة'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.insert_drive_file, color: Colors.orange),
                title: const Text('ملف'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineStatus(String otherId) {
    return StreamBuilder<UserModel?>(
      stream: FirestoreService().getUserStream(otherId),
      builder: (context, snapshot) {
        final otherUser = snapshot.data;
        if (otherUser == null || otherUser.lastActive == null) {
          return const Text('غير متصل',
              style: TextStyle(fontSize: 12, color: Colors.grey));
        }
        final lastActiveDate = otherUser.lastActive!;
        final diff = DateTime.now().difference(lastActiveDate).inMinutes;
        if (diff < 5) {
          return const Text('نشط الآن',
              style: TextStyle(fontSize: 12, color: Colors.green));
        } else {
          return Text(
              'آخر ظهور ${timeago.format(lastActiveDate, locale: "ar")}',
              style: const TextStyle(fontSize: 11, color: Colors.grey));
        }
      },
    );
  }

  void _showContractBottomSheet(BuildContext context) {
    final detailsController = TextEditingController();
    final priceController = TextEditingController();
    final deadlineController = TextEditingController();
    final notesController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          color: Theme.of(context).cardColor,
          blur: 15,
          opacity: isDark ? 0.3 : 0.6,
          child: Column(children: [
            // Handle
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2))),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.handshake,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('إنشاء اتفاق',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('حدد تفاصيل العمل لحماية حقوق الطرفين',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ])),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close)),
              ]),
            ),
            const Divider(),
            // Form
            Expanded(
              child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Service Description
                    _buildContractField(
                      label: 'وصف الخدمة المطلوبة *',
                      icon: Icons.description,
                      child: TextField(
                        controller: detailsController,
                        maxLines: 4,
                        decoration: _contractInputDecor(
                            'اكتب وصف تفصيلي للخدمة أو العمل المطلوب إنجازه...',
                            isDark),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Price
                    _buildContractField(
                      label: 'المبلغ المتفق عليه *',
                      icon: Icons.payments,
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            _contractInputDecor('0.00', isDark).copyWith(
                          suffixText: 'SDG',
                          suffixStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Deadline
                    _buildContractField(
                      label: 'مدة التنفيذ المتوقعة',
                      icon: Icons.schedule,
                      child: TextField(
                        controller: deadlineController,
                        decoration: _contractInputDecor(
                            'مثال: 3 أيام، أسبوع، شهر...', isDark),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Notes
                    _buildContractField(
                      label: 'شروط وملاحظات إضافية',
                      icon: Icons.note_add,
                      child: TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: _contractInputDecor(
                            'أي شروط أو ملاحظات خاصة بالاتفاق...', isDark),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                                child: Text(
                              'سيتم إرسال الاتفاق للطرف الآخر للموافقة عليه. بعد الموافقة سيتم تتبع سير العمل تلقائياً.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  height: 1.5),
                            )),
                          ]),
                    ),
                    const SizedBox(height: 20),
                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final details = detailsController.text.trim();
                          final priceText = priceController.text.trim();
                          if (details.isEmpty || priceText.isEmpty) {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                  content: Text('يرجى ملء وصف الخدمة والمبلغ'),
                                  backgroundColor: Colors.orange),
                            );
                            return;
                          }
                          final price = double.tryParse(priceText);
                          if (price == null || price <= 0) {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                  content: Text('يرجى إدخال مبلغ صحيح'),
                                  backgroundColor: Colors.orange),
                            );
                            return;
                          }
                          final auth = context.read<AuthProvider>();
                          final chatProv = context.read<ChatProvider>();
                          final user = auth.user;
                          if (user == null) return;
                          final otherId =
                              widget.chat.getOtherParticipantId(user.id);
                          Navigator.pop(ctx);
                          final deadline = deadlineController.text.trim();
                          final notes = notesController.text.trim();
                          final fullDetails =
                              '$details${deadline.isNotEmpty ? '\n⏰ المدة: $deadline' : ''}${notes.isNotEmpty ? '\n📝 ملاحظات: $notes' : ''}';
                          await chatProv.sendContractMessage(
                            senderId: user.id,
                            senderName: user.name,
                            receiverId: otherId,
                            contractDetails: fullDetails,
                            contractPrice: price,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text('إرسال الاتفاق',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildContractField(
      {required String label, required IconData icon, required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      child,
    ]);
  }

  InputDecoration _contractInputDecor(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.grey.withValues(alpha: 0.06),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final ChatModel chat;
  final void Function(MessageModel)? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.chat,
    this.onReply,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isHidden = false;

  MessageModel get message => widget.message;
  bool get isMe => widget.isMe;
  ChatModel get chat => widget.chat;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;
    final chat = widget.chat;
    final color = isMe
        ? AppColors.primary
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200]);
    final textColor = isMe
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? (isRtl ? 0 : 16) : (isRtl ? 16 : 0)),
      bottomRight: Radius.circular(isMe ? (isRtl ? 16 : 0) : (isRtl ? 0 : 16)),
    );

    if (_isHidden) {
      return GestureDetector(
        onLongPress: () {
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: GlassContainer(
                borderRadius: BorderRadius.circular(20),
                blur: 15,
                opacity:
                    Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.6,
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isRtl ? 'خيارات الرسالة' : 'Message Options',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _isHidden = false);
                      },
                      icon: const Icon(Icons.visibility, color: Colors.white),
                      label: Text(isRtl ? 'إظهار الرسالة' : 'Show Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: isMe
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: borderRadius,
              ),
              child: Icon(Icons.chat_bubble_outline,
                  color: Colors.grey[600], size: 24),
            ),
          ),
        ),
      );
    }

    return Dismissible(
      key: ValueKey('swipe_${message.id}'),
      direction:
          isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
      background: Container(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.transparent,
        child: const Icon(Icons.reply, color: AppColors.primary),
      ),
      confirmDismiss: (direction) async {
        if (widget.onReply != null) {
          widget.onReply!(message);
        }
        return false; // Prevent actual dismissal
      },
      child: GestureDetector(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => GlassContainer(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              color: Theme.of(context).cardColor,
              blur: 15,
              opacity:
                  Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.6,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.reply, color: AppColors.primary),
                      title: Text(isRtl ? 'رد' : 'Reply'),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (widget.onReply != null) {
                          widget.onReply!(message);
                        }
                      },
                    ),
                    if (message.type == MessageType.text)
                      ListTile(
                        leading: const Icon(Icons.copy, color: Colors.blue),
                        title: Text(isRtl ? 'نسخ النص' : 'Copy Text'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Clipboard.setData(
                              ClipboardData(text: message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(isRtl
                                    ? 'تم النسخ إلى الحافظة'
                                    : 'Copied to clipboard'),
                                duration: const Duration(seconds: 1)),
                          );
                        },
                      ),
                    if (message.type == MessageType.file ||
                        message.type == MessageType.image)
                      ListTile(
                        leading:
                            const Icon(Icons.download, color: Colors.green),
                        title: Text(
                            isRtl ? 'تنزيل المرفق' : 'Download Attachment'),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (message.type == MessageType.file &&
                              message.attachmentUrl != null) {
                            FileDownloadService.downloadAndOpen(
                              context: context,
                              url: message.attachmentUrl!,
                              fileName: message.attachmentName ?? 'ملف',
                            );
                          } else if (message.type == MessageType.image &&
                              message.attachmentUrl != null) {
                            FileDownloadService.downloadAndOpen(
                              context: context,
                              url: message.attachmentUrl!,
                              fileName: 'image_${message.id}.jpg',
                            );
                          }
                        },
                      ),
                    if (isMe && message.type == MessageType.text)
                      ListTile(
                        leading: const Icon(Icons.edit, color: Colors.orange),
                        title: Text(isRtl ? 'تعديل' : 'Edit'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showEditMessageDialog(context, isRtl);
                        },
                      ),
                    ListTile(
                      leading:
                          const Icon(Icons.visibility_off, color: Colors.grey),
                      title: Text(isRtl ? 'إخفاء لدي' : 'Hide for me'),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _isHidden = true);
                      },
                    ),
                    if (isMe)
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: Text(isRtl ? 'حذف' : 'Delete',
                            style: const TextStyle(color: Colors.red)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          try {
                            await context.read<ChatProvider>().deleteMessage(
                                  message.id,
                                  chatId: chat.id,
                                );
                            if (!mounted) return;
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(isRtl
                                    ? 'تم حذف الرسالة'
                                    : 'Message deleted'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            debugPrint('Error deleting message: $e');
                            if (!mounted) return;
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(isRtl
                                    ? 'فشل حذف الرسالة'
                                    : 'Failed to delete message'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        child: Align(
          alignment: isMe
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(12),
                    blur: 15,
                    opacity: isMe
                        ? 0.9
                        : (Theme.of(context).brightness == Brightness.dark
                            ? 0.3
                            : 0.6),
                    color: color,
                    borderRadius: borderRadius,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildMessageContent(context, textColor),
                        if (message.isUploading)
                          Positioned(
                            bottom: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeago.format(message.createdAt, locale: 'ar'),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      if (message.isUploading) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'جاري الإرسال...',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ] else if (message.isEdited) ...[
                        const SizedBox(width: 4),
                        Text(
                          isRtl ? '(معدلة)' : '(edited)',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                      if (isMe && !message.isUploading) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead ? Colors.blue : Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditMessageDialog(BuildContext context, bool isRtl) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(20),
          blur: 15,
          opacity: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.6,
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isRtl ? 'تعديل الرسالة' : 'Edit Message',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: null,
                decoration: InputDecoration(
                  hintText:
                      isRtl ? 'اكتب رسالتك هنا...' : 'Type your message...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isRtl ? 'إلغاء' : 'Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final chatProvider = context.read<ChatProvider>();
                      final newText = controller.text.trim();
                      final currentContext = context;
                      if (newText.isNotEmpty && newText != message.content) {
                        await chatProvider.editMessage(
                          message.id,
                          newText,
                          chatId: chat.id,
                        );
                      }
                      if (!mounted) return;
                      Navigator.pop(currentContext);
                    },
                    child: Text(isRtl ? 'حفظ' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _extractFirstUrl(String text) {
    final RegExp urlRegex = RegExp(
      r'((?:https?:\/\/|www\.)[^\s؀-ۿ()<>]+|\b[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\/[^\s؀-ۿ()<>]*)?)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      String url = match.group(0)!;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      return url;
    }
    return null;
  }

  Widget _buildMessageContent(BuildContext context, Color textColor) {
    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (message.attachmentUrl != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                  imageUrls: [message.attachmentUrl!],
                                  initialIndex: 0)));
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.attachmentUrl ?? '',
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                            height: 150,
                            child: Center(child: CircularProgressIndicator()));
                      },
                    ),
                  ),
                ),
                if (message.attachmentUrl != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        final fileName = 'image_${message.id}.jpg';
                        FileDownloadService.downloadAndOpen(
                          context: context,
                          url: message.attachmentUrl!,
                          fileName: fileName,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
            if (message.content.isNotEmpty && message.content != '📷 صورة') ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinkableText(
                    text: message.content, style: TextStyle(color: textColor)),
              ),
              if (_extractFirstUrl(message.content) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: InternalLinkPreviewWidget.isInternalLink(
                            _extractFirstUrl(message.content)!)
                        ? InternalLinkPreviewWidget(
                            url: _extractFirstUrl(message.content)!)
                        : AnyLinkPreview(
                            link: _extractFirstUrl(message.content)!,
                            displayDirection: UIDirection.uiDirectionHorizontal,
                            backgroundColor: Colors.grey[200],
                            errorWidget: const SizedBox.shrink(),
                            errorImage: '',
                            cache: const Duration(days: 7),
                            placeholderWidget: Container(
                              padding: const EdgeInsets.all(12),
                              decoration:
                                  BoxDecoration(color: Colors.grey[200]),
                              child: Row(
                                children: [
                                  const Icon(Icons.link, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'جاري تحميل الرابط...',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ],
        );
      case MessageType.audio:
        return VoiceMessageWidget(
            url: message.attachmentUrl ?? '',
            duration: message.duration ?? 0,
            isMe: isMe);
      case MessageType.file:
        return _FileMessageWidget(
          message: message,
          isMe: isMe,
          textColor: textColor,
        );
      case MessageType.contract:
        return _buildContractContent(context, textColor);
      default:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Widget textWidget = LinkableText(
            text: message.content,
            style: TextStyle(color: textColor, fontSize: 15));

        // Parse Telegram-style reply
        if (message.content.startsWith('╭ الرد على ') ||
            message.content.startsWith('╭ Replying to ')) {
          final lines = message.content.split('\n');
          if (lines.length >= 4) {
            final senderLine = lines[0];
            final quoteLine = lines[1];
            final borderLine = lines[2];
            if (quoteLine.startsWith('│ ') && borderLine.startsWith('╰──')) {
              final sender = senderLine
                  .replaceFirst('╭ الرد على ', '')
                  .replaceFirst('╭ Replying to ', '');
              final quote = quoteLine.substring(2);
              final actualText = lines.sublist(3).join('\n');

              textWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.only(
                        left: 8, right: 8, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.black.withValues(alpha: 0.15)
                          : (isDark ? Colors.black26 : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 3,
                              decoration: BoxDecoration(
                                  color:
                                      isMe ? Colors.white : AppColors.primary,
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sender,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isMe
                                            ? Colors.white
                                            : AppColors.primary)),
                                const SizedBox(height: 2),
                                Text(quote,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white70
                                            : (isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[700])),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  LinkableText(
                      text: actualText,
                      style: TextStyle(color: textColor, fontSize: 15)),
                ],
              );
            }
          }
        }

        return Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            textWidget,
            if (_extractFirstUrl(message.content) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InternalLinkPreviewWidget.isInternalLink(
                          _extractFirstUrl(message.content)!)
                      ? InternalLinkPreviewWidget(
                          url: _extractFirstUrl(message.content)!)
                      : AnyLinkPreview(
                          link: _extractFirstUrl(message.content)!,
                          displayDirection: UIDirection.uiDirectionHorizontal,
                          backgroundColor: Colors.grey[200],
                          errorWidget: const SizedBox.shrink(),
                          errorImage: '',
                          cache: const Duration(days: 7),
                          placeholderWidget: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey[200]),
                            child: Row(
                              children: [
                                const Icon(Icons.link, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text(
                                  'جاري تحميل الرابط...',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
          ],
        );
    }
  }

  Widget _buildContractContent(BuildContext context, Color textColor) {
    IconData statusIcon = Icons.pending_actions;
    Color statusColor = Colors.orange;
    String statusText = 'قيد الانتظار';

    if (message.contractStatus == 'accepted') {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
      statusText = 'مقبول وبدأ العمل';
    } else if (message.contractStatus == 'rejected') {
      statusIcon = Icons.cancel;
      statusColor = Colors.red;
      statusText = 'تم الرفض';
    } else if (message.contractStatus == 'cancel_requested') {
      statusIcon = Icons.warning_amber_rounded;
      statusColor = Colors.deepOrange;
      statusText = 'طلب إلغاء';
    } else if (message.contractStatus == 'cancelled') {
      statusIcon = Icons.cancel_schedule_send;
      statusColor = Colors.grey;
      statusText = 'تم الإلغاء';
    }

    final currentUserId = context.read<AuthProvider>().user?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2736) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border:
            Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (Gradient)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.handshake_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('عقد عمل ذكي',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
                ),
                Icon(statusIcon, color: Colors.white, size: 20),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text('تفاصيل المهمة:',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                LinkableText(
                    text: message.contractDetails ?? '',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.5)),

                const SizedBox(height: 16),

                // Price Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المبلغ المتفق عليه:',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary)),
                      Text('${message.contractPrice} SDG',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.secondary)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Status line
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),

                // Action Buttons
                if (!isMe && message.contractStatus == 'pending') ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await context
                                .read<ChatProvider>()
                                .updateContractStatus(message.id, 'rejected');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('رفض',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Show a simple loading indicator dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white)),
                            );

                            try {
                              // Extract details for the job
                              final freelancerId = message.senderId;
                              final freelancerName =
                                  chat.participantNames[freelancerId] ??
                                      'مستقل';

                              final clientId = currentUserId ?? '';
                              final clientName =
                                  chat.participantNames[clientId] ?? 'عميل';
                              final clientImageUrl =
                                  chat.participantImages[clientId];

                              // 1. Start the Project
                              final jobProvider = context.read<JobProvider>();
                              final chatProvider = context.read<ChatProvider>();
                              final jobId = await jobProvider.startProject(
                                clientId: clientId,
                                clientName: clientName,
                                clientImageUrl: clientImageUrl,
                                title: 'عقد عمل مع $freelancerName',
                                description: message.contractDetails ??
                                    'تم إنشاء الاتفاق عبر الدردشة',
                                price: message.contractPrice ?? 0.0,
                                freelancerId: freelancerId,
                                freelancerName: freelancerName,
                              );

                              if (jobId != null) {
                                // 2. Update the contract status with the new job ID
                                await chatProvider.updateContractStatus(
                                    message.id, 'accepted',
                                    jobId: jobId);
                                if (!context.mounted) return;
                                Navigator.pop(context); // Close loading dialog
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'تم توقيع العقد وبدء المشروع بنجاح! 🎉'),
                                      backgroundColor: Colors.green),
                                );
                              } else {
                                if (!context.mounted) return;
                                Navigator.pop(context); // Close loading dialog
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('حدث خطأ أثناء إنشاء المشروع'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            } catch (e) {
                              if (context.mounted)
                                Navigator.pop(context); // Close loading dialog
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                          ),
                          child: const Text('موافقة وبدء العمل',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],

                // Additional Actions
                if (message.contractStatus == 'pending') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showEditContractDialog(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('طلب تعديل الاتفاق',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                if (message.contractStatus == 'accepted') ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final jobId = message.jobId;
                        if (jobId != null && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActiveJobTrackingScreen(jobId: jobId),
                            ),
                          );
                        } else {
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                                content: Text('لم يتم العثور على المشروع')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.dashboard_customize, size: 18),
                      label: const Text('متابعة مسار المشروع',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                if (message.contractStatus == 'cancel_requested' &&
                    message.cancelRequesterId != currentUserId) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context
                            .read<ChatProvider>()
                            .updateContractStatus(message.id, 'cancelled');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.cancel_schedule_send, size: 18),
                      label: const Text('الموافقة على الإلغاء',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditContractDialog(BuildContext context) {
    final detailsController =
        TextEditingController(text: message.contractDetails);
    final priceController =
        TextEditingController(text: message.contractPrice?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الاتفاق',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(
                  labelText: 'وصف الخدمة المعدل', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                  labelText: 'السعر المعدل (SDG)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final details = detailsController.text.trim();
              final priceStr = priceController.text.trim();
              if (details.isEmpty || priceStr.isEmpty) return;
              final price = double.tryParse(priceStr);
              if (price == null) return;

              Navigator.pop(ctx);

              await context.read<ChatProvider>().updateContractDetails(
                    message.id,
                    details,
                    price,
                  );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('تحديث الاتفاق',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class VoiceMessageWidget extends StatefulWidget {
  final String url;
  final int duration;
  final bool isMe;

  const VoiceMessageWidget(
      {super.key,
      required this.url,
      required this.duration,
      required this.isMe});

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  late AnimationController _pulseController;

  // Fake waveform data for visual effect
  static const List<double> _waveformBars = [
    0.3,
    0.5,
    0.7,
    0.4,
    0.8,
    0.6,
    0.9,
    0.5,
    0.7,
    0.3,
    0.6,
    0.8,
    0.4,
    0.7,
    0.5,
    0.9,
    0.6,
    0.4,
    0.8,
    0.5,
    0.7,
    0.3,
    0.6,
    0.9,
    0.5,
    0.7,
    0.4,
    0.8,
    0.6,
    0.3,
    0.5,
    0.8,
    0.4,
    0.7,
    0.6,
    0.9,
    0.3,
    0.5,
    0.7,
    0.4,
  ];

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.duration);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted && d.inSeconds > 0) setState(() => _totalDuration = d);
    });

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _isPlaying = s == PlayerState.playing;
        _isLoading = false;
      });
      if (s == PlayerState.playing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
      if (s == PlayerState.completed) {
        setState(() => _position = Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      setState(() => _isLoading = true);
      await _audioPlayer.play(UrlSource(widget.url));
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
    }
  }

  void _cycleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = widget.isMe ? Colors.white : AppColors.primary;
    final secondaryColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.4)
        : (isDark ? Colors.grey[600]! : Colors.grey[400]!);
    final textColor =
        widget.isMe ? Colors.white : (isDark ? Colors.white70 : Colors.black87);

    final totalMs = _totalDuration.inMilliseconds;
    final posMs = _position.inMilliseconds;
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // ── Play/Pause Button ──
              GestureDetector(
                onTap: _togglePlay,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = _isPlaying
                        ? 1.0 + (_pulseController.value * 0.08)
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isMe
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.primary.withValues(alpha: 0.12),
                        ),
                        child: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              )
                            : Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: primaryColor,
                                size: 24,
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // ── Waveform ──
              Expanded(
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    // Account for the play button width (48px)
                    final waveWidth = box.size.width - 48;
                    final localX = details.localPosition.dx - 48;
                    final ratio = (localX / waveWidth).clamp(0.0, 1.0);
                    final seekPos =
                        Duration(milliseconds: (totalMs * ratio).toInt());
                    _audioPlayer.seek(seekPos);
                  },
                  onTapDown: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final waveWidth = box.size.width - 48;
                    final localX = details.localPosition.dx - 48;
                    final ratio = (localX / waveWidth).clamp(0.0, 1.0);
                    final seekPos =
                        Duration(milliseconds: (totalMs * ratio).toInt());
                    _audioPlayer.seek(seekPos);
                  },
                  child: SizedBox(
                    height: 32,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        bars: _waveformBars,
                        progress: progress,
                        activeColor: primaryColor,
                        inactiveColor: secondaryColor,
                      ),
                      size: const Size(double.infinity, 32),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // ── Timer + Speed ──
          Padding(
            padding: const EdgeInsets.only(right: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isPlaying || _position.inSeconds > 0
                      ? _formatDuration(_position)
                      : _formatDuration(_totalDuration),
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.7),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (_isPlaying || _position.inSeconds > 0)
                  Text(
                    _formatDuration(_totalDuration),
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withValues(alpha: 0.5),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                // Speed button
                GestureDetector(
                  onTap: _cycleSpeed,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_playbackSpeed}x',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom waveform painter — draws vertical bars with progress coloring
class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = bars.length;
    final totalGaps = barCount - 1;
    const barGap = 2.0;
    final barWidth = (size.width - totalGaps * barGap) / barCount;
    final maxBarHeight = size.height * 0.85;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + barGap);
      final barHeight = bars[i] * maxBarHeight;
      final isActive = (i / barCount) <= progress;

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..strokeCap = StrokeCap.round;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth.clamp(1.5, 3.5),
          height: barHeight.clamp(3.0, maxBarHeight),
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ── File Message Widget (تيليغرام أسلوب) ──────────────────────────────────
class _FileMessageWidget extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final Color textColor;

  const _FileMessageWidget({
    required this.message,
    required this.isMe,
    required this.textColor,
  });

  @override
  State<_FileMessageWidget> createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends State<_FileMessageWidget> {
  bool _isDownloading = false;
  bool _fileExists = false;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  Future<void> _checkFileExists() async {
    final fileName = widget.message.attachmentName;
    if (fileName == null) return;
    final exists = await FileDownloadService.fileExists(fileName);
    if (mounted && exists) {
      setState(() => _fileExists = true);
    }
  }

  String _getFileIcon(String? fileName) {
    if (fileName == null) return '📎';
    final ext = fileName.split('.').last.toLowerCase();
    if (['pdf'].contains(ext)) return '📄';
    if (['doc', 'docx'].contains(ext)) return '📝';
    if (['xls', 'xlsx'].contains(ext)) return '📊';
    if (['zip', 'rar', '7z'].contains(ext)) return '🗜️';
    if (['mp4', 'avi', 'mov'].contains(ext)) return '🎬';
    if (['mp3', 'wav', 'aac'].contains(ext)) return '🎵';
    if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return '🖼️';
    return '📎';
  }

  Color _getFileColor(String? fileName) {
    if (fileName == null) return Colors.blue;
    final ext = fileName.split('.').last.toLowerCase();
    if (['pdf'].contains(ext)) return Colors.red;
    if (['doc', 'docx'].contains(ext)) return Colors.blue;
    if (['xls', 'xlsx'].contains(ext)) return Colors.green;
    if (['zip', 'rar', '7z'].contains(ext)) return Colors.orange;
    if (['mp4', 'avi', 'mov'].contains(ext)) return Colors.purple;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.message.attachmentName ?? 'ملف';
    final fileColor = _getFileColor(fileName);
    final fileIcon = _getFileIcon(fileName);

    return GestureDetector(
      onTap: _isDownloading
          ? null
          : () async {
              if (widget.message.attachmentUrl == null) return;
              if (_fileExists) {
                await FileDownloadService.openFile(fileName);
                return;
              }
              setState(() => _isDownloading = true);
              await FileDownloadService.downloadAndOpen(
                context: context,
                url: widget.message.attachmentUrl!,
                fileName: fileName,
              );
              if (mounted) {
                setState(() {
                  _isDownloading = false;
                  _fileExists = true;
                });
              }
            },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.15)
              : fileColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe
                ? Colors.white.withValues(alpha: 0.3)
                : fileColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fileColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: _isDownloading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.isMe ? Colors.white : fileColor,
                        ),
                      )
                    : Text(fileIcon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: widget.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  if (!_fileExists) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _isDownloading
                              ? Icons.downloading
                              : Icons.download_rounded,
                          size: 14,
                          color: widget.isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : fileColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isDownloading ? 'جاري التحميل...' : 'اضغط للتحميل',
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : fileColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.2, end: 1.0).animate(_controller),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.2).animate(_controller),
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
