import 'dart:convert';

import '../models/chat_message.dart';
import 'assistant_text_sanitize.dart';

/// Extension WebSocket / CLI çıktısını sohbet + sistem satırına ayırır.
class ParsedInbound {
  ParsedInbound({
    this.chatLines = const [],
    this.systemLine,
    this.kind = InboundKind.unknown,
  });

  final List<({ChatRole role, String text, InboundKind kind})> chatLines;
  final String? systemLine;
  final InboundKind kind;
}

ParsedInbound parseInboundJson(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      return ParsedInbound(systemLine: raw, kind: InboundKind.unknown);
    }
    final type = data['type'] as String?;
    final kind = inboundKindFromType(type);

    switch (kind) {
      case InboundKind.chatResponse:
        final text = _extractText(data);
        if (text.isEmpty || isGarbageAssistantText(text)) {
          return ParsedInbound(kind: kind);
        }
        return ParsedInbound(
          kind: kind,
          chatLines: [
            (role: ChatRole.assistant, text: text, kind: kind),
          ],
        );

      case InboundKind.chatResponseChunk:
        final chunk = data['text'] as String? ?? '';
        final full = data['fullText'] as String? ?? chunk;
        final text = full.isNotEmpty ? full : chunk;
        if (text.isEmpty) return ParsedInbound(kind: kind);
        return ParsedInbound(
          kind: kind,
          chatLines: [
            (
              role: ChatRole.assistant,
              text: text,
              kind: kind,
            ),
          ],
        );

      case InboundKind.chatResponseComplete:
        final text = data['text'] as String? ?? data['fullText'] as String? ?? '';
        if (text.isEmpty || isGarbageAssistantText(text)) {
          return ParsedInbound(kind: kind);
        }
        return ParsedInbound(
          kind: kind,
          chatLines: [
            (role: ChatRole.assistant, text: text, kind: InboundKind.chatResponse),
          ],
        );

      case InboundKind.agentProgress:
        final phase = data['phase'] as String? ?? 'step';
        final summary = data['summary'] as String? ?? '';
        if (summary.isEmpty) return ParsedInbound(kind: kind);
        final icon = phase == 'tool'
            ? '🔧'
            : phase == 'thinking'
                ? '💭'
                : phase == 'todo'
                    ? '☑'
                    : '▸';
        return ParsedInbound(
          kind: kind,
          chatLines: [
            (
              role: ChatRole.progress,
              text: '$icon $summary',
              kind: kind,
            ),
          ],
        );

      case InboundKind.log:
        final msg = data['message'] as String? ?? jsonEncode(data);
        final level = data['level'] as String? ?? 'info';
        return ParsedInbound(
          kind: kind,
          chatLines: [
            (role: ChatRole.log, text: '[$level] $msg', kind: kind),
          ],
        );

      case InboundKind.commandResult:
        final ok = data['success'] == true;
        final cmd = data['command_type'] as String? ?? '';
        if (cmd == 'get_chat_history' ||
            cmd == 'get_session_info' ||
            cmd == 'delete_session' ||
            cmd == 'clear_chat_history') {
          return ParsedInbound(kind: kind);
        }
        if (!ok) {
          final err = data['error'] ?? data['error_message'] ?? 'komut başarısız';
          return ParsedInbound(
            kind: kind,
            systemLine: '❌ $cmd: $err',
          );
        }
        return ParsedInbound(kind: kind);

      case InboundKind.connectionStatus:
        final status = data['status'] as String? ?? '';
        final message = data['message'] as String? ?? '';
        return ParsedInbound(
          kind: kind,
          systemLine: 'Bağlantı: $status — $message',
        );

      case InboundKind.system:
        if (type == 'connected') {
          return ParsedInbound(
            kind: kind,
            systemLine: data['message'] as String? ?? 'PC extension bağlı',
          );
        }
        if (type == 'agent_mode_selected') {
          final display = data['displayName'] as String? ?? '';
          final actual = data['actualMode'] as String? ?? '';
          return ParsedInbound(
            kind: kind,
            systemLine: display.isNotEmpty
                ? '🤖 Otomatik mod → $display ($actual)'
                : '🤖 Mod: $actual',
          );
        }
        return ParsedInbound(
          kind: kind,
          systemLine: data['message'] as String? ?? raw,
        );

      default:
        final text = _extractText(data);
        if (text.isNotEmpty && !isGarbageAssistantText(text)) {
          return ParsedInbound(
            kind: kind,
            chatLines: [
              (role: ChatRole.assistant, text: text, kind: kind),
            ],
          );
        }
        return ParsedInbound(systemLine: raw, kind: InboundKind.unknown);
    }
  } catch (_) {
    if (raw.trim().isEmpty) return ParsedInbound();
    return ParsedInbound(systemLine: raw, kind: InboundKind.unknown);
  }
}

String _extractText(Map<String, dynamic> data) {
  final t = data['text'];
  if (t is String && t.isNotEmpty) return t;
  final nested = data['data'];
  if (nested is Map && nested['text'] is String) {
    return nested['text'] as String;
  }
  return '';
}
