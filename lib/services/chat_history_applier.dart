import '../models/chat_message.dart';

import '../models/session_summary.dart';
import '../state/chat/chat_message_match.dart';
import '../state/chat/chat_turn_logic.dart';

import 'assistant_text_sanitize.dart';
import 'history_trace_log.dart';



DateTime? parseEntryTimestamp(Map<String, dynamic> entry) {

  final raw = entry['timestamp'] as String?;

  if (raw == null || raw.isEmpty) return null;

  return DateTime.tryParse(raw)?.toLocal();

}



int _entrySortKey(Map<String, dynamic> entry) {

  final t = parseEntryTimestamp(entry);

  if (t != null) return t.millisecondsSinceEpoch;

  final id = entry['id'] as String? ?? '';

  final n = int.tryParse(id.split('-').first);

  return n ?? 0;

}



bool historySessionsMatch(String a, String b) {
  final pa = a.trim();
  final pb = b.trim();
  if (pa == pb) return true;
  if (pa.isEmpty || pb.isEmpty) return false;
  if (pa.startsWith('pending-') && pb.startsWith('pending-')) {
    return pa == pb;
  }
  return false;
}



/// Parçalı kayıt: cevapsız kullanıcı + kullanıcısız cevap → tek tur.

/// Sıra modunda art arda gelen tek harf / kısa mesajları tek satırda birleştir.

List<Map<String, dynamic>> _mergeRapidUserFragments(

  List<Map<String, dynamic>> sorted,

) {

  final out = <Map<String, dynamic>>[];

  for (final entry in sorted) {

    final um = (entry['userMessage'] as String? ?? '').trim();

    final ar = (entry['assistantResponse'] as String? ?? '').trim();

    if (out.isNotEmpty && um.isNotEmpty && um.length <= 4) {

      final prev = out.last;

      final prevUm = (prev['userMessage'] as String? ?? '').trim();

      final prevAr = (prev['assistantResponse'] as String? ?? '').trim();

      final prevTs = parseEntryTimestamp(prev);

      final ts = parseEntryTimestamp(entry);

      final sameSession = historySessionsMatch(

        (prev['sessionId'] as String? ?? '').trim(),

        (entry['sessionId'] as String? ?? '').trim(),

      );

      final rapid = prevTs != null &&

          ts != null &&

          ts.difference(prevTs).inMinutes.abs() <= 3;

      if (prevAr.isEmpty &&

          prevUm.isNotEmpty &&

          sameSession &&

          rapid) {

        prev['userMessage'] = '$prevUm $um';

        if (ar.isNotEmpty) {

          prev['assistantResponse'] = ar;

        }

        final newTs = parseEntryTimestamp(entry);

        if (newTs != null) prev['timestamp'] = entry['timestamp'];

        continue;

      }

    }

    out.add(Map<String, dynamic>.from(entry));

  }

  return out;

}



