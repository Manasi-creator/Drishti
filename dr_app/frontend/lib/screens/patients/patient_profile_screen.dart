import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../screening/screening_detail_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  Map<String, dynamic>? _patient;
  List<dynamic> _screenings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getPatient(widget.patientId);
      final patient = (response['patient'] as Map<String, dynamic>?) ?? {};
      final screenings = (response['screenings'] as List<dynamic>?) ?? const [];

      if (!mounted) return;

      setState(() {
        _patient = patient;
        _screenings = screenings;
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

  String _safeText(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? '--' : text;
  }

  String _formatDateTime(String? value) {
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

  String _formatConfidence(dynamic value) {
    if (value is num) {
      return '${(value * 100).toStringAsFixed(1)}%';
    }

    return '--';
  }

  String _latestGradeLabel() {
    if (_screenings.isEmpty) {
      return 'No screening records available.';
    }

    final latest = _screenings.first as Map<String, dynamic>;
    final label = latest['dr_grade_label'];
    return label == null || label.toString().trim().isEmpty
        ? '--'
        : label.toString();
  }

  String _latestConfidence() {
    if (_screenings.isEmpty) {
      return '--';
    }

    final latest = _screenings.first as Map<String, dynamic>;
    final confidence = latest['confidence'];
    return _formatConfidence(confidence);
  }

  String _latestReferral() {
    if (_screenings.isEmpty) {
      return '--';
    }

    final latest = _screenings.first as Map<String, dynamic>;
    final referable = latest['referable'] == 1 || latest['referable'] == true;
    return referable ? 'Referable' : 'Non-referable';
  }

  @override
  Widget build(BuildContext context) {
    final patientName = _safeText(_patient?['name']);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
              const Text('Back to Patients'),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadPatient,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _patient == null
          ? const Center(
              child: Text(
                'No patient information available.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient Profile',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF17202A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          color: Color(0xFF176B87),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Patient ID: ${_safeText(_patient?['patient_id'])}',
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PATIENT INFORMATION',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Color(0xFF176B87),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 32,
                            runSpacing: 20,
                            children: [
                              _infoTile('Name', patientName),
                              _infoTile(
                                'Patient ID',
                                _safeText(_patient?['patient_id']),
                              ),
                              _infoTile(
                                'Date of Birth',
                                _formatDateTime(
                                  _patient?['date_of_birth']?.toString(),
                                ),
                              ),
                              _infoTile(
                                'Gender',
                                _safeText(_patient?['gender']),
                              ),
                              _infoTile('Phone', _safeText(_patient?['phone'])),
                              _infoTile(
                                'Blood Group',
                                _safeText(_patient?['blood_group']),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Screening Summary',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_screenings.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFE5E7EB)),
                        ),
                        child: const Center(
                          child: Text(
                            'No screening records available.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          _summaryCard(
                            'Total Screenings',
                            _screenings.length.toString(),
                          ),
                          _summaryCard('Latest DR Grade', _latestGradeLabel()),
                          _summaryCard(
                            'Latest Confidence',
                            _latestConfidence(),
                          ),
                          _summaryCard(
                            'Latest Referral Status',
                            _latestReferral(),
                          ),
                        ],
                      ),
                    const SizedBox(height: 30),
                    const Text(
                      'Screening History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildScreeningHistory(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScreeningHistory() {
    final patientName = _safeText(_patient?['name']);

    if (_screenings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Text(
            'No screening records available.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 860),
          child: DataTable(
            headingRowColor: WidgetStateColor.resolveWith(
              (states) => const Color(0xFFF8FAFC),
            ),
            columns: const [
              DataColumn(label: Text('Screening ID')),
              DataColumn(label: Text('Date / Time')),
              DataColumn(label: Text('DR Grade')),
              DataColumn(label: Text('Confidence')),
              DataColumn(label: Text('Referral')),
              DataColumn(label: Text('Quality')),
              DataColumn(label: Text('View Details')),
            ],
            rows: _screenings.map((screening) {
              final screeningId = screening['id']?.toString() ?? '--';
              final date = _formatDateTime(screening['created_at']?.toString());
              final grade = _safeText(screening['dr_grade_label']);
              final confidence = _formatConfidence(screening['confidence']);
              final referable =
                  screening['referable'] == 1 || screening['referable'] == true;
              final quality =
                  screening['quality_acceptable'] == 1 ||
                      screening['quality_acceptable'] == true
                  ? 'Pass'
                  : 'Review';

              return DataRow(
                cells: [
                  DataCell(Text(screeningId)),
                  DataCell(Text(date)),
                  DataCell(Text(grade)),
                  DataCell(Text(confidence)),
                  DataCell(
                    Text(
                      referable ? 'Referable' : 'Non-referable',
                      style: TextStyle(
                        color: referable
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(Text(quality)),
                  DataCell(
                    TextButton(
                      onPressed: () {
                        final screeningId = screening['id'];
                        if (screeningId is int) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ScreeningDetailScreen(
                                screeningId: screeningId,
                                patientName: patientName,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('View Details'),
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

  Widget _infoTile(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF17202A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
