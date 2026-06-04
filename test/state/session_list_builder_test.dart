import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/session_summary.dart';
import 'package:alper_cursor_remote/state/sessions/session_list_builder.dart';
import 'package:alper_cursor_remote/state/sessions/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('üç PC oturumu listeye ayrı ayrı girer (resolve birleştirmez)', () {
    final store = SessionStore();
    const locMusic = 'loc-music';
    const locYuruk = 'loc-yuruk';
    const locPlanner = 'loc-planner';
    const pcMusic = 'pc-uuid-music';
    const pcYuruk = 'pc-uuid-yuruk';
    const pcPlanner = 'pc-uuid-planner';

    store.linkPcSession(locMusic, pcMusic);
    store.linkPcSession(locYuruk, pcYuruk);
    store.linkPcSession(locPlanner, pcPlanner);

    store.of(locMusic).messages.add(
          ChatMessage(
            id: 'm1',
            role: ChatRole.user,
            text: 'müzik path',
            at: DateTime(2026, 5, 29, 10),
            sessionId: locMusic,
          ),
        );

    final history = [
      {
        'sessionId': pcMusic,
        'userMessage': 'müzik path',
        'timestamp': '2026-05-29T10:00:00Z',
      },
      {
        'sessionId': pcYuruk,
        'userMessage': 'yürük path',
        'timestamp': '2026-05-29T11:00:00Z',
      },
      {
        'sessionId': pcPlanner,
        'userMessage': 'planner path',
        'timestamp': '2026-05-29T12:00:00Z',
      },
    ];

    final list = buildSessionSummaries(
      store: store,
      sessionNames: {
        locMusic: 'Müzik',
        locYuruk: 'Yürük',
        locPlanner: 'Planner',
      },
      historyEntries: history,
      registryKeys: store.localIds,
      cursorSessionId: locMusic,
      summaryFromLocalChat: (_) => null,
    );

    final titles = list.map((s) => s.title).toSet();
    expect(titles, contains('Müzik'));
    expect(titles, contains('Yürük'));
    expect(titles, contains('Planner'));
    expect(list.length, greaterThanOrEqualTo(3));
  });

  test('isListSessionActive loc ile PC uuid eşleşir', () {
    final store = SessionStore();
    const loc = 'loc-m';
    const pc = 'pc-m';
    store.linkPcSession(loc, pc);
    expect(isListSessionActive(store, loc, loc), isTrue);
    expect(isListSessionActive(store, pc, loc), isTrue);
    expect(isListSessionActive(store, 'loc-other', loc), isFalse);
  });
}
