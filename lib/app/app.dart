import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_controller.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_theme.dart';
import 'app_config.dart';
import 'router.dart';

/// Root widget. Wires DI (Provider), restores the session, builds the router.
class PlantexApp extends StatefulWidget {
  const PlantexApp({super.key, required this.config});
  final AppConfig config;

  @override
  State<PlantexApp> createState() => _PlantexAppState();
}

class _PlantexAppState extends State<PlantexApp> {
  late final ApiClient _api;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    final tokenStorage = TokenStorage();
    _api = ApiClient(baseUrl: widget.config.apiBaseUrl, tokenStorage: tokenStorage);
    _auth = AuthController(api: _api, tokenStorage: tokenStorage);
    _auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: widget.config),
        Provider<ApiClient>.value(value: _api),
        ChangeNotifierProvider<AuthController>.value(value: _auth),
      ],
      child: Builder(
        builder: (context) {
          final router = buildRouter(_auth);
          return MaterialApp.router(
            title: widget.config.flavorConfig.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(widget.config.flavorConfig.accent),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
