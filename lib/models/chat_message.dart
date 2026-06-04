enum ChatRole {
  user,
  assistant,
  system,
  log,
  progress,
}

enum InboundKind {
  chatResponse,
  chatResponseChunk,
  chatResponseComplete,
  userPrompt,
  agentProgress,
  log,
  system,
  commandResult,
  connectionStatus,
  unknown,
}

InboundKind inboundKindFromType(String? type) {
  switch (type) {
    case 'chat_response':
      return InboundKind.chatResponse;
    case 'chat_response_chunk':
      return InboundKind.chatResponseChunk;
    case 'chat_response_complete':
      return InboundKind.chatResponseComplete;
    case 'user_prompt':
      return InboundKind.userPrompt;
    case 'log':
      return InboundKind.log;
    case 'connected':
    case 'connection_status':
      return InboundKind.connectionStatus;
    case 'agent_progress':
      return InboundKind.agentProgress;
    case 'agent_mode_selected':
      return InboundKind.system;
    case 'command_result':
      return InboundKind.commandResult;
    default:
      if (type != null &&
          (type.contains('error') || type == 'system')) {
        return InboundKind.system;
      }
      return InboundKind.unknown;
  }
}

/// Sohbet listesinde gösterilsin mi (varsayılan filtre).
bool shouldShowInChatByDefault(InboundKind kind) {
  switch (kind) {
    case InboundKind.chatResponse:
    case InboundKind.chatResponseComplete:
    case InboundKind.userPrompt:
      return true;
    case InboundKind.chatResponseChunk:
      return false; // birleştirme açıksa controller gösterir
    case InboundKind.agentProgress:
      return false; // showProgress ile gösterilir
    case InboundKind.log:
    case InboundKind.system:
    case InboundKind.commandResult:
    case InboundKind.connectionStatus:
    case InboundKind.unknown:
      return false;
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.kind = InboundKind.chatResponse,
    this.agentMode,
    this.isStreaming = false,
    this.replyToUserId,
    this.sessionId,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime at;
  final InboundKind kind;
  final String? agentMode;
  final bool isStreaming;
  /// Agent cevabı hangi kullanıcı mesajına ait (sıra modu).
  final String? replyToUserId;
  /// Cursor CLI oturum kimliği (PC geçmişi ile uyumlu).
  final String? sessionId;

  ChatMessage copyWith({
    String? text,
    bool? isStreaming,
    InboundKind? kind,
    String? replyToUserId,
    String? sessionId,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      at: at,
      kind: kind ?? this.kind,
      agentMode: agentMode,
      isStreaming: isStreaming ?? this.isStreaming,
      replyToUserId: replyToUserId ?? this.replyToUserId,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}
