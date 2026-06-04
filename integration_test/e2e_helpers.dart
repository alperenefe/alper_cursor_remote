import 'package:alper_cursor_remote/testing/e2e_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const kMusicName = 'müzik';
const kYurukName = 'yürük';
const kPlanName = 'plan';

/// Üç mesaj peş peşe; uzun bekleme yalnızca sondaki [waitForAgentPause].
const kMusicPrompt =
    '[E2E müzik] Kod değiştirmeden music_theory_trainer projesini tek cümleyle özetle.';
const kYurukPrompt =
    '[E2E yürük] Kod değiştirmeden yuruk projesini tek cümleyle özetle.';
const kPlanPrompt =
    '[E2E plan] Kod değiştirmeden weekly_planner projesini tek cümleyle özetle.';

/// Kısa pump — uzun bekleme yalnızca sondaki [waitForAgentPause].
Future<void> pumpFrames(
  WidgetTester tester, {
  Duration total = const Duration(milliseconds: 350),
  Duration step = const Duration(milliseconds: 50),
}) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
  }
}

Future<void> dismissDestructiveDialogs(WidgetTester tester) async {
  final clearAllTitle = find.text('Tüm geçmiş silinsin mi?');
  if (clearAllTitle.evaluate().isNotEmpty) {
    final vazgec = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Vazgeç'),
    );
    if (vazgec.evaluate().isNotEmpty) {
      await tester.tap(vazgec.first, warnIfMissed: false);
      await pumpFrames(tester);
    }
  }
  final deleteTitle = find.text('Oturumu sil?');
  if (deleteTitle.evaluate().isNotEmpty) {
    final vazgec = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Vazgeç'),
    );
    if (vazgec.evaluate().isNotEmpty) {
      await tester.tap(vazgec.first, warnIfMissed: false);
      await pumpFrames(tester);
    }
  }
}

/// Uygulama varsayılan olarak sohbet sekmesinde açılır — sekmeye tekrar basma.
Future<void> ensureOnChatScreen(WidgetTester tester) async {
  await dismissDestructiveDialogs(tester);
  await closeSheetIfOpen(tester);
  expect(
    find.byKey(E2eKeys.chatComposer),
    findsOneWidget,
    reason: 'Sohbet ekranında değil (composer yok)',
  );
}

Future<void> waitForConnected(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  await dismissDestructiveDialogs(tester);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(seconds: 1));
    final sessionsBtn = find.byKey(E2eKeys.openSessions);
    if (sessionsBtn.evaluate().isEmpty) continue;
    final widget = tester.widget<IconButton>(sessionsBtn);
    if (widget.onPressed != null) {
      await pumpFrames(tester);
      return;
    }
  }
  fail('PC bağlantısı yok — Bağlantı sekmesinde Bağlan veya otomatik bağlantıyı bekle.');
}

Future<void> closeSheetIfOpen(WidgetTester tester) async {
  await dismissDestructiveDialogs(tester);
  if (find.text('Oturumlar ve geçmiş').evaluate().isEmpty) return;

  final closeBtn = find.byKey(E2eKeys.closeSessionsSheet);
  if (closeBtn.evaluate().isNotEmpty) {
    await tester.tap(closeBtn, warnIfMissed: false);
  } else {
    final barriers = find.byType(ModalBarrier);
    if (barriers.evaluate().isNotEmpty) {
      await tester.tap(barriers.first, warnIfMissed: false);
    }
  }
  await pumpFrames(tester);
  expect(
    find.text('Tüm geçmiş silinsin mi?'),
    findsNothing,
    reason: 'Yanlışlıkla «tüm geçmişi sil» diyalogu açıldı',
  );
}

