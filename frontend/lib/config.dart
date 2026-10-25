/// App-wide settings. Change the backend address with
/// `--dart-define=API_BASE_URL=http://host:3000` when running or building.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const Duration requestTimeout = Duration(seconds: 20);
}
