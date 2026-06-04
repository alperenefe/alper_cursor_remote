// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:alper_cursor_remote/services/chat_history_applier.dart';
import 'package:alper_cursor_remote/models/chat_message.dart';

void main() {
  final path = Platform.environment['CHAT_HISTORY'] ??
      r'c:\cursorProjects\.cursor\CHAT_HISTORY.json';
  final raw = File(path).readAsStringSync();
  final j = jsonDecode(raw) as Map<String, dynamic>;
  final entries = (j['entries'] as List).cast<Map<String, dynamic>>();

  const music = '0c988c83-81d3-4632-ba1f-6ffb6b9dd838';
  const plan = 'a0ba8aa5-e56f-4d16-8536-d49818f446f4';

  for (final e in entries) {
    final um = (e['userMessage'] as String? ?? '');
    if (um.contains('müzik naber') || um.contains('slm müzik')) {
      print('CROSS: [${e['timestamp']}] session=${e['sessionId']}');
      print('  user: $um');
      print('  asst len: ${(e['assistantResponse'] as String? ?? '').length}');
    }
  }

  for (final spec in [
    ('MÜZİK', music),
    ('PLANLAYICI', plan),
  ]) {
    final label = spec.$1;
    final sid = spec.$2;
    final list =
        entries.where((e) => e['sessionId'] == sid).toList()
          ..sort(
            (a, b) =>
                (a['timestamp'] as String).compareTo(b['timestamp'] as String),
          );

    print('\n${'=' * 60}');
    print('$label — PC dosyasında ${list.length} tur');
    print('=' * 60);

    print('\n[PC] Son 6 tur — yazılma zamanı (UTC → yerel):');
    for (final e in list.sublist(list.length > 6 ? list.length - 6 : 0)) {
      dumpPcTurn(e);
    }

    // PC extension: newest 5, reverse chronological
    final newest = List<Map<String, dynamic>>.from(list)
      ..sort(
        (a, b) =>
            (b['timestamp'] as String).compareTo(a['timestamp'] as String),
      );
    final window = newest.take(5).toList().reversed.toList();

    print('\n[PC] get_chat_history(limit:5) → telefona giden ham 5 tur:');
    for (final e in window) {
      dumpPcTurn(e);
    }

    final normalized = normalizeHistoryEntries(window);
    print('\n[MOBİL] normalizeHistoryEntries sonrası ${normalized.length} tur:');
    for (final e in normalized) {
      dumpPcTurn(e);
    }

    final bubbles = entriesToChatMessages(normalized);
    print('\n[MOBİL UI] entriesToChatMessages → ${bubbles.length} balon:');
    for (final m in bubbles) {
      final role = m.role == ChatRole.user ? 'USER' : 'ASST';
      final local = m.at.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      final ss = local.second.toString().padLeft(2, '0');
      final preview = m.text.length > 48 ? '${m.text.substring(0, 48)}…' : m.text;
      print('  UI@${hh}:${mm}:${ss} ($role) id=${m.id}');
      print('    $preview');
    }
    if (bubbles.isNotEmpty) {
      final last = bubbles.last;
      print('\n  → Ekranda EN ALTTAKİ balon: ${last.role.name} @ ${last.at.toLocal()}');
    }
  }
}

void dumpPcTurn(Map<String, dynamic> e) {
  final ts = e['timestamp'] as String? ?? '';
  final local = DateTime.tryParse(ts)?.toLocal();
  final clock = local != null
      ? '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}:'
          '${local.second.toString().padLeft(2, '0')}'
      : '?';
  final um = (e['userMessage'] as String? ?? '').trim();
  final ar = (e['assistantResponse'] as String? ?? '').trim();
  final umP = um.isEmpty ? '—' : (um.length > 42 ? '${um.substring(0, 42)}…' : um);
  final arP = ar.isEmpty
      ? 'BOŞ'
      : (ar.length > 42 ? '${ar.substring(0, 42)}… (${ar.length} chr)' : ar);
  print('  PC@$clock ($ts)');
  print('    USER: $umP');
  print('    ASST: $arP');
  if (e['_droppedGarbageAssistant'] == true) {
    print('    ⚠ normalize: çöp JSON → asst silindi, tur filtreden geçebilir');
  }
}
