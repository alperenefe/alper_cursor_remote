import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/chat/chat_message_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('yerel ekli balon PC kısa metnine göre zengin sayılır', () {
    final local = ChatMessage(
      id: 'local',
      role: ChatRole.user,
      text: '📎 scaled_1000136359.jpg, scaled_1000136361.jpg\n\nreis son mesaj',
      at: DateTime(2026),
      kind: InboundKind.userPrompt,
    );
    final pc = ChatMessage(
      id: 'h-u-1',
      role: ChatRole.user,
      text: 'reis son mesaj',
      at: DateTime(2026),
    );
    expect(localUserBubbleIsRicher(local, pc), isTrue);
  });

  test('aynı dosya adı farklı saat — aynı tur', () {
    const local = '📎 scaled_1000136441.jpg\n\nplanla';
    const pc =
        "[Mobil ekler — workspace'e kaydedildi]\n"
        '- Görsel scaled_1000136441.jpg: @.cursor-remote-attachments/x/f.jpg\n\n'
        'planla';
    expect(userMessagesLikelySame(local, pc), isTrue);
  });

  test('📎 dosya adları PC workspace metniyle eşleşir', () {
    const local = '📎 scaled_1000136359.jpg, scaled_1000136361.jpg';
    const pc =
        '[Mobil ekler — workspace\'e kaydedildi]\n'
        '- Görsel scaled_1000136359.jpg: @.cursor-remote-attachments/x/a.jpg\n'
        '- Görsel scaled_1000136361.jpg: @.cursor-remote-attachments/x/b.jpg';
    expect(userMessagesLikelySame(local, pc), isTrue);
  });

  test('PC geçmişi h-u yerine yerel balon seçilir', () {
    const pc =
        "[Mobil ekler — workspace'e kaydedildi]\n"
        '- Görsel scaled_1000136441.jpg: @.cursor-remote-attachments/x/f.jpg';
    const local = '📎 scaled_1000136441.jpg';
    final picked = pickPreferredUserBubble(
      ChatMessage(
        id: 'h-u-1',
        role: ChatRole.user,
        text: pc,
        at: DateTime(2026, 5, 28, 15, 13),
      ),
      ChatMessage(
        id: 'local-1',
        role: ChatRole.user,
        text: local,
        at: DateTime(2026, 5, 28, 14, 30),
        kind: InboundKind.userPrompt,
      ),
    );
    expect(picked.id, 'local-1');
    expect(picked.text, local);
  });
}