List<Map<String, dynamic>> normalizeHistoryEntries(

  List<Map<String, dynamic>> entries,

) {

  final seenIds = <String>{};

  final out = <Map<String, dynamic>>[];

  for (final entry in entries) {

    final id = (entry['id'] as String? ?? '').trim();

    if (id.isNotEmpty) {

      if (seenIds.contains(id)) continue;

      seenIds.add(id);

    }

    final um = (entry['userMessage'] as String? ?? '').trim();

    final ar = (entry['assistantResponse'] as String? ?? '').trim();



    if (um.isEmpty && ar.isNotEmpty && out.isNotEmpty) {

      final prev = out.last;

      final prevUm = (prev['userMessage'] as String? ?? '').trim();

      final prevAr = (prev['assistantResponse'] as String? ?? '').trim();

      final sid = (entry['sessionId'] as String? ?? '').trim();

      final prevSid = (prev['sessionId'] as String? ?? '').trim();

      if (prevUm.isNotEmpty &&

          prevAr.isEmpty &&

          historySessionsMatch(prevSid, sid)) {

        prev['assistantResponse'] = entry['assistantResponse'];

        final prevTs = parseEntryTimestamp(prev);

        final newTs = parseEntryTimestamp(entry);

        if (newTs != null &&

            (prevTs == null || newTs.isAfter(prevTs))) {

          prev['timestamp'] = entry['timestamp'];

        }

        if (prevSid.startsWith('pending-') && !sid.startsWith('pending-')) {

          prev['sessionId'] = sid;

        }

        continue;

      }

    }



    if (um.isEmpty && ar.isEmpty) continue;

    final copy = Map<String, dynamic>.from(entry);

    final arRaw = (copy['assistantResponse'] as String? ?? '').trim();

    if (arRaw.isNotEmpty) {
      if (isGarbageAssistantText(arRaw)) {
        copy['assistantResponse'] = '';
        copy['_droppedGarbageAssistant'] = true;
      } else {
        copy['assistantResponse'] = sanitizeAssistantTextForDisplay(arRaw);
      }
    }

    out.add(copy);

  }

  out.sort((a, b) => _entrySortKey(a).compareTo(_entrySortKey(b)));

  final merged = _mergeRapidUserFragments(out);

  return merged

      .where((e) {

        final um = (e['userMessage'] as String? ?? '').trim();

        final ar = (e['assistantResponse'] as String? ?? '').trim();

        if (um.isEmpty && ar.isEmpty) {
          HistoryTraceLog.normalizeDrop('boş tur', e);
          return false;
        }

        // Cevapsız kırık sıra parçaları (PC'ye hiç gitmemiş) gösterme
        if (um.isNotEmpty && ar.isEmpty) {
          if (e['_droppedGarbageAssistant'] == true) {
            HistoryTraceLog.normalizeDrop(
              'çöp-json-asst-temizlendi user-kalır',
              e,
            );
            return true;
          }
          HistoryTraceLog.normalizeDrop('cevapsız-user', e);
          return false;
        }

        return true;

      })

      .toList();

}



/// Extension `get_chat_history` → sohbet balonları (eskiden yeniye).

List<ChatMessage> entriesToChatMessages(

  List<Map<String, dynamic>> entries, {

  DateTime? baseTime,

  bool alreadyNormalized = false,

}) {

  final out = <ChatMessage>[];

  var t = baseTime ?? DateTime.now();

  final ordered =
      alreadyNormalized ? entries : normalizeHistoryEntries(entries);

  for (var i = 0; i < ordered.length; i++) {

    final entry = ordered[i];

    final userMsg = (entry['userMessage'] as String? ?? '').trim();

    var assistantMsg =

        (entry['assistantResponse'] as String? ?? '').trim();

    final agentMode = entry['agentMode'] as String?;

    final entryAt = parseEntryTimestamp(entry) ?? t.add(Duration(milliseconds: i));



    final entryId = (entry['id'] as String? ?? 'i-$i').trim();

    if (userMsg.isNotEmpty) {

      out.add(

        ChatMessage(

          id: 'h-u-$entryId',

          role: ChatRole.user,

          text: userMsg,

          at: entryAt,

          kind: InboundKind.unknown,

          agentMode: agentMode,

        ),

      );

    }

    if (assistantMsg.isNotEmpty) {
      if (isGarbageAssistantText(assistantMsg)) {
        assistantMsg = '';
      }
    }

    if (assistantMsg.isNotEmpty) {
      final userId = userMsg.isNotEmpty ? 'h-u-$entryId' : null;
      out.add(

        ChatMessage(

          id: 'h-a-$entryId',

          role: ChatRole.assistant,

          text: assistantMsg,

          at: entryAt.add(const Duration(seconds: 1)),

          kind: InboundKind.chatResponse,

          replyToUserId: userId,

        ),

      );

    }

  }

  return out;

}



