import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalPatients = 0;
  int totalScreenings = 0;
  int referableCases = 0;

  List<dynamic> screenings = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final patients = await ApiService.getPatients();
      final screeningData = await ApiService.getScreenings();

      int referable = 0;

      for (final screening in screeningData) {
        final value = screening['referable'];

        if (value == 1 || value == true) {
          referable++;
        }
      }

      if (!mounted) return;

      setState(() {
        totalPatients = patients.length;
        totalScreenings = screeningData.length;
        referableCases = referable;
        screenings = screeningData;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : error != null
                          ? Center(
                              child: Text(
                                'Failed to load dashboard\n$error',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _buildDashboard(),
                ),
              ],
            ),
          ),
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

          _sidebarItem(
            Icons.dashboard_outlined,
            'Dashboard',
            true,
          ),

          _sidebarItem(
            Icons.people_outline,
            'Patients',
            false,
          ),

          _sidebarItem(
            Icons.remove_red_eye_outlined,
            'Screenings',
            false,
          ),

          _sidebarItem(
            Icons.description_outlined,
            'Reports',
            false,
          ),

          const Spacer(),

          _sidebarItem(
            Icons.settings_outlined,
            'Settings',
            false,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String title,
    bool selected,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? Colors.white : Colors.white70,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17202A),
            ),
          ),

          const Spacer(),

          IconButton(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),

          const SizedBox(width: 10),

          const CircleAvatar(
            radius: 19,
            child: Icon(Icons.person_outline),
          ),

          const SizedBox(width: 10),

          const Text(
            'Doctor',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Good afternoon, Doctor',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Here is an overview of your retinal screening activity.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Total Patients',
                  totalPatients.toString(),
                  Icons.people_outline,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _statCard(
                  'Total Screenings',
                  totalScreenings.toString(),
                  Icons.remove_red_eye_outlined,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _statCard(
                  'Referable Cases',
                  referableCases.toString(),
                  Icons.warning_amber_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          const Text(
            'Recent Screening Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          _buildScreeningTable(),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF176B87),
            ),
          ),

          const SizedBox(width: 15),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningTable() {
    if (screenings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: const Center(
          child: Text(
            'No screenings available yet.',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          for (final screening in screenings.take(10))
            _screeningRow(screening),
        ],
      ),
    );
  }

  Widget _screeningRow(Map<String, dynamic> screening) {
    final patientName =
        screening['patient_name'] ?? 'Unknown Patient';

    final grade =
        screening['dr_grade_label'] ?? 'Unknown';

    final confidence =
        screening['confidence'];

    final referable =
        screening['referable'] == 1 ||
        screening['referable'] == true;

    final confidenceText = confidence is num
        ? '${(confidence * 100).toStringAsFixed(1)}%'
        : '--';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      leading: const CircleAvatar(
        child: Icon(Icons.remove_red_eye_outlined),
      ),
      title: Text(
        patientName.toString(),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '$grade  •  Confidence: $confidenceText',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: referable
              ? Colors.orange.withValues(alpha: 0.12)
              : Colors.green.withValues(alpha: 0.12),
        ),
        child: Text(
          referable ? 'Referable' : 'Non-referable',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: referable
                ? Colors.orange.shade800
                : Colors.green.shade800,
          ),
        ),
      ),
    );
  }
}