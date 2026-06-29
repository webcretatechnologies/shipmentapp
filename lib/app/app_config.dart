/// Runtime configuration. One app, one backend — the role is decided at login,
/// not here. Override the host for local/staging with:
///   --dart-define=API_BASE_URL=http://10.0.2.2:8000
class AppConfig {
  AppConfig({required this.baseUrl});

  final String baseUrl;

  factory AppConfig.fromEnvironment() {
    const override = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return AppConfig(baseUrl: override.isNotEmpty ? override : 'https://plantex.work');
  }

  /// Full mobile API root, e.g. https://plantex.work/api/v1/mobile
  String get apiBaseUrl => '$baseUrl/api/v1/mobile';
}