List<Map<String, dynamic>> parseHistoryEntriesFromCommandResult(

  Map<String, dynamic> data,

) {

  if (data['type'] != 'command_result') return [];

  if (data['command_type'] != 'get_chat_history') return [];

  if (data['success'] != true) return [];



  final raw = data['data'];

  if (raw is List) {

    return raw

        .map((e) => Map<String, dynamic>.from(e as Map))

        .toList();

  }

  if (raw is Map && raw['entries'] is List) {

    return List<Map<String, dynamic>>.from(

      (raw['entries'] as List).map((e) => Map<String, dynamic>.from(e as Map)),

    );

  }

  return [];

}



/// Geçmiş kayıtlarından oturum listesi (yeniden eskiye).

List<SessionSummary> extractSessionSummaries(

  List<Map<String, dynamic>> entries,

) {

  final grouped = <String, List<Map<String, dynamic>>>{};

  for (final entry in entries) {

    final userMsg = (entry['userMessage'] as String? ?? '').trim();

    if (userMsg.startsWith('__REMOTE_DELETE_SESSION__')) continue;

    final sid = (entry['sessionId'] as String? ?? '').trim();

    if (sid.isEmpty || sid.startsWith('pending-') || sid == 'unknown') continue;

    grouped.putIfAbsent(sid, () => []).add(entry);

  }



  final summaries = <SessionSummary>[];

  for (final e in grouped.entries) {

    final list = e.value;

    list.sort((a, b) => _entrySortKey(b).compareTo(_entrySortKey(a)));

    final latest = list.first;

    final user = (latest['userMessage'] as String? ?? '').trim();

    final assistant = (latest['assistantResponse'] as String? ?? '').trim();

    final preview = user.isNotEmpty

        ? user

        : assistant.isNotEmpty

            ? assistant

            : '(boş oturum)';

    final short = preview.length > 60 ? '${preview.substring(0, 60)}…' : preview;

    summaries.add(

      SessionSummary(

        sessionId: e.key,

        preview: short,

        lastTimestamp: latest['timestamp'] as String?,

        entryCount: list.length,

      ),

    );

  }



  summaries.sort((a, b) {

    final ta = a.lastTimestamp ?? '';

    final tb = b.lastTimestamp ?? '';

    return tb.compareTo(ta);

  });

  return summaries;

}



List<Map<String, dynamic>> filterEntriesBySession(

  List<Map<String, dynamic>> entries,

  String sessionId,

) {

  final sid = sessionId.trim();

  final filtered = entries

      .where((e) => (e['sessionId'] as String? ?? '').trim() == sid)

      .toList();

  filtered.sort((a, b) => _entrySortKey(a).compareTo(_entrySortKey(b)));

  return filtered;

}



int? parseDeletedCountFromCommandResult(Map<String, dynamic> data) {

  if (data['type'] != 'command_result') return null;

  final raw = data['data'];

  if (raw is! Map || !raw.containsKey('deletedCount')) return null;

  final c = raw['deletedCount'];

  if (c is num) return c.toInt();

  return null;

}



bool isDeleteSessionCommandResult(Map<String, dynamic> data) {

  if (data['type'] != 'command_result') return false;

  final cmd = data['command_type'] as String? ?? '';

  if (cmd == 'delete_session' || cmd == 'remove_session') return true;

  if (cmd == 'insert_text') {

    final n = parseDeletedCountFromCommandResult(data);

    return n != null && n > 0;

  }

  return false;

}



List<Map<String, dynamic>> parseSessionInfoFromCommandResult(

  Map<String, dynamic> data,

) {

  if (data['type'] != 'command_result') return [];

  if (data['command_type'] != 'get_session_info') return [];

  if (data['success'] != true) return [];

  final raw = data['data'];

  if (raw is Map<String, dynamic>) return [raw];

  return [];

}

/// Geçmiş yenilemesinde silinebilecek sohbet balonları.
bool isReplaceableConversationMessage(ChatMessage m) =>
    m.role == ChatRole.user ||
    m.role == ChatRole.assistant ||
    m.kind == InboundKind.chatResponseChunk;

