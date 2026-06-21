import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/message_model.dart';

class ChatFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send message
  Future<void> sendMessage(MessageModel message) async {
    final batch = _firestore.batch();

    final msgRef = _firestore
        .collection('chats')
        .doc(message.chatId)
        .collection('messages')
        .doc();

    final messageWithId = message.copyWith(id: msgRef.id);
    batch.set(msgRef, messageWithId.toFirestore());

    // Update chat metadata using merge to preserve existing fields
    // Use dot notation for nested map fields (unreadCount.userId)
    batch.set(
        _firestore.collection('chats').doc(message.chatId),
        {
          'lastMessage': message.content,
          'lastMessageTime': Timestamp.fromDate(message.createdAt),
          'lastSenderId': message.senderId,
          'unreadCount': {
            message.receiverId: FieldValue.increment(1),
          },
        },
        SetOptions(merge: true));

    await batch.commit();
  }

  // Get user's chats (Stream - for active chat view if needed)
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList());
  }

  // Get user's chats ONCE (Get - to save reads)
  Future<List<ChatModel>> getUserChatsOnce(String userId) async {
    final snapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .get();
    return snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
  }

  // Get or create chat between two users
  Future<ChatModel> getOrCreateChat({
    required String user1Id,
    required String user1Name,
    String? user1ImageUrl,
    required String user2Id,
    required String user2Name,
    String? user2ImageUrl,
    String? jobId,
    String? jobTitle,
  }) async {
    // Standardize chatId to be consistent regardless of who initiates
    final ids = [user1Id, user2Id]..sort();
    final chatId = ids.join('_');

    final chatDoc = _firestore.collection('chats').doc(chatId);

    // Try to read existing chat — may fail with permission-denied if doc doesn't exist
    // (Firestore read rule checks resource.data.participants which is null for non-existent docs)
    try {
      final snapshot = await chatDoc.get();

      if (snapshot.exists) {
        // Update participant names/images in case they changed
        await chatDoc.update({
          'participantNames.$user1Id': user1Name,
          'participantNames.$user2Id': user2Name,
          'participantImages.$user1Id': user1ImageUrl,
          'participantImages.$user2Id': user2ImageUrl,
        });
        // Re-fetch to get updated data
        final updatedSnapshot = await chatDoc.get();
        return ChatModel.fromFirestore(updatedSnapshot);
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow; // Only swallow permission-denied (means doc doesn't exist)
      }
    }

    // Chat doesn't exist — create new one
    final now = DateTime.now();
    final chat = ChatModel(
      id: chatId,
      participants: [user1Id, user2Id],
      participantNames: {
        user1Id: user1Name,
        user2Id: user2Name,
      },
      participantImages: {
        user1Id: user1ImageUrl,
        user2Id: user2ImageUrl,
      },
      unreadCount: {
        user1Id: 0,
        user2Id: 0,
      },
      typingStatus: {
        user1Id: false,
        user2Id: false,
      },
      lastMessageTime: now, // Set initial time so it appears in queries
      jobId: jobId,
      jobTitle: jobTitle,
      createdAt: now,
    );

    await chatDoc.set(chat.toFirestore());
    return chat;
  }

  // Get messages stream
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  // Mark chat as read
  Future<void> markAsRead(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.$userId': 0,
    });
  }

  // Update a message in a chat subcollection
  Future<void> updateMessage(String messageId, Map<String, dynamic> data,
      {String? chatId}) async {
    // If chatId is provided, update directly (faster and more reliable)
    if (chatId != null) {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update(data);
      return;
    }

    // Fallback: Use collectionGroup query to find the message across all chats
    final querySnapshot = await _firestore
        .collectionGroup('messages')
        .where(FieldPath.documentId, isEqualTo: messageId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.update(data);
    }
  }

  // Delete a message from a chat
  Future<void> deleteMessage(String messageId, {String? chatId}) async {
    if (chatId != null) {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      return;
    }

    final querySnapshot = await _firestore
        .collectionGroup('messages')
        .where(FieldPath.documentId, isEqualTo: messageId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.delete();
    }
  }

  // Update typing status
  Future<void> updateTypingStatus(
      String chatId, String userId, bool isTyping) async {
    await _firestore.collection('chats').doc(chatId).update({
      'typingStatus.$userId': isTyping,
    });
  }

  // Get chat by ID
  Future<ChatModel?> getChatById(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (doc.exists) return ChatModel.fromFirestore(doc);
    } catch (e) {
      // Ignore
    }
    return null;
  }
}
