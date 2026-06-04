import 'package:alper_cursor_remote/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_helpers.dart';

bool _benignE2eFlutterError(FlutterErrorDetails details) {
  final text = details.exceptionAsString();
  if (text.contains('overflowed')) return true;
  if (text.contains('deactivated widget')) return true;
  return false;
}

/// 3 oturum peş peşe; agent cevapları için sonda tek bekleme.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const runE2e = bool.fromEnvironment('RUN_E2E');

  if (runE2e) {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_benignE2eFlutterError(details)) return;
      prior?.call(details);
    };
  }

  if (!runE2e) {
    test('E2E atlandı', () {}, skip: true);
    return;
  }

  testWidgets(
    '3 oturum: peş peşe gönder, çakışan cevaplar, doğrula',
    (tester) async {
      app.main();
      await pumpFrames(tester, total: const Duration(seconds: 2));
      await waitForConnected(tester);
      await clearPcHistoryAtStart(tester);

      try {
        await runE2eSession(
          tester,
          stepLabel: '1/3 müzik',
          sessionName: kMusicName,
          prompt: kMusicPrompt,
          marker: '[E2E müzik]',
        );
        await runE2eSession(
          tester,
          stepLabel: '2/3 yürük',
          sessionName: kYurukName,
          prompt: kYurukPrompt,
          marker: '[E2E yürük]',
        );
        await runE2eSession(
          tester,
          stepLabel: '3/3 plan',
          sessionName: kPlanName,
          prompt: kPlanPrompt,
          marker: '[E2E plan]',
        );

        await assertAllE2eSessionsInList(tester);

        await waitForAgentPause(
          tester,
          duration: const Duration(seconds: 65),
          label: 'üç oturum agent cevapları',
        );

        await verifyAllE2eAtEnd(tester);
      } finally {
        await dismissDestructiveDialogs(tester);
        await closeSheetIfOpen(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
