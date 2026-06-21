import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/chat_utils.dart';
import 'package:universal_io/io.dart';
import 'dart:async';

class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  List<ChatModel> _chats = [];
  List<MessageModel> _messages = [];
  ChatModel? _currentChat;

  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  StreamSubscription? _chatsSubscription;
  StreamSubscription? _messagesSubscription;

  List<ChatModel> get chats => _chats;
  List<MessageModel> get messages => _messages;
  ChatModel? get currentChat => _currentChat;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  // Get total unread count
  int getTotalUnreadCount(String userId) {
    return _chats.fold(0, (total, chat) => total + chat.getUnreadCount(userId));
  }

  // Fetch user's chats ONCE (Get instead of Listen to save costs)
  Future<void> fetchChats(String userId) async {
    if (_isLoading && _chats.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      _chatsSubscription?.cancel(); // Cancel any existing stream just in case
      final chats = await _firestoreService.getUserChatsOnce(userId);
      _chats = chats;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Get or create chat with another user
  Future<ChatModel?> getOrCreateChat({
    required String currentUserId,
    required String currentUserName,
    String? currentUserImageUrl,
    required String otherUserId,
    required String otherUserName,
    String? otherUserImageUrl,
    String? jobId,
    String? jobTitle,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final chat = await _firestoreService.getOrCreateChat(
        user1Id: currentUserId,
        user1Name: currentUserName,
        user1ImageUrl: currentUserImageUrl,
        user2Id: otherUserId,
        user2Name: otherUserName,
        user2ImageUrl: otherUserImageUrl,
        jobId: jobId,
        jobTitle: jobTitle,
      );
      _currentChat = chat;
      _isLoading = false;
      notifyListeners();
      return chat;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Open chat and load messages
  void openChat(ChatModel chat, String currentUserId) {
    _currentChat = chat;
    _messages = [];
    notifyListeners();

    // Mark messages as read
    _firestoreService.markMessagesAsRead(chat.id, currentUserId);

    // Listen to messages
    _messagesSubscription?.cancel();
    _messagesSubscription =
        _firestoreService.getChatMessages(chat.id).listen((messages) {
      _messages = messages;
      notifyListeners();
    }, onError: (error) {
      debugPrint('ChatProvider: Error fetching messages: $error');
      _errorMessage = error.toString();
      notifyListeners();
    });
  }

  // Send text message
  Future<bool> sendMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String content,
  }) async {
    if (_currentChat == null) return false;

    _isSending = true;
    // لا نستدعي notifyListeners هنا لتجنب إعادة الرسم المتكرر

    try {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final message = MessageModel(
        id: tempId,
        chatId: _currentChat!.id,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        content: content,
        createdAt: DateTime.now(),
      );

      // Optimistic Update: إضافة الرسالة فوراً للشاشة
      _messages = [message, ..._messages];
      notifyListeners();

      await _firestoreService.sendMessage(message);
      _isSending = false;
      _messages = removeTemporaryMessage(_messages, tempId);
      return true;
    } catch (e) {
      _isSending = false;
      _errorMessage = e.toString();
      // في حالة الفشل، الـ Stream سيعيد مزامنة الرسائل الصحيحة تلقائياً
      notifyListeners();
      return false;
    }
  }

  // Send image message
  Future<bool> sendImageMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required File imageFile,
  }) async {
    if (_currentChat == null) return false;

    // ── 1. ظهور فوري (Optimistic) ──
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = MessageModel(
      id: tempId,
      chatId: _currentChat!.id,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: '📷 صورة',
      type: MessageType.image,
      createdAt: DateTime.now(),
      isUploading: true,
      localFilePath: imageFile.path,
    );
    _messages = [optimisticMsg, ..._messages];
    notifyListeners();

    try {
      // ── 2. رفع للسيرفر في الخلفية ──
      final imageUrl = await _storageService.uploadChatAttachment(
        _currentChat!.id,
        imageFile,
        'image',
      );

      final message = MessageModel(
        id: '',
        chatId: _currentChat!.id,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        content: '📷 صورة',
        type: MessageType.image,
        attachmentUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await _firestoreService.sendMessage(message);

      // ── 3. حذف الرسالة المؤقتة (Firestore stream سيُظهر الحقيقية) ──
      _messages = removeTemporaryMessage(_messages, tempId);
      notifyListeners();
      return true;
    } catch (e) {
      _messages = removeTemporaryMessage(_messages, tempId);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Send file message
  Future<bool> sendFileMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required File file,
    required String fileName,
  }) async {
    if (_currentChat == null) return false;

    // ── 1. ظهور فوري (Optimistic) ──
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = MessageModel(
      id: tempId,
      chatId: _currentChat!.id,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: '📎 $fileName',
      type: MessageType.file,
      attachmentName: fileName,
      createdAt: DateTime.now(),
      isUploading: true,
      localFilePath: file.path,
    );
    _messages = [optimisticMsg, ..._messages];
    notifyListeners();

    try {
      // ── 2. رفع في الخلفية ──
      final fileUrl = await _storageService.uploadChatAttachment(
        _currentChat!.id,
        file,
        'file',
      );

      final message = MessageModel(
        id: '',
        chatId: _currentChat!.id,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        content: '📎 $fileName',
        type: MessageType.file,
        attachmentUrl: fileUrl,
        attachmentName: fileName,
        createdAt: DateTime.now(),
      );

      await _firestoreService.sendMessage(message);

      // ── 3. حذف المؤقتة ──
      _messages = removeTemporaryMessage(_messages, tempId);
      notifyListeners();
      return true;
    } catch (e) {
      _messages = removeTemporaryMessage(_messages, tempId);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Send audio message
  Future<bool> sendAudioMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required File audioFile,
    required int duration,
  }) async {
    if (_currentChat == null) return false;

    // ── 1. ظهور فوري (Optimistic) ──
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = MessageModel(
      id: tempId,
      chatId: _currentChat!.id,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: '🎤 رسالة صوتية',
      type: MessageType.audio,
      duration: duration,
      createdAt: DateTime.now(),
      isUploading: true,
      localFilePath: audioFile.path,
    );
    _messages = [optimisticMsg, ..._messages];
    notifyListeners();

    try {
      // ── 2. رفع في الخلفية ──
      final audioUrl = await _storageService.uploadChatAttachment(
        _currentChat!.id,
        audioFile,
        'audio',
      );

      final message = MessageModel(
        id: '',
        chatId: _currentChat!.id,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        content: '🎤 رسالة صوتية',
        type: MessageType.audio,
        attachmentUrl: audioUrl,
        duration: duration,
        createdAt: DateTime.now(),
      );

      await _firestoreService.sendMessage(message);

      // ── 3. حذف المؤقتة ──
      _messages = removeTemporaryMessage(_messages, tempId);
      notifyListeners();
      return true;
    } catch (e) {
      _messages = removeTemporaryMessage(_messages, tempId);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Send contract message
  Future<bool> sendContractMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String contractDetails,
    required double contractPrice,
  }) async {
    if (_currentChat == null) return false;

    _isSending = true;
    notifyListeners();

    try {
      final message = MessageModel(
        id: '',
        chatId: _currentChat!.id,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        content: '📝 تم إرسال عقد اتفاق جديد',
        type: MessageType.contract,
        contractDetails: contractDetails,
        contractPrice: contractPrice,
        contractStatus: 'pending',
        createdAt: DateTime.now(),
      );

      await _firestoreService.sendMessage(message);

      // Send notification to the receiver about the new contract
      try {
        final notification = NotificationModel(
          id: '',
          userId: receiverId,
          type: NotificationType.message,
          title: '📄 عقد اتفاق جديد من $senderName',
          message:
              'تم إرسال عقد اتفاق جديد. يرجى مراجعة التفاصيل والسعر بعناية والموافقة عليها ليكون العقد رسمياً.',
          createdAt: Timestamp.now(),
          relatedId: _currentChat!.id,
        );
        await _firestoreService.sendNotification(notification);
      } catch (e) {
        debugPrint('Error sending contract notification: $e');
      }

      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSending = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update contract status
  Future<void> updateContractStatus(String messageId, String status,
      {String? jobId, String? chatId}) async {
    try {
      final data = <String, dynamic>{'contractStatus': status};
      if (jobId != null) data['jobId'] = jobId;
      await _firestoreService.updateMessage(messageId, data,
          chatId: chatId ?? _currentChat?.id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Delete a chat message safely through the provider
  Future<void> deleteMessage(String messageId, {String? chatId}) async {
    try {
      await _firestoreService.deleteMessage(messageId,
          chatId: chatId ?? _currentChat?.id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Edit a chat message content
  Future<void> editMessage(String messageId, String content,
      {String? chatId}) async {
    try {
      await _firestoreService.updateMessage(
        messageId,
        {
          'content': content,
          'isEdited': true,
        },
        chatId: chatId ?? _currentChat?.id,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Update contract details (for editing)
  Future<void> updateContractDetails(
      String messageId, String details, double price) async {
    try {
      await _firestoreService.updateMessage(
          messageId,
          {
            'contractDetails': details,
            'contractPrice': price,
            'contractStatus': 'pending', // Revert to pending if edited
          },
          chatId: _currentChat?.id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Request cancellation
  Future<void> requestContractCancellation(
      String messageId, String requesterId) async {
    try {
      await _firestoreService.updateMessage(
          messageId,
          {
            'contractStatus': 'cancel_requested',
            'cancelRequesterId': requesterId,
          },
          chatId: _currentChat?.id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Mark current chat as read
  void markAsRead(String userId) {
    if (_currentChat != null) {
      _firestoreService.markMessagesAsRead(_currentChat!.id, userId);
    }
  }

  // Set typing status
  void setTypingStatus(String userId, bool isTyping) {
    if (_currentChat != null) {
      _firestoreService.updateTypingStatus(_currentChat!.id, userId, isTyping);
    }
  }

  // Close current chat
  void closeChat() {
    _messagesSubscription?.cancel();
    _currentChat = null;
    _messages = [];
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear all data (on logout)
  void clear() {
    _chats = [];
    _messages = [];
    _currentChat = null;
    _isLoading = false;
    _isSending = false;
    _errorMessage = null;
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
