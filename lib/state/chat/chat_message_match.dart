import '../../models/chat_message.dart';
import '../../services/assistant_text_sanitize.dart';
import '../../services/chat_bubble_format.dart';

String normalizeUserBubbleText(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Asistan balonu eşlemesi — yalnızca aynı metin (benzerlik / atlama yok).
String normalizedAssistantBody(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

List<String> attachmentNamesInUserText(String text) {
  final fromBlock = extractMobilAttachmentNames(text);
  if (fromBlock.isNotEmpty) return fromBlock;
  final clip = RegExp(r'^📎\s*(.+)$', multiLine: true).firstMatch(text.trim());
  if (clip == null) return const [];
  return clip
      .group(1)!
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

String userTextBodyWithoutAttachments(String text) {
  var body = text.trim();
  if (body.contains('[Mobil ekler')) {
    body = formatUserBubbleForDisplay(body);
  }
  return body.replaceFirst(RegExp(r'^📎[^\n]*\n*'), '').trim();
}

bool userMessagesLikelySame(String a, String b) {
  final na = normalizeUserBubbleText(a);
  final nb = normalizeUserBubbleText(b);
  if (na == nb) return true;
  if (na.isEmpty || nb.isEmpty) return false;
  if (na.contains(nb) || nb.contains(na)) return true;

  final namesA = attachmentNamesInUserText(a);
  final namesB = attachmentNamesInUserText(b);
  if (namesA.isNotEmpty && namesB.isNotEmpty) {
    final setA = namesA.toSet();
    final setB = namesB.toSet();
    if (setA.length == setB.length && setA.containsAll(setB)) {
      final bodyA = userTextBodyWithoutAttachments(a);
      final bodyB = userTextBodyWithoutAttachments(b);
      if (bodyA == bodyB) return true;
      if (bodyA.isEmpty || bodyB.isEmpty) return true;
      if (bodyA.contains(bodyB) || bodyB.contains(bodyA)) return true;
    }
  }

  final attachLine = RegExp(r'^📎\s*(.+)$', multiLine: true).firstMatch(a);
  if (attachLine != null) {
    final names = attachLine
        .group(1)!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    if (names.isNotEmpty && names.every((n) => b.contains(n))) {
      return true;
    }
  }
  return false;
}

bool chatMessagesEquivalent(ChatMessage a, ChatMessage b) {
  if (a.role != b.role) return false;
  if (a.role == ChatRole.user) {
    return userMessagesLikelySame(a.text, b.text);
  }
  if (a.role == ChatRole.assistant) {
    return normalizedAssistantBody(a.text) == normalizedAssistantBody(b.text);
  }
  return false;
}

bool listContainsEquivalentMessage(
  List<ChatMessage> list,
  ChatMessage candidate,
) {
  return list.any((m) => chatMessagesEquivalent(m, candidate));
}

bool preferUserBubbleOver(ChatMessage candidate, ChatMessage other) {
  if (candidate.role != ChatRole.user || other.role != ChatRole.user) {
    return false;
  }
  if (candidate.kind == InboundKind.userPrompt &&
      other.kind != InboundKind.userPrompt) {
    return true;
  }
  if (!candidate.id.startsWith('h-') && other.id.startsWith('h-u-')) {
    return true;
  }
  final ct = candidate.text;
  final ot = other.text;
  if (other.text.contains('[Mobil ekler') && candidate.text.contains('📎')) {
    return true;
  }
  if (ct.length > ot.length + 8) return true;
  if (ct.contains('📎') && !ot.contains('📎')) return true;
  if (ct.contains('[Mobil ekler') && !ot.contains('[Mobil ekler')) {
    return true;
  }
  return false;
}

bool localUserBubbleIsRicher(ChatMessage local, ChatMessage existing) =>
    preferUserBubbleOver(local, existing);

/// Birleştirmede yerel gönderim (zaman + sade metin) korunur.
ChatMessage pickPreferredUserBubble(ChatMessage a, ChatMessage b) {
  if (a.id.startsWith('h-u-') && !b.id.startsWith('h-')) return b;
  if (b.id.startsWith('h-u-') && !a.id.startsWith('h-')) return a;
  if (preferUserBubbleOver(a, b)) return a;
  if (preferUserBubbleOver(b, a)) return b;
  return a.at.isBefore(b.at) ? a : b;
}
