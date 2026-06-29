import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  runApp(PlantexApp(config: config));
}
