import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/services/chat_history_applier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('command_result içinden entries çıkarılır', () {
    final entries = parseHistoryEntriesFromCommandResult({
      'type': 'command_result',
      'success': true,
      'command_type': 'get_chat_history',
      'data': [
        {
          'userMessage': 'selam',
          'assistantResponse': 'merhaba',
          'agentMode': 'agent',
        },
      ],
    });
    expect(entries.length, 1);
    final msgs = entriesToChatMessages(entries);
    expect(msgs.length, 2);
    expect(msgs.first.role, ChatRole.user);
    expect(msgs.last.role, ChatRole.assistant);
  });

  test('oturum listesi sessionId ile gruplanır', () {
    final summaries = extractSessionSummaries([
      {
        'sessionId': 'abc-111',
        'userMessage': 'ilk soru',
        'assistantResponse': 'cevap',
        'timestamp': '2026-05-19T10:00:00Z',
      },
      {
        'sessionId': 'abc-222',
        'userMessage': 'başka oturum',
        'timestamp': '2026-05-19T11:00:00Z',
      },
    ]);
    expect(summaries.length, 2);
    expect(summaries.first.sessionId, 'abc-222');
    expect(
      filterEntriesBySession(
        [
          {'sessionId': 'abc-111', 'userMessage': 'x'},
          {'sessionId': 'abc-222', 'userMessage': 'y'},
        ],
        'abc-111',
      ).length,
      1,
    );
  });

  test('delete_session deletedCount parse', () {
    expect(
      parseDeletedCountFromCommandResult({
        'type': 'command_result',
        'success': true,
        'command_type': 'delete_session',
        'data': {'deletedCount': 2, 'sessionId': 'abc'},
      }),
      2,
    );
    expect(
      parseDeletedCountFromCommandResult({
        'type': 'command_result',
        'success': false,
        'command_type': 'delete_session',
        'data': {'deletedCount': 0, 'sessionId': 'abc'},
      }),
      0,
    );
  });

  test('parçalı geçmiş birleştirilir', () {
    final merged = normalizeHistoryEntries([
      {
        'sessionId': 'sess-a',
        'userMessage': 'selamm nasılsın',
        'assistantResponse': '',
      },
      {
        'sessionId': 'sess-a',
        'userMessage': '',
        'assistantResponse': 'iyiyim',
      },
      {
        'sessionId': 'sess-a',
        'userMessage': 'weekly planner',
        'assistantResponse': 'tamam',
      },
    ]);
    expect(merged.length, 2);
    expect(merged.first['userMessage'], 'selamm nasılsın');
    expect(merged.first['assistantResponse'], 'iyiyim');
    final msgs = entriesToChatMessages([
      {
        'sessionId': 'sess-a',
        'userMessage': 'selamm',
        'assistantResponse': '',
      },
      {
        'sessionId': 'sess-a',
        'userMessage': '',
        'assistantResponse': 'cevap',
      },
    ]);
    expect(msgs.length, 2);
  });

  test('zaman sırasına göre sıralanır', () {
    final msgs = entriesToChatMessages([
      {
        'userMessage': 'son',
        'assistantResponse': 'c2',
        'timestamp': '2026-05-26T12:00:02Z',
      },
      {
        'userMessage': 'ilk',
        'assistantResponse': 'c1',
        'timestamp': '2026-05-26T12:00:01Z',
      },
    ]);
    expect(msgs[0].text, 'ilk');
    expect(msgs[2].text, 'son');
  });

  test('sıra tek harfleri birleştirilir', () {
    final merged = normalizeHistoryEntries([
      {
        'id': '1',
        'sessionId': 's1',
        'userMessage': 'a',
        'assistantResponse': '',
        'timestamp': '2026-05-26T13:00:00Z',
      },
      {
        'id': '2',
        'sessionId': 's1',
        'userMessage': 'l',
        'assistantResponse': '',
        'timestamp': '2026-05-26T13:00:01Z',
      },
      {
        'id': '3',
        'sessionId': 's1',
        'userMessage': 'p',
        'assistantResponse': 'birlesik cevap',
        'timestamp': '2026-05-26T13:00:02Z',
      },
    ]);
    expect(merged.length, 1);
    expect(merged.first['userMessage'], 'a l p');
    expect(merged.first['assistantResponse'], 'birlesik cevap');
  });

  test('ardışık benzer cevaplar da gösterilir', () {
    final body =
        '## Durum özeti\nFirebase dağıtım **başarısız**\n'
        '`FIREBASE_SERVICE_ACCOUNT_JSON` bozuk\nunexpected end of JSON input';
    final msgs = entriesToChatMessages([
      {
        'userMessage': 'noldu çıktın mı',
        'assistantResponse': body,
        'timestamp': '2026-05-26T12:00:01Z',
      },
      {
        'userMessage': 'baktın mı reis',
        'assistantResponse': '$body\nSecret düzelt.',
        'timestamp': '2026-05-26T12:00:02Z',
      },
    ]);
    expect(msgs.length, 4);
    final assistants =
        msgs.where((m) => m.role == ChatRole.assistant).map((m) => m.text).toList();
    expect(assistants.length, 2);
    expect(assistants.first, contains('Firebase'));
    expect(assistants.last, contains('Secret düzelt'));
  });

  test('aynı ekli tur PC+h-u çifti tek balona iner', () {
    const pc =
        "[Mobil ekler — workspace'e kaydedildi; gerekirse @ ile referans verin]\n"
        '- Görsel scaled_1000136441.jpg: @.cursor-remote-attachments/1780057076391/scaled_1000136441.jpg';
    const local = '📎 scaled_1000136441.jpg';
    final atLocal = DateTime(2026, 5, 28, 14, 30);
    final atPc = DateTime(2026, 5, 28, 15, 13);
    final merged = dedupeEquivalentUserMessages([
      ChatMessage(
        id: 'h-u-99',
        role: ChatRole.user,
        text: pc,
        at: atPc,
        kind: InboundKind.unknown,
      ),
      ChatMessage(
        id: 'local-99',
        role: ChatRole.user,
        text: local,
        at: atLocal,
        kind: InboundKind.userPrompt,
      ),
    ]);
    expect(merged.length, 1);
    expect(merged.single.id, 'local-99');
    expect(merged.single.text, local);
    expect(merged.single.at, atLocal);
  });

  test('geçmiş yenilemesinde yerel userPrompt korunur', () {
    final local = [
      ChatMessage(
        id: 'local-1',
        role: ChatRole.user,
        text: '[Mobil ekler] test',
        at: DateTime(2026, 5, 28, 12),
        kind: InboundKind.userPrompt,
      ),
    ];
    final protected = filterProtectedLocalMessages(
      local,
      anchorIds: {'local-1'},
    );
    expect(protected.length, 1);
    final merged = mergeImportedWithProtected(
      imported: const [],
      protected: protected,
    );
    expect(merged.length, 1);
    expect(merged.first.id, 'local-1');
  });

  test('farklı oturumlar pending ile birleşmez', () {
    final merged = normalizeHistoryEntries([
      {
        'sessionId': 'sess-music',
        'userMessage': 'müzik sorusu',
        'assistantResponse': 'müzik cevabı',
        'timestamp': '2026-05-29T08:00:00Z',
      },
      {
        'sessionId': 'pending-planner',
        'userMessage': '',
        'assistantResponse': 'planlayıcı cevabı',
        'timestamp': '2026-05-29T08:01:00Z',
      },
    ]);
    final music = filterEntriesBySession(merged, 'sess-music').single;
    expect(music['assistantResponse'], 'müzik cevabı');
    expect(
      filterEntriesBySession(merged, 'pending-planner').single['assistantResponse'],
      'planlayıcı cevabı',
    );
  });

  test('CLI JSON cevap balona dönmez', () {
    final msgs = entriesToChatMessages([
      {
        'sessionId': 's1',
        'userMessage': 'durum',
        'assistantResponse': '{"type":"system","subtype":"init"}',
      },
    ]);
    expect(msgs.length, 1);
    expect(msgs.first.role, ChatRole.user);
  });

  test('boş geçmiş', () {
    final entries = parseHistoryEntriesFromCommandResult({
      'type': 'command_result',
      'success': true,
      'command_type': 'get_chat_history',
      'data': [],
    });
    expect(entriesToChatMessages(entries), isEmpty);
  });

  test('consolidateSessionChatMessages yerel + PC tek tur', () {
    const q = 'müzik path nerede';
    final list = [
      ChatMessage(
        id: 'local-u',
        role: ChatRole.user,
        text: q,
        at: DateTime(2026, 5, 29, 10),
        kind: InboundKind.userPrompt,
      ),
      ChatMessage(
        id: 'local-a',
        role: ChatRole.assistant,
        text: 'müzik cevap',
        at: DateTime(2026, 5, 29, 10, 0, 30),
        kind: InboundKind.chatResponse,
        replyToUserId: 'local-u',
      ),
      ChatMessage(
        id: 'h-u-1',
        role: ChatRole.user,
        text: q,
        at: DateTime(2026, 5, 29, 10, 0, 1),
      ),
      ChatMessage(
        id: 'h-a-1',
        role: ChatRole.assistant,
        text: 'müzik cevap',
        at: DateTime(2026, 5, 29, 10, 0, 31),
        replyToUserId: 'h-u-1',
      ),
    ];
    final out = consolidateSessionChatMessages(list);
    expect(out.where((m) => m.role == ChatRole.user).length, 1);
    expect(out.where((m) => m.role == ChatRole.assistant).length, 1);
  });
}