/// E2E başında bir kez PC geçmişi sıfırlanır (`RUN_E2E` + onay key).
/// Test sonunda oturum silinmez — yanlışlıkla «Hepsini sil» tetiklenmesin diye.
Future<void> clearPcHistoryAtStart(WidgetTester tester) async {
  await dismissDestructiveDialogs(tester);
  await openSessions(tester);
  final clearBtn = find.byKey(E2eKeys.clearAllHistory);
  expect(clearBtn, findsOneWidget, reason: 'RUN_E2E=true ile temizle butonu görünmeli');
  await tester.ensureVisible(clearBtn);
  await tester.tap(clearBtn, warnIfMissed: false);
  await pumpFrames(tester);
  expect(find.text('Tüm geçmiş silinsin mi?'), findsOneWidget);
  final confirm = find.byKey(E2eKeys.confirmClearAllHistory);
  expect(confirm, findsOneWidget);
  await tester.tap(confirm, warnIfMissed: false);
  await pumpFrames(tester, total: const Duration(seconds: 3));
  expect(
    find.textContaining('Kayıtlı oturum yok', findRichText: true),
    findsOneWidget,
    reason: 'PC geçmişi boşalmadı — extension Reload Window gerekebilir',
  );
  await closeSheetIfOpen(tester);
}

Future<void> openSessions(WidgetTester tester) async {
  await ensureOnChatScreen(tester);
  final btn = find.byKey(E2eKeys.openSessions);
  expect(btn, findsOneWidget);
  final iconBtn = tester.widget<IconButton>(btn);
  if (iconBtn.onPressed == null) {
    fail('Oturumlar butonu kapalı (connected=false).');
  }
  await tester.ensureVisible(btn);
  await tester.tap(btn, warnIfMissed: false);
  await pumpFrames(tester);
  expect(find.text('Oturumlar ve geçmiş'), findsOneWidget);
}

