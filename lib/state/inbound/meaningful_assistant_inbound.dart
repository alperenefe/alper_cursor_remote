import '../../models/chat_message.dart';
import '../../services/assistant_text_sanitize.dart';
import '../../services/message_parser.dart';

bool isMeaningfulAssistantInbound(ParsedInbound parsed) {
  return parsed.chatLines.any(
    (l) =>
        l.role == ChatRole.assistant &&
        l.text.trim().isNotEmpty &&
        !isGarbageAssistantText(l.text) &&
        (l.kind == InboundKind.chatResponse ||
            l.kind == InboundKind.chatResponseComplete),
  );
}
