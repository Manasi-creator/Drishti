import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _reports = [];
  bool _loading = true;
  String? _error;

  String _referralFilter = 'All';
  String _gradeFilter = 'All';
  String _qualityFilter = 'All';
  String _sortOrder = 'Newest first';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getScreenings();
      if (!mounted) return;

      setState(() {
        _reports = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load reports.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _reports.whereType<Map<String, dynamic>>().where((report) {
      bool matchesSearch = true;

      if (query.isNotEmpty) {
        final patientName = (report['patient_name'] ?? '')
            .toString()
            .toLowerCase();
        final patientId = (report['patient_id'] ?? '').toString().toLowerCase();
        final screeningId = (report['id'] ?? '').toString().toLowerCase();

        matchesSearch =
            patientName.contains(query) ||
            patientId.contains(query) ||
            screeningId.contains(query);
      }

      final matchesReferral =
          _referralFilter == 'All' ||
          (_referralFilter == 'Referable' && _isReferable(report)) ||
          (_referralFilter == 'Non-referable' && !_isReferable(report));

      final matchesGrade =
          _gradeFilter == 'All' ||
          _normalizedGrade(report).toLowerCase() == _gradeFilter.toLowerCase();

      final matchesQuality =
          _qualityFilter == 'All' ||
          (_qualityFilter == 'Acceptable' && _isQualityAcceptable(report)) ||
          (_qualityFilter == 'Poor' && !_isQualityAcceptable(report));

      return matchesSearch && matchesReferral && matchesGrade && matchesQuality;
    }).toList();

    filtered.sort((a, b) {
      final aTime = _parseDateTime(a['created_at']?.toString());
      final bTime = _parseDateTime(b['created_at']?.toString());

      final comparison = aTime.compareTo(bTime);
      return _sortOrder == 'Newest first' ? -comparison : comparison;
    });

    return filtered;
  }

  DateTime _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
  }

  bool _isReferable(Map<String, dynamic> report) {
    final value = report['referable'];
    return value == 1 || value == true;
  }

  bool _isQualityAcceptable(Map<String, dynamic> report) {
    final value = report['quality_acceptable'];
    return value == 1 || value == true;
  }

  String _normalizedGrade(Map<String, dynamic> report) {
    final grade = report['dr_grade_label']?.toString() ?? '';
    final lower = grade.toLowerCase();

    if (lower.contains('l0') || lower.contains('no dr')) return 'L0 — No DR';
    if (lower.contains('l1') || lower.contains('mild')) return 'L1 — Mild';
    if (lower.contains('l2') || lower.contains('moderate')) {
      return 'L2 — Moderate';
    }
    if (lower.contains('l3') || lower.contains('severe')) return 'L3 — Severe';
    if (lower.contains('l4') || lower.contains('proliferative')) {
      return 'L4 — Proliferative DR';
    }

    return grade.isEmpty ? 'Unspecified' : grade;
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
      return '${date.day} ${monthNames[date.month - 1]} ${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports Centre',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17202A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review AI-assisted diabetic retinopathy screening reports and clinical findings.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  width: 420,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search patient, patient ID or screening ID',
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
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _filterDropdown(
                'Referral',
                ['All', 'Referable', 'Non-referable'],
                _referralFilter,
                (value) => setState(() => _referralFilter = value ?? 'All'),
              ),
              _filterDropdown(
                'DR Grade',
                [
                  'All',
                  'L0 — No DR',
                  'L1 — Mild',
                  'L2 — Moderate',
                  'L3 — Severe',
                  'L4 — Proliferative DR',
                ],
                _gradeFilter,
                (value) => setState(() => _gradeFilter = value ?? 'All'),
              ),
              _filterDropdown(
                'Image Quality',
                ['All', 'Acceptable', 'Poor'],
                _qualityFilter,
                (value) => setState(() => _qualityFilter = value ?? 'All'),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _sortOrder,
                  decoration: InputDecoration(
                    labelText: 'Sort',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Newest first',
                      child: Text('Newest first'),
                    ),
                    DropdownMenuItem(
                      value: 'Oldest first',
                      child: Text('Oldest first'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _sortOrder = value ?? 'Newest first'),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _referralFilter = 'All';
                    _gradeFilter = 'All';
                    _qualityFilter = 'All';
                    _sortOrder = 'Newest first';
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear Filters'),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadReports,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredReports.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 42,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No screening reports found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Adjust your search or filters to view more records.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildReportsTable(),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown(
    String label,
    List<String> items,
    String currentValue,
    ValueChanged<String?> onChanged,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: items.contains(currentValue) ? currentValue : items.first,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReportsTable() {
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
          constraints: const BoxConstraints(minWidth: 1180),
          child: DataTable(
            headingRowColor: WidgetStateColor.resolveWith(
              (states) => const Color(0xFFF8FAFC),
            ),
            columns: const [
              DataColumn(label: Text('Report / Screening ID')),
              DataColumn(label: Text('Patient')),
              DataColumn(label: Text('Date & Time')),
              DataColumn(label: Text('DR Grade')),
              DataColumn(label: Text('Confidence')),
              DataColumn(label: Text('Referral')),
              DataColumn(label: Text('Image Quality')),
              DataColumn(label: Text('Action')),
            ],
            rows: _filteredReports.map((report) {
              final screeningId = report['id']?.toString() ?? '--';
              final patientName = (report['patient_name'] ?? 'Unknown Patient')
                  .toString();
              final grade = _normalizedGrade(report);
              final confidence = _formatConfidence(report['confidence']);
              final referral = _isReferable(report)
                  ? 'Referable'
                  : 'Non-referable';
              final quality = _isQualityAcceptable(report)
                  ? 'Acceptable'
                  : 'Poor';
              final date = _formatDateTime(report['created_at']?.toString());

              return DataRow(
                cells: [
                  DataCell(Text('#$screeningId')),
                  DataCell(Text(patientName)),
                  DataCell(Text(date)),
                  DataCell(Text(grade)),
                  DataCell(Text(confidence)),
                  DataCell(
                    Text(
                      referral,
                      style: TextStyle(
                        color: _isReferable(report)
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
                        final parsedId = int.tryParse(screeningId);
                        if (parsedId == null) return;

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ReportDetailScreen(screeningId: parsedId),
                          ),
                        );
                      },
                      child: const Text('View Report'),
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