Future<void> openSessionFromList(WidgetTester tester, String sessionName) async {
  await openSessions(tester);
  final tile = find.byKey(E2eKeys.sessionTile(sessionName));
  expect(tile, findsOneWidget, reason: 'Listede "$sessionName" yok');
  await tester.ensureVisible(tile);
  await tester.tap(tile, warnIfMissed: false);
  await pumpFrames(tester, total: const Duration(milliseconds: 800));
  await closeSheetIfOpen(tester);
  await ensureOnChatScreen(tester);
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    if (find.text('Oturumlar ve geçmiş').evaluate().isNotEmpty) {
      await closeSheetIfOpen(tester);
    } else if (_activeSessionHeaderName(sessionName).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('Oturum seçilemedi (üst şerit): $sessionName');
}

Future<void> createNewSession(WidgetTester tester) async {
  await openSessions(tester);
  final newBtn = find.byKey(E2eKeys.newSession);
  expect(newBtn, findsOneWidget);
  await tester.ensureVisible(newBtn);
  await tester.tap(newBtn, warnIfMissed: false);
  await pumpFrames(tester);
  expect(
    find.text('Tüm geçmiş silinsin mi?'),
    findsNothing,
    reason: 'Yeni oturum yerine «tüm geçmişi sil» tetiklendi',
  );
  await closeSheetIfOpen(tester);
  await ensureOnChatScreen(tester);
}

/// Yeni oturum + isim + mesaj (plan dahil üçü de bu zincirden geçmeli).
Future<void> runE2eSession(
  WidgetTester tester, {
  required String stepLabel,
  required String sessionName,
  required String prompt,
  required String marker,
}) async {
  // ignore: avoid_print
  print('[E2E] === $stepLabel ===');
  await createNewSession(tester);
  await renameActiveSessionFromChat(tester, sessionName);
  await sendChatMessage(tester, prompt);
  await _assertMarkerOnlyInActiveChat(tester, marker);
  // ignore: avoid_print
  print('[E2E] === $stepLabel tamam ($marker) ===');
}

Future<void> _assertMarkerOnlyInActiveChat(
  WidgetTester tester,
  String marker,
) async {
  await ensureOnChatScreen(tester);
  final composer = find.byKey(E2eKeys.chatComposer);
  expect(
    _textInComposer(tester, composer, marker),
    isFalse,
    reason: 'Mesaj hâlâ kutuda (gönderilmemiş): $marker',
  );
  expect(
    find.textContaining(marker, findRichText: true),
    findsWidgets,
    reason: 'Sohbette kullanıcı balonu yok: $marker',
  );
}

/// 65 sn önce: üç oturum listede (balon kontrolü zaten runE2eSession'da yapıldı).
/// Listeden tekrar açınca geçmiş senkronu sohbeti boşaltabiliyor — balona tekrar bakma.
Future<void> assertAllE2eSessionsInList(WidgetTester tester) async {
  await openSessions(tester);
  for (final name in [kMusicName, kYurukName, kPlanName]) {
    expect(
      find.byKey(E2eKeys.sessionTile(name)),
      findsOneWidget,
      reason: 'Listede "$name" yok',
    );
  }
  await closeSheetIfOpen(tester);
  // ignore: avoid_print
  print('[E2E] Üç oturum listede (müzik/yürük/plan) — 65s beklemeye geçiliyor');
}

/// Sohbet üstündeki oturum şeridinden isim ver (liste açmaya gerek yok).
Future<void> renameActiveSessionFromChat(WidgetTester tester, String name) async {
  await ensureOnChatScreen(tester);
  // ignore: avoid_print
  print('[E2E] Oturum adı: $name');
  final renameBtn = find.byKey(E2eKeys.chatRename);
  expect(renameBtn, findsOneWidget, reason: 'Üst şeritte düzenle ikonu yok');
  final iconBtn = tester.widget<IconButton>(renameBtn);
  if (iconBtn.onPressed == null) {
    fail('Oturum adı düzenlenemiyor (canRenameActiveSession=false)');
  }
  await tester.ensureVisible(renameBtn);
  await tester.tap(renameBtn, warnIfMissed: false);
  await pumpFrames(tester);
  await tester.enterText(find.byKey(E2eKeys.renameField), name);
  await tester.tap(find.byKey(E2eKeys.renameSave), warnIfMissed: false);
  await pumpFrames(tester);
}

Future<void> selectSessionByName(WidgetTester tester, String name) async {
  await openSessions(tester);
  final byKey = find.byKey(E2eKeys.sessionTile(name));
  if (byKey.evaluate().isNotEmpty) {
    await tester.ensureVisible(byKey);
    await tester.tap(byKey, warnIfMissed: false);
  } else {
    await _tapSessionListText(tester, name);
  }
  await pumpFrames(tester, total: const Duration(seconds: 2));
  await closeSheetIfOpen(tester);
}

Future<void> selectSessionByMarker(
  WidgetTester tester,
  String marker, {
  String? sessionName,
}) async {
  await openSessions(tester);
  if (sessionName != null) {
    final byKey = find.byKey(E2eKeys.sessionTile(sessionName));
    if (byKey.evaluate().isNotEmpty) {
      await tester.ensureVisible(byKey);
      await tester.tap(byKey, warnIfMissed: false);
    } else {
      await _tapSessionListText(tester, sessionName);
    }
  } else {
    await _tapSessionListText(tester, marker);
  }
  await pumpFrames(tester, total: const Duration(seconds: 2));
  await closeSheetIfOpen(tester);
}

Future<void> _tapSessionListText(WidgetTester tester, String snippet) async {
  final inList = find.descendant(
    of: find.byType(ListView),
    matching: find.textContaining(snippet, findRichText: true),
  );
  expect(
    inList,
    findsWidgets,
    reason: 'Oturum listesinde "$snippet" yok (Yenile basma, E2E etiketi kaybolmuş olabilir)',
  );
  await tester.ensureVisible(inList.first);
  await tester.tap(inList.first, warnIfMissed: false);
}

bool _textInComposer(WidgetTester tester, Finder composer, String text) {
  return find
      .descendant(
        of: composer,
        matching: find.textContaining(text, findRichText: true),
      )
      .evaluate()
      .isNotEmpty;
}

bool _isInsideComposer(Element element, Finder composer) {
  final composerEls = composer.evaluate();
  var inside = false;
  element.visitAncestorElements((ancestor) {
    if (composerEls.contains(ancestor)) inside = true;
    return !inside;
  });
  return inside;
}

Finder _e2eUserBubbleKey(String marker) => find.byKey(Key('e2e_bubble_$marker'));

Future<void> _scrollChatToExposeMarker(
  WidgetTester tester,
  String marker,
) async {
  final bubble = _e2eUserBubbleKey(marker);
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  for (var i = 0; i < 12; i++) {
    if (bubble.evaluate().isNotEmpty) {
      await tester.ensureVisible(bubble);
      return;
    }
    await tester.drag(scrollable.first, const Offset(0, 280));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

bool _snippetVisibleInChat(
  WidgetTester tester,
  Finder composer,
  String snippet,
) {
  if (_e2eUserBubbleKey(snippet).evaluate().isNotEmpty) return true;
  final semantics = find.bySemanticsLabel(snippet, skipOffstage: false);
  if (semantics.evaluate().isNotEmpty) return true;
  final matches = find.textContaining(snippet, findRichText: true);
  for (final e in matches.evaluate()) {
    if (!_isInsideComposer(e, composer)) return true;
  }
  return false;
}

Finder _activeSessionHeaderName(String sessionName) {
  return find.descendant(
    of: find.ancestor(
      of: find.byKey(E2eKeys.chatRename),
      matching: find.byType(Row),
    ),
    matching: find.text(sessionName),
  );
}

/// Mesajı gönderir. «Gönderildi» yalnızca kutu boşalınca sayılır (yazılı metin balon değildir).
Future<void> sendChatMessage(WidgetTester tester, String text) async {
  await ensureOnChatScreen(tester);
  // ignore: avoid_print
  print('[E2E] Gönder: ${text.length > 48 ? '${text.substring(0, 48)}…' : text}');

  final composer = find.byKey(E2eKeys.chatComposer);
  await tester.ensureVisible(composer);
  await tester.tap(composer, warnIfMissed: false);
  await tester.enterText(composer, text);
  await tester.pump();
  expect(
    _textInComposer(tester, composer, text),
    isTrue,
    reason: 'Metin composer\'a yazılmadı',
  );

  final send = find.byKey(E2eKeys.sendMessage);
  await tester.ensureVisible(send);
  final sendInk = tester.widget<InkWell>(send);
  if (sendInk.onTap == null) {
    fail('Gönder butonu kapalı (onTap=null) — PC meşgul veya metin boş');
  }

  Object? lastError;
  for (var attempt = 1; attempt <= 4; attempt++) {
    // ignore: avoid_print
    print('[E2E] Gönder butonuna bas (deneme $attempt)');
    final rect = tester.getRect(send);
    await tester.tapAt(rect.center);
    await pumpFrames(tester, total: const Duration(milliseconds: 600));
    if (!_textInComposer(tester, composer, text)) {
      // ignore: avoid_print
      print('[E2E] Gönderildi ✓ buton tapAt (deneme $attempt)');
      return;
    }
    lastError = 'tapAt: metin hâlâ kutuda';
    await tester.tap(composer, warnIfMissed: false);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await pumpFrames(tester, total: const Duration(milliseconds: 600));
    if (!_textInComposer(tester, composer, text)) {
      // ignore: avoid_print
      print('[E2E] Gönderildi ✓ klavye Gönder (deneme $attempt)');
      return;
    }
    lastError = 'klavye: metin hâlâ kutuda';
    await tester.enterText(composer, text);
    await tester.pump();
  }
  fail('Gönderilemedi ($lastError): $text');
}

Future<void> expectChatContains(WidgetTester tester, String snippet) async {
  await pumpFrames(tester);
  expect(
    find.textContaining(snippet, findRichText: true),
    findsWidgets,
    reason: 'Sohbette "$snippet" görünmeli',
  );
}

Future<void> expectChatExcludes(WidgetTester tester, String snippet) async {
  expect(
    find.textContaining(snippet, findRichText: true),
    findsNothing,
    reason: 'Sohbette "$snippet" olmamalı',
  );
}

/// Agent PC'de çalışırken test bekler (`pump` ile; `pumpAndSettle` kullanma).
Future<void> waitForAgentPause(
  WidgetTester tester, {
  required Duration duration,
  String? label,
}) async {
  // ignore: avoid_print
  print('[E2E] ▶ Bekleme başladı ${duration.inSeconds}s — ${label ?? "agent"}');
  final end = DateTime.now().add(duration);
  var lastLog = DateTime.now();
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(seconds: 2));
    if (DateTime.now().difference(lastLog).inSeconds >= 10) {
      final left = end.difference(DateTime.now()).inSeconds;
      // ignore: avoid_print
      print('[E2E] … hâlâ bekleniyor (~${left}s kaldı)');
      lastLog = DateTime.now();
    }
  }
  // ignore: avoid_print
  print('[E2E] ■ Bekleme bitti — doğrulama başlıyor');
}

Future<void> expectChatContainsWithRetry(
  WidgetTester tester,
  String snippet, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final composer = find.byKey(E2eKeys.chatComposer);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (_snippetVisibleInChat(tester, composer, snippet)) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  fail('Sohbette "$snippet" görünmüyor (balon yok veya yalnızca kutuda)');
}

Future<void> expectChatExcludesMarkers(
  WidgetTester tester,
  List<String> markers,
) async {
  final composer = find.byKey(E2eKeys.chatComposer);
  for (final other in markers) {
    if (_textInComposer(tester, composer, other)) {
      fail('Yanlış oturum: $other composer kutusunda');
    }
    final hits = find.textContaining(other, findRichText: true);
    expect(
      hits,
      findsNothing,
      reason: 'Bu oturumda başka oturum etiketi görünmemeli: $other',
    );
  }
}

void _verifySessionListTile(
  WidgetTester tester,
  String sessionName,
  String marker,
  List<String> mustExcludeInPreview,
) {
  final tile = find.byKey(E2eKeys.sessionTile(sessionName));
  expect(tile, findsOneWidget, reason: 'Listede "$sessionName" yok');
  for (final other in mustExcludeInPreview) {
    expect(
      find.descendant(
        of: tile,
        matching: find.textContaining(other, findRichText: true),
      ),
      findsNothing,
      reason: '"$sessionName" listesinde $other olmamalı',
    );
  }
}

Future<void> verifySessionMessages(
  WidgetTester tester, {
  required String sessionName,
  required String marker,
  required List<String> mustExclude,
}) async {
  // ignore: avoid_print
  print('[E2E] Doğrula liste: $sessionName');
  await openSessions(tester);
  _verifySessionListTile(tester, sessionName, marker, mustExclude);
  await closeSheetIfOpen(tester);

  // ignore: avoid_print
  print('[E2E] Doğrula sohbet: $sessionName');
  await openSessionFromList(tester, sessionName);
  await _scrollChatToExposeMarker(tester, marker);
  await expectChatContainsWithRetry(
    tester,
    marker,
    timeout: const Duration(seconds: 45),
  );
  await expectChatExcludesMarkers(tester, mustExclude);
  // ignore: avoid_print
  print('[E2E] Doğrula OK: $sessionName (liste + sohbet)');
}

/// 65 sn sonra: üç oturum listesi + her oturumda mesaj izolasyonu.
Future<void> verifyAllE2eAtEnd(WidgetTester tester) async {
  // ignore: avoid_print
  print('[E2E] ========== SON DOĞRULAMA ==========');
  await verifySessionMessages(
    tester,
    sessionName: kMusicName,
    marker: '[E2E müzik]',
    mustExclude: ['[E2E yürük]', '[E2E plan]'],
  );
  await verifySessionMessages(
    tester,
    sessionName: kYurukName,
    marker: '[E2E yürük]',
    mustExclude: ['[E2E müzik]', '[E2E plan]'],
  );
  await verifySessionMessages(
    tester,
    sessionName: kPlanName,
    marker: '[E2E plan]',
    mustExclude: ['[E2E müzik]', '[E2E yürük]'],
  );
  // ignore: avoid_print
  print('[E2E] ========== SON DOĞRULAMA TAMAM ==========');
}

