import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:alper_cursor_remote/models/prompt_attachment.dart';

void main() {
  test('toWireJson uses type and base64', () {
    final att = PromptAttachment(
      name: 'a.png',
      mimeType: 'image/png',
      base64: base64Encode([1, 2, 3]),
    );
    final json = att.toWireJson();
    expect(json['name'], 'a.png');
    expect(json['type'], 'image/png');
    expect(json['base64'], isNotEmpty);
  });

  test('formatUserMessageWithAttachments', () {
    final text = formatUserMessageWithAttachments('merhaba', [
      PromptAttachment(name: 'x.jpg', mimeType: 'image/jpeg', base64: ''),
    ]);
    expect(text, contains('📎'));
    expect(text, contains('merhaba'));
  });
}
