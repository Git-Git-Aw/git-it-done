/// App-wide settings. Change the backend address with
/// `--dart-define=API_BASE_URL=http://host:3000` when running or building.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const Duration requestTimeout = Duration(seconds: 20);

  /// The AI Dorm Manager can take a long time to answer (about 20 seconds for
  /// a monthly summary). The backend gives up after 60 seconds, so the app
  /// waits a little longer than that.
  static const Duration aiRequestTimeout = Duration(seconds: 70);
}