/// PC geçmişi gelmeden önce gönderilen yerel tur (mobil userPrompt vb.).
List<ChatMessage> filterProtectedLocalMessages(
  List<ChatMessage> current, {
  required Set<String> anchorIds,
}) {
  final out = <ChatMessage>[];
  final seen = <String>{};

  void take(ChatMessage m) {
    if (seen.add(m.id)) out.add(m);
  }

  for (final m in current) {
    if (!isReplaceableConversationMessage(m)) continue;
    if (m.kind == InboundKind.userPrompt) {
      take(m);
      continue;
    }
    if (anchorIds.contains(m.id)) {
      take(m);
      continue;
    }
    if (m.isStreaming) {
      take(m);
      continue;
    }
    final replyTo = m.replyToUserId;
    if (replyTo != null && anchorIds.contains(replyTo)) {
      take(m);
    }
  }
  return out;
}

bool historyHasSimilarUserMessage(
  List<ChatMessage> imported,
  ChatMessage local,
) {
  final text = local.text.trim();
  if (text.isEmpty) return false;
  for (final m in imported) {
    if (m.role == ChatRole.user && userMessagesLikelySame(m.text, text)) {
      return true;
    }
  }
  return false;
}

/// h-u birleşince asistanın replyToUserId hedefini güncelle.
void rewireAssistantRepliesAfterUserIdChange(
  List<ChatMessage> list,
  String oldUserId,
  String newUserId,
) {
  if (oldUserId == newUserId) return;
  for (var i = 0; i < list.length; i++) {
    final m = list[i];
    if (m.role != ChatRole.assistant || m.replyToUserId != oldUserId) continue;
    list[i] = ChatMessage(
      id: m.id,
      role: m.role,
      text: m.text,
      at: m.at,
      kind: m.kind,
      agentMode: m.agentMode,
      isStreaming: m.isStreaming,
      replyToUserId: newUserId,
      sessionId: m.sessionId,
    );
  }
}

/// PC geçmişinde aynı tur iki kez (yerel + h-u-) gelmesin.
List<ChatMessage> dedupeEquivalentUserMessages(List<ChatMessage> messages) {
  final users = <ChatMessage>[];
  final others = <ChatMessage>[];
  for (final m in messages) {
    if (m.role == ChatRole.user) {
      users.add(m);
    } else {
      others.add(m);
    }
  }

  final canonicalUsers = <ChatMessage>[];
  final idRemap = <String, String>{};

  for (final m in users) {
    final dupIdx = canonicalUsers.indexWhere(
      (x) => userMessagesLikelySame(x.text, m.text),
    );
    if (dupIdx < 0) {
      canonicalUsers.add(m);
      continue;
    }
    final prev = canonicalUsers[dupIdx];
    final picked = pickPreferredUserBubble(prev, m);
    idRemap[prev.id] = picked.id;
    idRemap[m.id] = picked.id;
    canonicalUsers[dupIdx] = picked;
  }

  final out = <ChatMessage>[...canonicalUsers];
  for (final m in others) {
    var replyTo = m.replyToUserId;
    if (replyTo != null && idRemap.containsKey(replyTo)) {
      replyTo = idRemap[replyTo];
    }
    if (m.replyToUserId == replyTo) {
      out.add(m);
    } else {
      out.add(
        ChatMessage(
          id: m.id,
          role: m.role,
          text: m.text,
          at: m.at,
          kind: m.kind,
          agentMode: m.agentMode,
          isStreaming: m.isStreaming,
          replyToUserId: replyTo,
          sessionId: m.sessionId,
        ),
      );
    }
  }
  sortChatMessagesChronologically(out);
  return out;
}

