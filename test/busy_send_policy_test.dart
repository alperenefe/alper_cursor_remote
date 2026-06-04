import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('busy send policy string roundtrip', () {
    expect(
      busySendPolicyFromString('interrupt'),
      BusySendPolicy.interrupt,
    );
    expect(busySendPolicyFromString('queue'), BusySendPolicy.queue);
    expect(busySendPolicyFromString(null), BusySendPolicy.queue);
    expect(
      busySendPolicyToString(BusySendPolicy.interrupt),
      'interrupt',
    );
  });
}
