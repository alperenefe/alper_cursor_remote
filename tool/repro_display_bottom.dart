// ignore_for_file: avoid_print
/// Kök neden kanıtı: PC geçmişi + display sıralama.
/// dart run tool/repro_display_bottom.dart
import 'dart:convert';
import 'dart:io';

import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/services/chat_history_applier.dart';
import 'package:alper_cursor_remote/state/chat/chat_message_match.dart';
import 'package:alper_cursor_remote/state/chat/chat_turn_logic.dart';
import 'package:alper_cursor_remote/state/chat/history_sync_protection.dart';
import 'package:alper_cursor_remote/state/display/conversation_display_order.dart';

const musicSid = '0c988c83-81d3-4632-ba1f-6ffb6b9dd838';

void main() {
  final path = Platform.environment['CHAT_HISTORY'] ??
      r'c:\cursorProjects\.cursor\CHAT_HISTORY.json';
  final entries = (jsonDecode(File(path).readAsStringSync())['entries'] as List)
      .cast<Map<String, dynamic>>();

  final music = entries.where((e) => e['sessionId'] == musicSid).toList()
    ..sort(
      (a, b) =>
          (a['timestamp'] as String).compareTo(b['timestamp'] as String),
    );
  final newest = List<Map<String, dynamic>>.from(music)
    ..sort(
      (a, b) =>
          (b['timestamp'] as String).compareTo(a['timestamp'] as String),
    );
  final window = newest.take(5).toList().reversed.toList();
  final normalized = normalizeHistoryEntries(window);
  final imported = dedupeEquivalentUserMessages(
    entriesToChatMessages(normalized, alreadyNormalized: true),
  );

  final lastPcUser = imported.lastWhere((m) => m.role == ChatRole.user);
  final lastPcAsst = imported.lastWhere((m) => m.role == ChatRole.assistant);

  print('=== A) Sadece PC geçmişi (5 tur) — fix sonrası EN ALT assistant olmalı ===');
  report('imported raw', imported);
  report('orderSettledByTurns', orderSettledByTurns(imported));
  report(
    'buildConversationDisplay',
    buildConversationDisplayMessages(visible: imported, effectiveQueue: []),
  );

  print('\n=== B) PC + korumalı yerel userPrompt (merge sonrası) ===');
  final local = ChatMessage(
    id: 'local-msg-test',
    role: ChatRole.user,
    text: lastPcUser.text,
    at: lastPcUser.at.add(const Duration(seconds: 2)),
    kind: InboundKind.userPrompt,
  );
  final merged = List<ChatMessage>.from(imported);
  mergeProtectedIntoList(
    merged,
    [local],
    localIsRicher: localUserBubbleIsRicher,
    messagesEquivalent: chatMessagesEquivalent,
    sortChronologically: sortChatMessagesChronologically,
  );
  final deduped = dedupeEquivalentUserMessages(merged);
  merged
    ..clear()
    ..addAll(deduped);
  report('after merge+dedupe (app gibi)', merged);
  report('orderSettledByTurns', orderSettledByTurns(merged));
  report(
    'display (pin yok)',
    buildConversationDisplayMessages(visible: merged, effectiveQueue: []),
  );
  report(
    'display (pin local)',
    buildConversationDisplayMessages(
      visible: merged,
      effectiveQueue: [],
      inFlightUserMessageId: 'local-msg-test',
    ),
  );

  print('\n=== C) Son tur asistanı hangi kullanıcıya bağlandı? ===');
  final settled = orderSettledByTurns(merged);
  final idxAsst = settled.indexWhere((m) => m.id == lastPcAsst.id);
  final idxUserBefore = settled.lastIndexWhere(
    (m) => m.role == ChatRole.user && settled.indexOf(m) < idxAsst,
  );
  print('  Son PC asistan id=${lastPcAsst.id}');
  print('  orderSettled içinde index=$idxAsst');
  if (idxAsst > 0) {
    print('  Hemen önceki balon: ${settled[idxAsst - 1].role} id=${settled[idxAsst - 1].id}');
    print('  Beklenen son user: ${lastPcUser.id} → yerel merge: local-msg-test');
  }
  print('  EN ALT: ${settled.last.role} id=${settled.last.id}');

  print('\n=== D) A senaryosu — tam orderSettled sırası ===');
  for (final m in orderSettledByTurns(imported)) {
    final tag = m.role == ChatRole.user ? 'U' : 'A';
    print('  $tag ${m.id.substring(m.id.length > 12 ? m.id.length - 12 : 0)}');
  }
}

void report(String label, List<ChatMessage> msgs) {
  final last = msgs.isEmpty ? null : msgs.last;
  print('[$label] ${msgs.length} balon, EN ALT=${last?.role.name} id=${last?.id}');
  if (last != null && last.role == ChatRole.user) {
    print('  ⚠ EN ALTTAKİ KULLANICI — asistan yok');
  }
}
