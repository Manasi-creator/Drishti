import 'package:flutter/material.dart';

import 'dashboard/dashboard_screen.dart';
import 'patients/patients_screen.dart';
import 'reports/reports_screen.dart';
import 'screening/screenings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedIndex = 0;

  final List<String> titles = [
    'Dashboard',
    'Patients',
    'Screenings',
    'Reports',
    'Settings',
  ];

  void changePage(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Widget _buildContent() {
    switch (selectedIndex) {
      case 0:
        return const DashboardScreen();

      case 1:
        return const PatientsScreen();

      case 2:
        return const ScreeningsScreen();

      case 3:
        return const ReportsScreen();

      case 4:
        return const Center(
          child: Text('Settings', style: TextStyle(fontSize: 28)),
        );

      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 230,
      color: const Color(0xFF123B4A),
      child: Column(
        children: [
          const SizedBox(height: 35),

          const Text(
            'DRISHTI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'AI RETINAL SCREENING',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 45),

          _sidebarItem(Icons.dashboard_outlined, 'Dashboard', 0),

          _sidebarItem(Icons.people_outline, 'Patients', 1),

          _sidebarItem(Icons.remove_red_eye_outlined, 'Screenings', 2),

          _sidebarItem(Icons.description_outlined, 'Reports', 3),

          const Spacer(),

          _sidebarItem(Icons.settings_outlined, 'Settings', 4),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, int index) {
    final selected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: selected ? Colors.white : Colors.white70),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => changePage(index),
      ),
    );
  }
}
