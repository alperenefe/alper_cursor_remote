import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/models/session_live_state.dart';
import 'package:alper_cursor_remote/state/inbound/inbound_session_resolver.dart';
import 'package:alper_cursor_remote/state/session_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sessionId varsa doğrudan kullanılır', () {
    expect(
      resolveInboundSessionId(
        map: {'sessionId': 'abc'},
        pcBusySessionKey: 'other',
        liveEntries: const [],
        cursorSessionId: 'ui',
      ),
      'abc',
    );
  });

  test('sessionId yoksa aktif UI değil pcBusy kullanılır', () {
    expect(
      resolveInboundSessionId(
        map: null,
        pcBusySessionKey: 'planner',
        liveEntries: const [],
        cursorSessionId: 'music',
      ),
      'planner',
    );
  });

  test('sessionId yoksa waiting oturum UI dan önce gelir', () {
    final reg = SessionRegistry();
    reg.liveFor('planner').waitingResponse = true;
    reg.liveFor('music');
    expect(
      resolveInboundSessionId(
        map: null,
        pcBusySessionKey: null,
        liveEntries: reg.liveEntries,
        cursorSessionId: 'music',
      ),
      'planner',
    );
  });

  test('asistan yolu: sessionId yoksa aktif UI kullanılmaz', () {
    final reg = SessionRegistry();
    reg.liveFor('music');
    expect(
      resolveInboundSessionId(
        map: null,
        pcBusySessionKey: null,
        liveEntries: reg.liveEntries,
        cursorSessionId: 'music',
        allowActiveUiFallback: false,
      ),
      '',
    );
  });

  test('inFlight oturum waiting den önce', () {
    final reg = SessionRegistry();
    reg.liveFor('a').inFlight = QueuedPrompt(
      text: 'x',
      agentMode: 'agent',
      queuedAt: DateTime(2026),
      localMessageId: 'm1',
      sessionId: 'a',
    );
    reg.liveFor('b').waitingResponse = true;
    expect(
      resolveInboundSessionId(
        map: null,
        pcBusySessionKey: null,
        liveEntries: reg.liveEntries,
        cursorSessionId: 'b',
      ),
      'a',
    );
  });
}
