import 'chat_message.dart';

extension ChatMessageJson on ChatMessage {
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'at': at.toIso8601String(),
        'kind': kind.name,
        if (agentMode != null) 'agentMode': agentMode,
        'isStreaming': isStreaming,
        if (replyToUserId != null) 'replyToUserId': replyToUserId,
        if (sessionId != null) 'sessionId': sessionId,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: _roleFrom(json['role']?.toString()),
      text: json['text']?.toString() ?? '',
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      kind: _kindFrom(json['kind']?.toString()),
      agentMode: json['agentMode']?.toString(),
      isStreaming: json['isStreaming'] == true,
      replyToUserId: json['replyToUserId']?.toString(),
      sessionId: json['sessionId']?.toString(),
    );
  }

  static ChatRole _roleFrom(String? raw) {
    switch (raw) {
      case 'user':
        return ChatRole.user;
      case 'assistant':
        return ChatRole.assistant;
      case 'system':
        return ChatRole.system;
      case 'log':
        return ChatRole.log;
      case 'progress':
        return ChatRole.progress;
      default:
        return ChatRole.assistant;
    }
  }

  static InboundKind _kindFrom(String? raw) {
    if (raw == null || raw.isEmpty) return InboundKind.chatResponse;
    for (final k in InboundKind.values) {
      if (k.name == raw) return k;
    }
    return InboundKind.chatResponse;
  }
}
