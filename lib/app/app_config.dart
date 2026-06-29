import 'flavor.dart';

/// Resolved runtime configuration, read from --dart-define values.
class AppConfig {
  AppConfig({required this.flavorConfig, required this.baseUrl});

  final FlavorConfig flavorConfig;
  final String baseUrl;

  AppFlavor get flavor => flavorConfig.flavor;

  /// Built once at startup from compile-time defines.
  factory AppConfig.fromEnvironment() {
    const rawFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'shipment');
    final flavor = FlavorConfig.parse(rawFlavor);
    final flavorConfig = FlavorConfig.of(flavor);

    // API_BASE_URL override lets you point at local/staging without rebuilding flavors.
    const overrideUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final baseUrl = overrideUrl.isNotEmpty ? overrideUrl : flavorConfig.defaultBaseUrl;

    return AppConfig(flavorConfig: flavorConfig, baseUrl: baseUrl);
  }

  /// Full mobile API root, e.g. https://plantex.work/api/v1/mobile
  String get apiBaseUrl => '$baseUrl/api/v1/mobile';
}
