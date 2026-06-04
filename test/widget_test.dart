import 'package:alper_cursor_remote/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uygulama açılır', (tester) async {
    await tester.pumpWidget(const AlperCursorRemoteApp());
    expect(find.text('Sohbet'), findsOneWidget);
  });
}
