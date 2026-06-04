import 'package:flutter_test/flutter_test.dart';

import 'package:alper_cursor_remote/services/ws_logger.dart';

void main() {
  test('logName sabit', () {
    expect(WsLogger.logName, 'CursorUzaktan');
  });
}
