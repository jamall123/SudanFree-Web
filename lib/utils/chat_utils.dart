import '../models/message_model.dart';

/// Helper utilities for chat message operations.
List<MessageModel> removeTemporaryMessage(
    List<MessageModel> messages, String tempId) {
  return messages.where((m) => m.id != tempId).toList();
}
