import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'screening_detail_screen.dart';

class ScreeningsScreen extends StatefulWidget {
  const ScreeningsScreen({super.key});

  @override
  State<ScreeningsScreen> createState() => _ScreeningsScreenState();
}

class _ScreeningsScreenState extends State<ScreeningsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _screenings = [];
  bool _loading = true;
  String? _error;

  String _referralFilter = 'All';
  String _gradeFilter = 'All';
  String _qualityFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadScreenings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScreenings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final screenings = await ApiService.getScreenings();
      final converted = screenings
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();

      converted.sort((a, b) {
        final aTime = a['created_at']?.toString() ?? '';
        final bTime = b['created_at']?.toString() ?? '';

        final aDate = DateTime.tryParse(aTime);
        final bDate = DateTime.tryParse(bTime);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _screenings = converted;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load screenings.';
        _loading = false;
      });
    }
  }

  bool _isReferable(Map<String, dynamic> screening) {
    final value = screening['referable'];
    return value == 1 || value == true;
  }

  bool _isQualityAcceptable(Map<String, dynamic> screening) {
    final value = screening['quality_acceptable'];
    return value == 1 || value == true;
  }

  String _formatGrade(Map<String, dynamic> screening) {
    final grade = screening['dr_grade_label']?.toString().trim();
    if (grade == null || grade.isEmpty) return '--';
    return grade;
  }

  String _formatConfidence(Map<String, dynamic> screening) {
    final value = screening['confidence'];
    if (value is num) {
      return '${(value * 100).toStringAsFixed(1)}%';
    }
    return '--';
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return '--';

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

  List<Map<String, dynamic>> get _filteredScreenings {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _screenings.where((screening) {
      bool matchesSearch = true;

      if (query.isNotEmpty) {
        final patientName = (screening['patient_name'] ?? '')
            .toString()
            .toLowerCase();
        final patientId = (screening['patient_id'] ?? '')
            .toString()
            .toLowerCase();
        final screeningId = (screening['id'] ?? '').toString().toLowerCase();

        matchesSearch =
            patientName.contains(query) ||
            patientId.contains(query) ||
            screeningId.contains(query);
      }

      final matchesReferral =
          _referralFilter == 'All' ||
          (_referralFilter == 'Referable' && _isReferable(screening)) ||
          (_referralFilter == 'Non-referable' && !_isReferable(screening));

      final matchesGrade =
          _gradeFilter == 'All' ||
          _normalizedGrade(screening).toLowerCase() ==
              _gradeFilter.toLowerCase();

      final matchesQuality =
          _qualityFilter == 'All' ||
          (_qualityFilter == 'Acceptable' && _isQualityAcceptable(screening)) ||
          (_qualityFilter == 'Poor' && !_isQualityAcceptable(screening));

      return matchesSearch && matchesReferral && matchesGrade && matchesQuality;
    }).toList();

    return filtered;
  }

  String _normalizedGrade(Map<String, dynamic> screening) {
    final grade = screening['dr_grade_label']?.toString() ?? '';

    final lower = grade.toLowerCase();
    if (lower.contains('l0') || lower.contains('no dr')) {
      return 'L0 — No DR';
    }
    if (lower.contains('l1') || lower.contains('mild')) {
      return 'L1 — Mild';
    }
    if (lower.contains('l2') || lower.contains('moderate')) {
      return 'L2 — Moderate';
    }
    if (lower.contains('l3') || lower.contains('severe')) {
      return 'L3 — Severe';
    }
    if (lower.contains('l4') || lower.contains('proliferative')) {
      return 'L4 — Proliferative DR';
    }
    return grade;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Screenings',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17202A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review AI-assisted retinal screening results.',
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
                      hintText:
                          'Search by patient name, patient ID, or screening ID',
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
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _referralFilter = 'All';
                    _gradeFilter = 'All';
                    _qualityFilter = 'All';
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
                          onPressed: _loadScreenings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredScreenings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.remove_red_eye_outlined,
                          size: 42,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No screening records available.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildScreeningTable(),
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

  Widget _buildScreeningTable() {
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
              DataColumn(label: Text('Screening ID')),
              DataColumn(label: Text('Patient')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('DR Grade')),
              DataColumn(label: Text('Confidence')),
              DataColumn(label: Text('Referral')),
              DataColumn(label: Text('Quality')),
              DataColumn(label: Text('Action')),
            ],
            rows: _filteredScreenings.map((screening) {
              final screeningId = screening['id']?.toString() ?? '--';
              final patientName =
                  (screening['patient_name'] ?? 'Unknown Patient').toString();
              final date = _formatDate(screening['created_at']?.toString());
              final grade = _formatGrade(screening);
              final confidence = _formatConfidence(screening);
              final referral = _isReferable(screening)
                  ? 'Referable'
                  : 'Non-referable';
              final quality = _isQualityAcceptable(screening)
                  ? 'Acceptable'
                  : 'Poor';

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
                        color: _isReferable(screening)
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
                            builder: (context) => ScreeningDetailScreen(
                              screeningId: parsedId,
                              patientName: patientName,
                            ),
                          ),
                        );
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
}
