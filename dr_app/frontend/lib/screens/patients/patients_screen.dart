import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'patient_profile_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final patientList = await ApiService.getPatients();
      final enrichedPatients = <Map<String, dynamic>>[];

      for (final patient in patientList) {
        final patientId = (patient['patient_id'] ?? '').toString();

        if (patientId.isEmpty) {
          enrichedPatients.add({
            ...patient,
            'screening_count': 0,
            'last_screening_at': null,
          });
          continue;
        }

        final screenings = await ApiService.getPatientScreenings(patientId);
        final latestScreening = screenings.isNotEmpty ? screenings.first : null;

        enrichedPatients.add({
          ...patient,
          'screening_count': screenings.length,
          'last_screening_at': latestScreening != null
              ? latestScreening['created_at']
              : null,
        });
      }

      if (!mounted) return;

      setState(() {
        _patients = enrichedPatients;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load patient information.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPatients {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _patients;
    }

    return _patients.where((patient) {
      final patientId = (patient['patient_id'] ?? '').toString().toLowerCase();
      final name = (patient['name'] ?? '').toString().toLowerCase();
      return patientId.contains(query) || name.contains(query);
    }).toList();
  }

  void _openPatientProfile(String patientId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PatientProfileScreen(patientId: patientId),
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '--';
    }

    try {
      final date = DateTime.parse(value);
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
    } catch (_) {
      return '--';
    }
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? '--' : text;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patients',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17202A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage patient records and view screening history.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 420,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search patients by name or patient ID',
                prefixIcon: const Icon(Icons.search_outlined),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF176B87),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadPatients,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredPatients.isEmpty
                ? const Center(
                    child: Text(
                      'No patients found.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : _buildPatientTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 980),
          child: DataTable(
            headingRowColor: WidgetStateColor.resolveWith(
              (states) => const Color(0xFFF8FAFC),
            ),
            columns: const [
              DataColumn(label: Text('Patient ID')),
              DataColumn(label: Text('Patient Name')),
              DataColumn(label: Text('Gender')),
              DataColumn(label: Text('Blood Group')),
              DataColumn(label: Text('Screenings')),
              DataColumn(label: Text('Last Screening')),
              DataColumn(label: Text('Action')),
            ],
            rows: _filteredPatients.map((patient) {
              final patientId = _safeText(patient['patient_id']);
              final name = _safeText(patient['name']);
              final gender = _safeText(patient['gender']);
              final bloodGroup = _safeText(patient['blood_group']);
              final screeningCount = patient['screening_count'] ?? 0;
              final lastScreening = _formatDate(
                patient['last_screening_at']?.toString(),
              );

              return DataRow(
                onSelectChanged: (_) => _openPatientProfile(patientId),
                cells: [
                  DataCell(Text(patientId)),
                  DataCell(Text(name)),
                  DataCell(Text(gender)),
                  DataCell(Text(bloodGroup)),
                  DataCell(Text(screeningCount.toString())),
                  DataCell(Text(lastScreening)),
                  DataCell(
                    TextButton.icon(
                      onPressed: () => _openPatientProfile(patientId),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('View'),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
