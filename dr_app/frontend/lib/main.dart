import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() {
  runApp(const DrishtiApp());
}

class DrishtiApp extends StatelessWidget {
  const DrishtiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drishti',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const DashboardScreen(),
    );
  }
}