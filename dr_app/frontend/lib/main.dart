import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  runApp(const DrishtiApp());
}

class DrishtiApp extends StatelessWidget {
  const DrishtiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = SettingsService.instance.themeMode;
    final baseTheme = AppTheme.lightTheme;
    return MaterialApp(
      title: 'Drishti',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainShell(),
    );
  }
}
