import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/state/session_registry.dart';
import 'package:alper_cursor_remote/state/sync/foreground_sync_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bekleyen oturum hedefe girer', () {
    final reg = SessionRegistry();
    reg.liveFor('a').waitingResponse = true;
    expect(
      collectForegroundHistorySyncTargets(
        registry: reg,
        activeLocalId: 'b',
      ),
      {'a'},
    );
  });

  test('kuyruklu oturum hedefe girer', () {
    final reg = SessionRegistry();
    reg.liveFor('q').queue.add(
          QueuedPrompt(
            text: 'x',
            agentMode: 'agent',
            queuedAt: DateTime.now(),
            localMessageId: 'm1',
          ),
        );
    expect(
      collectForegroundHistorySyncTargets(registry: reg, activeLocalId: 'z'),
      {'q'},
    );
  });

  test('aktif oturumda cevapsız son kullanıcı turu hedefe girer', () {
    final reg = SessionRegistry();
    reg.messagesFor('active').add(
          ChatMessage(
            id: 'u1',
            role: ChatRole.user,
            text: 'selam',
            at: DateTime.now(),
          ),
        );
    expect(
      collectForegroundHistorySyncTargets(
        registry: reg,
        activeLocalId: 'active',
      ),
      {'active'},
    );
  });
}
