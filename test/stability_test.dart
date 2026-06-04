import 'dart:convert';

import 'package:alper_cursor_remote/models/prompt_attachment.dart';
import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/services/attachment_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromptAttachment güvenliği', () {
    test('geçersiz base64 byteLength 0 döner', () {
      const att = PromptAttachment(
        name: 'x.bin',
        mimeType: 'application/octet-stream',
        base64: '!!!not-base64!!!',
      );
      expect(att.byteLength, 0);
    });

    test('toWireJson roundtrip', () {
      final raw = base64Encode(List.filled(100, 42));
      final att = PromptAttachment(
        name: 'a.bin',
        mimeType: 'application/octet-stream',
        base64: raw,
      );
      final restored = PromptAttachment.fromWireJson(att.toWireJson());
      expect(restored.name, 'a.bin');
      expect(restored.byteLength, 100);
    });

    test('sadece ek ile format metin', () {
      final text = formatUserMessageWithAttachments('', [
        PromptAttachment(name: 'f.jpg', mimeType: 'image/jpeg', base64: ''),
      ]);
      expect(text, contains('📎'));
      expect(text, isNot(contains('\n\n\n')));
    });
  });

  group('AttachmentPickerService sınırları', () {
    test('max dosya sayısı aşılınca exception', () {
      final current = List.generate(
        PromptAttachment.maxFiles,
        (i) => PromptAttachment(
          name: '$i.txt',
          mimeType: 'text/plain',
          base64: base64Encode([1]),
        ),
      );
      expect(
        () => AttachmentPickerService.ensureCanAdd(
          current,
          [
            PromptAttachment(
              name: 'extra.txt',
              mimeType: 'text/plain',
              base64: base64Encode([2]),
            ),
          ],
        ),
        throwsA(isA<AttachmentPickException>()),
      );
    });

    test('boş incoming izin verilir', () {
      expect(
        () => AttachmentPickerService.ensureCanAdd([], []),
        returnsNormally,
      );
    });
  });

  group('QueuedPrompt ekler', () {
    test('attachments listesi korunur', () {
      final q = QueuedPrompt(
        text: '',
        agentMode: 'agent',
        queuedAt: DateTime(2026),
        localMessageId: 'm1',
        attachments: [
          PromptAttachment(
            name: 'p.png',
            mimeType: 'image/png',
            base64: base64Encode([0, 1]),
          ),
        ],
      );
      expect(q.attachments, hasLength(1));
      expect(q.attachments.first.name, 'p.png');
    });
  });
}