/// PC geçmişi + henüz dosyaya düşmemiş yerel balonlar.
List<ChatMessage> mergeImportedWithProtected({
  required List<ChatMessage> imported,
  required List<ChatMessage> protected,
}) {
  final merged = List<ChatMessage>.from(imported);
  final ids = imported.map((m) => m.id).toSet();
  for (final m in protected) {
    if (ids.contains(m.id)) continue;
    if (m.role == ChatRole.user &&
        historyHasSimilarUserMessage(imported, m)) {
      continue;
    }
    merged.add(m);
    ids.add(m.id);
  }
  return merged;
}

/// Yerel balon + PC `h-u`/`h-a` birleşince çift soru/cevap kalmasın.
List<ChatMessage> consolidateSessionChatMessages(List<ChatMessage> messages) {
  var list = dedupeEquivalentUserMessages(List<ChatMessage>.from(messages));
  sortChatMessagesChronologically(list);

  final users = list.where((m) => m.role == ChatRole.user).toList();
  final removeIds = <String>{};

  ChatMessage? userById(String id) {
    for (final x in list) {
      if (x.id == id && x.role == ChatRole.user) return x;
    }
    return null;
  }

  for (final u in users) {
    final equivIds = <String>{
      for (final x in users)
        if (userMessagesLikelySame(x.text, u.text)) x.id,
    };

    final replies = <ChatMessage>[];
    final uIdx = list.indexWhere((m) => m.id == u.id);
    if (uIdx < 0) continue;

    DateTime? nextOtherUserAt;
    for (var j = uIdx + 1; j < list.length; j++) {
      final x = list[j];
      if (x.role == ChatRole.user &&
          !userMessagesLikelySame(x.text, u.text)) {
        nextOtherUserAt = x.at;
        break;
      }
    }

    for (final m in list) {
      if (m.role != ChatRole.assistant) continue;
      if (m.kind == InboundKind.chatResponseChunk) continue;
      final replyUid = m.replyToUserId;
      if (replyUid != null) {
        if (equivIds.contains(replyUid)) {
          replies.add(m);
          continue;
        }
        final replyUser = userById(replyUid);
        if (replyUser != null &&
            userMessagesLikelySame(replyUser.text, u.text)) {
          replies.add(m);
          continue;
        }
        continue;
      }
      if (m.at.isBefore(u.at)) continue;
      if (nextOtherUserAt != null && !m.at.isBefore(nextOtherUserAt)) {
        continue;
      }
      replies.add(m);
    }

    if (replies.length <= 1) continue;

    final byBody = <String, List<ChatMessage>>{};
    for (final a in replies) {
      final key = normalizedAssistantBody(a.text);
      if (key.isEmpty) continue;
      byBody.putIfAbsent(key, () => []).add(a);
    }

    for (final group in byBody.values) {
      if (group.length <= 1) continue;
      group.sort((a, b) {
        final aLocal = !a.id.startsWith('h-');
        final bLocal = !b.id.startsWith('h-');
        if (aLocal != bLocal) return aLocal ? -1 : 1;
        return b.text.trim().length.compareTo(a.text.trim().length);
      });
      for (var i = 1; i < group.length; i++) {
        removeIds.add(group[i].id);
      }
    }

    final survivors = replies.where((r) => !removeIds.contains(r.id)).toList()
      ..sort((a, b) => b.text.trim().length.compareTo(a.text.trim().length));
    if (survivors.length > 1) {
      final keep = survivors.first;
      final keepNorm = normalizedAssistantBody(keep.text);
      for (var i = 1; i < survivors.length; i++) {
        final o = survivors[i];
        final oNorm = normalizedAssistantBody(o.text);
        if (oNorm == keepNorm ||
            (keepNorm.length > 24 &&
                (keepNorm.contains(oNorm) || oNorm.contains(keepNorm)))) {
          removeIds.add(o.id);
        }
      }
    }
  }

  list.removeWhere((m) => removeIds.contains(m.id));
  return dedupeEquivalentUserMessages(list);
}

