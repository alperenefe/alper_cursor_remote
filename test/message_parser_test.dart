import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/services/message_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat_response metni çıkarılır', () {
    final p = parseInboundJson(
      '{"type":"chat_response","text":"Merhaba","clientId":"c1"}',
    );
    expect(p.chatLines.length, 1);
    expect(p.chatLines.first.text, 'Merhaba');
    expect(p.kind, InboundKind.chatResponse);
  });

  test('log varsayılan sohbette gizli kategori', () {
    final p = parseInboundJson(
      '{"type":"log","level":"info","message":"test"}',
    );
    expect(p.chatLines.first.role, ChatRole.log);
    expect(shouldShowInChatByDefault(p.kind), isFalse);
  });
}
