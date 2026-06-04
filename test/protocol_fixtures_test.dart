import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/services/message_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// cursor-remote extension çıktılarına göre sabit örnekler (cli-handler / websocket-server).
void main() {
  group('extension → mobil parse', () {
    test('connected (websocket-server)', () {
      final p = parseInboundJson(
        '{"type":"connected","message":"Connected to Cursor Remote"}',
      );
      expect(p.systemLine, contains('Connected'));
    });

    test('chat_response (cli-handler final)', () {
      final p = parseInboundJson(
        '{"type":"chat_response","text":"Merhaba dünya","source":"cli",'
        '"sessionId":"sess-1","clientId":"client-abc"}',
      );
      expect(p.chatLines.single.text, 'Merhaba dünya');
      expect(p.kind, InboundKind.chatResponse);
    });

    test('chat_response_complete boş metin — balon eklenmez', () {
      final p = parseInboundJson(
        '{"type":"chat_response_complete","clientId":"c1"}',
      );
      expect(p.chatLines, isEmpty);
    });

    test('chat_response_chunk fullText (birleştirme)', () {
      final p = parseInboundJson(
        '{"type":"chat_response_chunk","text":"ab","fullText":"abc",'
        '"clientId":"c1","isReplace":false}',
      );
      expect(p.chatLines.single.text, 'abc');
    });

    test('log extension', () {
      final p = parseInboundJson(
        '{"type":"log","level":"info","message":"CLI started","source":"extension"}',
      );
      expect(p.chatLines.single.role, ChatRole.log);
      expect(shouldShowInChatByDefault(p.kind), isFalse);
    });

    test('agent_mode_selected (auto)', () {
      final p = parseInboundJson(
        '{"type":"agent_mode_selected","requestedMode":"auto",'
        '"actualMode":"agent","displayName":"Agent"}',
      );
      expect(p.systemLine, contains('Otomatik'));
      expect(p.systemLine, contains('Agent'));
    });

    test('command_result get_chat_history gizli', () {
      final p = parseInboundJson(
        '{"type":"command_result","success":true,"command_type":"get_chat_history",'
        '"data":[]}',
      );
      expect(p.chatLines, isEmpty);
      expect(p.systemLine, isNull);
    });

    test('command_result hata görünür (sistem açıkken)', () {
      final p = parseInboundJson(
        '{"type":"command_result","success":false,"command_type":"insert_text",'
        '"error":"fail"}',
      );
      expect(p.systemLine, contains('insert_text'));
    });

    test('connection_status disconnected', () {
      final p = parseInboundJson(
        '{"type":"connection_status","status":"disconnected",'
        '"message":"WebSocket server not running"}',
      );
      expect(p.systemLine, contains('disconnected'));
    });
  });
}
