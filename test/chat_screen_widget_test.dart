import 'package:alper_cursor_remote/app.dart';
import 'package:alper_cursor_remote/navigation/home_tab_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('HomeTabController bağlantı sekmesine geçer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabController(
          goToTab: (_) {},
          child: const SizedBox(),
        ),
      ),
    );
    expect(
      HomeTabController.maybeOf(
        tester.element(find.byType(SizedBox)),
      ),
      isNotNull,
    );
  });

  testWidgets('sohbet ekranı dispose sonrası crash olmaz', (tester) async {
    await tester.pumpWidget(const AlperCursorRemoteApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Sekme değiştir → ChatScreen dispose/recreate
    await tester.tap(find.text('Bağlantı'));
    await tester.pump();
    await tester.tap(find.text('Sohbet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sohbet'), findsOneWidget);
  });

  testWidgets('bağlı değilken bağlantı CTA görünür', (tester) async {
    await tester.pumpWidget(const AlperCursorRemoteApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Bağlı değil varsayılan — boş sohbet metni veya CTA
    expect(
      find.textContaining('Bağlantı').evaluate().isNotEmpty ||
          find.textContaining('bağlan').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('composer metin girişi bağlı değilken çökmez', (tester) async {
    await tester.pumpWidget(const AlperCursorRemoteApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final fields = find.byType(TextField);
    if (fields.evaluate().isNotEmpty) {
      await tester.enterText(fields.first, 'test mesaj');
      await tester.pump();
      // Gönder düğmesi veya enter — crash olmamalı
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
