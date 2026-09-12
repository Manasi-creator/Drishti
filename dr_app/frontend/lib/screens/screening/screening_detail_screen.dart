import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api/api_constants.dart';

class ScreeningDetailScreen extends StatelessWidget {
  const ScreeningDetailScreen({
    super.key,
    required this.screening,
    required this.patientName,
  });

  final Map<String, dynamic> screening;
  final String patientName;

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
    final screeningId = screening['id']?.toString() ?? '--';
    final quality =
        screening['quality_acceptable'] == 1 ||
            screening['quality_acceptable'] == true
        ? 'Pass'
        : 'Review';
    final grade = _safeText(screening['dr_grade_label']);
    final confidence = _formatConfidence(screening['confidence']);
    final referable =
        screening['referable'] == 1 || screening['referable'] == true;
    final heatmapFile = _safeText(screening['heatmap_filename']);
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
      final pct = (value is num) ? (value * 100) : 0.0;
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
              const Text('Screening Result'),
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
              const Text(
                'SCREENING RESULT',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF17202A),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 20,
                  children: [
                    _detailItem('Screening ID', screeningId),
                    _detailItem(
                      'Date',
                      _formatDateTime(screening['created_at']?.toString()),
                    ),
                    _detailItem('Patient', patientName),
                    _detailItem('Image quality', quality),
                    _detailItem('DR Grade', grade),
                    _detailItem('Confidence', confidence),
                    _detailItem(
                      'Referral status',
                      referable ? 'Referable' : 'Non-referable',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'CLASS PROBABILITIES',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              if (probabilityEntries.every((entry) => entry.value == 0.0))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(0xFFE5E7EB)),
                  ),
                  child: const Text(
                    'Class probabilities unavailable for this screening.',
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
                            SizedBox(width: 120, child: Text('$label  ')),
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
              const SizedBox(height: 28),
              const Text(
                'AI Attention Map',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Highlights image regions that contributed to the model's prediction. This visualization supports clinician review and is not a definitive lesion map.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (heatmapUrl == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Text(
                    'Attention map unavailable for this screening.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      heatmapUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Attention map unavailable for this screening.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F7F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD9E7EA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AI-assisted screening — requires clinician review.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF123B4A),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This system is intended to support screening workflows and does not replace professional ophthalmic evaluation.',
                      style: TextStyle(color: Color(0xFF45606D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return SizedBox(
      width: 190,
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
