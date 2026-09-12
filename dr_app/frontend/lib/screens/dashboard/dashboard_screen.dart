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
    return Column(
      children: [
        _buildTopBar(),

        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
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
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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

          const CircleAvatar(radius: 19, child: Icon(Icons.person_outline)),

          const SizedBox(width: 10),

          const Text('Doctor', style: TextStyle(fontWeight: FontWeight.w600)),
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
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'Here is an overview of your retinal screening activity.',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),

          const SizedBox(height: 30),

          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 36) / 3;

              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Total Patients',
                      totalPatients.toString(),
                      Icons.people_outline,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Total Screenings',
                      totalScreenings.toString(),
                      Icons.remove_red_eye_outlined,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Referable Cases',
                      referableCases.toString(),
                      Icons.warning_amber_outlined,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 30),

          const Text(
            'Recent Screening Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          _buildScreeningTable(),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xFF176B87),
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Text(
            'No screenings available yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (final screening in screenings.take(10))
              _screeningRow(screening),
          ],
        ),
      ),
    );
  }

  Widget _screeningRow(Map<String, dynamic> screening) {
    final patientName = screening['patient_name'] ?? 'Unknown Patient';

    final grade = screening['dr_grade_label'] ?? 'Unknown';

    final confidence = screening['confidence'];

    final referable =
        screening['referable'] == 1 || screening['referable'] == true;

    final confidenceText = confidence is num
        ? '${(confidence * 100).toStringAsFixed(1)}%'
        : '--';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: const CircleAvatar(child: Icon(Icons.remove_red_eye_outlined)),
      title: Text(
        patientName.toString(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('$grade  •  Confidence: $confidenceText'),
      trailing: Text(
        referable ? 'Referable' : 'Non-referable',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: referable ? Colors.orange.shade800 : Colors.green.shade800,
        ),
      ),
    );
  }
}
