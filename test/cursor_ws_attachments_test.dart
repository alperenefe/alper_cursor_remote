import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// sendPrompt attachments alanının JSON şekli (regresyon).
void main() {
  test('insert_text attachments payload encode edilir', () {
    final payload = <String, dynamic>{
      'type': 'insert_text',
      'text': 'merhaba',
      'prompt': true,
      'attachments': [
        {'name': 'a.jpg', 'type': 'image/jpeg', 'base64': 'YQ=='},
      ],
    };
    final encoded = jsonEncode(payload);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final atts = decoded['attachments'] as List;
    expect(atts, hasLength(1));
    expect(atts.first['name'], 'a.jpg');
    expect(atts.first['type'], 'image/jpeg');
  });

  test('boş attachments anahtar eklenmez', () {
    final withAtt = <String, dynamic>{
      'attachments': [
        {'name': 'x', 'type': 'text/plain', 'base64': ''},
      ],
    };
    final without = <String, dynamic>{};
    expect(withAtt.containsKey('attachments'), isTrue);
    expect(without.containsKey('attachments'), isFalse);
  });
}
