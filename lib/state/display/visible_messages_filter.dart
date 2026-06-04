import '../../models/chat_message.dart';

List<ChatMessage> filterVisibleMessages(
  List<ChatMessage> messages, {
  required bool showLogs,
  required bool showSystem,
  required bool mergeStreamChunks,
  required bool showProgress,
}) {
  return messages.where((m) {
    if (m.role == ChatRole.log) return showLogs;
    if (m.role == ChatRole.system) return showSystem;
    if (m.kind == InboundKind.chatResponseChunk && !mergeStreamChunks) {
      return false;
    }
    if (m.role == ChatRole.progress) return showProgress;
    if (m.role == ChatRole.user || m.role == ChatRole.assistant) return true;
    return false;
  }).toList();
}
