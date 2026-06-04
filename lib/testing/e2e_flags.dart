/// `flutter test ... --dart-define=RUN_E2E=true` ile açılır.
abstract final class E2eFlags {
  static const enabled = bool.fromEnvironment('RUN_E2E');
}
