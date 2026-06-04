import 'package:alper_cursor_remote/services/chat_bubble_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mobil ekler bloğu sadeleştirilir', () {
    const raw = '''
[Mobil ekler — workspace'e kaydedildi; gerekirse @ ile referans verin]
- Görsel foto.jpg: @.cursor-remote-attachments/123/foto.jpg

durum nedir''';
    expect(
      formatUserBubbleForDisplay(raw),
      '📎 foto.jpg\n\ndurum nedir',
    );
  });

  test('Mobil ekler — yalnız görsel, plan geçmişi', () {
    const raw = '''[Mobil ekler — workspace'e kaydedildi; gerekirse @ ile referans verin]
- Görsel scaled_1000136435.jpg: @.cursor-remote-attachments/1780056590514/scaled_1000136435.jpg''';
    expect(formatUserBubbleForDisplay(raw), '📎 scaled_1000136435.jpg');
    expect(formatAssistantBubbleForDisplay(raw), '📎 scaled_1000136435.jpg');
  });

  test('Mobil uzaktan sarmalayıcı kullanıcı metninden çıkar', () {
    const raw = '''merhaba

[Mobil uzaktan] Devam oturumu. Türkçe yanıt;
<!--/mobile-remote-->''';
    expect(formatUserBubbleForDisplay(raw), 'merhaba');
  });

  test('uzun agent metni daraltma eşiği', () {
    expect(assistantBubbleNeedsCollapse('kısa'), false);
    expect(assistantBubbleNeedsCollapse('x' * 1500), true);
  });
}
