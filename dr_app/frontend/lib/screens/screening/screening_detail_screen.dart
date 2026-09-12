import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api/api_constants.dart';
import '../../services/api_service.dart';
import '../patients/patient_profile_screen.dart';

class ScreeningDetailScreen extends StatefulWidget {
  const ScreeningDetailScreen({
    super.key,
    required this.screeningId,
    this.patientName,
  });

  final int screeningId;
  final String? patientName;

  @override
  State<ScreeningDetailScreen> createState() => _ScreeningDetailScreenState();
}

class _ScreeningDetailScreenState extends State<ScreeningDetailScreen> {
  Map<String, dynamic>? _screening;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScreening();
  }

  Future<void> _loadScreening() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getScreening(widget.screeningId);
      if (!mounted) return;

      setState(() {
        _screening = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load screening details.';
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

  Map<String, dynamic> _normalizeProbabilities(dynamic rawValue) {
    if (rawValue is Map) {
      return rawValue.map((key, value) => MapEntry(key.toString(), value));
    }

    if (rawValue is String) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _screening == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Unable to load screening details.',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadScreening,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final screening = _screening!;
    final patientId = _safeText(screening['patient_id']);
    final patientName =
        widget.patientName ?? _safeText(screening['patient_name']);
    final screeningId = screening['id']?.toString() ?? '--';
    final quality =
        screening['quality_acceptable'] == 1 ||
            screening['quality_acceptable'] == true
        ? 'Acceptable'
        : 'Poor';
    final qualityReason = _safeText(screening['quality_reason']);
    final grade = _safeText(screening['dr_grade_label']);
    final confidence = _formatConfidence(screening['confidence']);
    final referable =
        screening['referable'] == 1 || screening['referable'] == true;
    final heatmapFile = _safeText(screening['heatmap_filename']);
    final imageFile = _safeText(screening['stored_filename']);
    final originalImageUrl = imageFile == '--'
        ? null
        : '${ApiConstants.baseUrl}/uploads/$imageFile';
    final heatmapUrl = heatmapFile == '--'
        ? null
        : '${ApiConstants.baseUrl}/heatmaps/$heatmapFile';

    final probabilities = _normalizeProbabilities(
      screening['class_probabilities'],
    );
    final probabilityEntries = ['L0', 'L1', 'L2', 'L3', 'L4'].map((label) {
      final key = label.toLowerCase();
      final value =
          probabilities[key] ??
          probabilities[label] ??
          probabilities[label.replaceFirst('L', '')] ??
          0;
      final pct = (value is num) ? (value * 100.0) : 0.0;
      return MapEntry(label, pct);
    }).toList();

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
              const Text('Back to Screenings'),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Screening #$screeningId',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF17202A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Patient: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (patientId != '--')
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                PatientProfileScreen(patientId: patientId),
                          ),
                        );
                      },
                      child: Text(patientName),
                    )
                  else
                    Text(patientName),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Patient ID: $patientId',
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Date: ${_formatDateTime(screening['created_at']?.toString())}',
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Screening Result',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 30,
                      runSpacing: 12,
                      children: [
                        _resultValue('DR Grade', grade),
                        _resultValue('Confidence', confidence),
                        _resultValue(
                          'Referral Status',
                          referable ? 'REFERABLE' : 'NON-REFERABLE',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'AI-assisted screening — requires clinician review.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF123B4A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This system is intended to support screening workflows and does not replace professional ophthalmic evaluation.',
                      style: TextStyle(color: Color(0xFF45606D)),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF176B87),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              referable
                                  ? 'AI screening indicates a referable result.'
                                  : 'AI screening indicates a non-referable result.',
                              style: const TextStyle(color: Color(0xFF17202A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Image Quality',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image Quality: $quality',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reason: $qualityReason',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 1000;
                  return Flex(
                    direction: stacked ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _imagePanel(
                          'Original Fundus Image',
                          originalImageUrl,
                          'Fundus image unavailable.',
                        ),
                      ),
                      const SizedBox(width: 20, height: 20),
                      Expanded(
                        child: _imagePanel(
                          'AI Attention Map',
                          heatmapUrl,
                          'Attention map unavailable for this screening.',
                          description:
                              'Highlights image regions that contributed most to the model\'s prediction.',
                          secondaryDescription:
                              'This visualization supports clinician review and is not a definitive lesion map.',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              const Text(
                'CLASS PROBABILITIES',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (probabilityEntries.every((entry) => entry.value == 0.0))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Text(
                    'Class probability details unavailable.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: probabilityEntries.map((entry) {
                      final label = entry.key;
                      final value = entry.value.toDouble();
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 118,
                              child: Text('$label — ${labelToName(label)}'),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: (value / 100).clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF176B87),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${value.toStringAsFixed(1)}%',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String labelToName(String label) {
    switch (label) {
      case 'L0':
        return 'No DR';
      case 'L1':
        return 'Mild';
      case 'L2':
        return 'Moderate';
      case 'L3':
        return 'Severe';
      case 'L4':
        return 'Proliferative DR';
      default:
        return '';
    }
  }

  Widget _resultValue(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _imagePanel(
    String title,
    String? imageUrl,
    String fallbackText, {
    String? description,
    String? secondaryDescription,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
          if (secondaryDescription != null) ...[
            const SizedBox(height: 6),
            Text(
              secondaryDescription,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(minHeight: 260),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: imageUrl == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        fallbackText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Image unavailable.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
