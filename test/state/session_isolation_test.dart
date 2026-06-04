import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/session_isolation.dart';
import 'package:alper_cursor_remote/state/session_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strictFilterEntriesBySession yabancı sessionId atar', () {
    final entries = [
      {
        'sessionId': 'music-uuid',
        'userMessage': 'müzik path',
        'assistantResponse': 'müzik cevap',
      },
      {
        'sessionId': 'yuruk-uuid',
        'userMessage': 'yürük path',
        'assistantResponse': 'yürük cevap',
      },
    ];
    final music = strictFilterEntriesBySession(entries, 'music-uuid');
    expect(music.length, 1);
    expect(music.first['userMessage'], contains('müzik'));
  });

  test('sessionId boş geçmiş satırı içeri alınmaz', () {
    final entries = [
      {'userMessage': 'x', 'assistantResponse': 'y'},
    ];
    expect(strictFilterEntriesBySession(entries, 'any'), isEmpty);
  });

  test('strictMessagesForBucket başka oturum etiketini göstermez', () {
    final list = [
      ChatMessage(
        id: '1',
        role: ChatRole.user,
        text: 'müzik',
        at: DateTime(2026),
        sessionId: 'music-uuid',
      ),
      ChatMessage(
        id: '2',
        role: ChatRole.user,
        text: 'yürük',
        at: DateTime(2026),
        sessionId: 'yuruk-uuid',
      ),
    ];
    final onlyMusic = strictMessagesForBucket(list, 'music-uuid');
    expect(onlyMusic.length, 1);
    expect(onlyMusic.first.text, 'müzik');
  });

  test('loc- kutusunda yalnızca o oturum etiketi', () {
    final list = [
      ChatMessage(
        id: '1',
        role: ChatRole.user,
        text: 'müzik',
        at: DateTime(2026),
        sessionId: 'loc-music',
      ),
      ChatMessage(
        id: '2',
        role: ChatRole.user,
        text: 'yürük',
        at: DateTime(2026),
        sessionId: 'loc-yuruk',
      ),
    ];
    expect(strictMessagesForBucket(list, 'loc-yuruk').length, 1);
  });

  test('purgeForeignMessagesInBucket kutu temizler', () {
    final bucket = [
      ChatMessage(
        id: '1',
        role: ChatRole.user,
        text: 'a',
        at: DateTime(2026),
        sessionId: 'a-uuid',
      ),
      ChatMessage(
        id: '2',
        role: ChatRole.user,
        text: 'b',
        at: DateTime(2026),
        sessionId: 'b-uuid',
      ),
    ];
    expect(purgeForeignMessagesInBucket(bucket, 'a-uuid'), 1);
    expect(bucket.length, 1);
    expect(bucket.first.sessionId, 'a-uuid');
  });
}
