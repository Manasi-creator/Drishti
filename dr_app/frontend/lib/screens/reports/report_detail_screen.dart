import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/api/api_constants.dart';
import '../../services/api_service.dart';
import '../../services/report_pdf_service.dart';
import '../patients/patient_profile_screen.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.screeningId});

  final int screeningId;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  Map<String, dynamic>? _screening;
  bool _loading = true;
  bool _isGeneratingPdf = false;
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
        _error = 'Unable to load report.';
        _loading = false;
      });
    }
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? '--' : text;
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

  String _normalizedGrade(Map<String, dynamic> screening) {
    final grade = screening['dr_grade_label']?.toString() ?? '';
    final lower = grade.toLowerCase();

    if (lower.contains('l0') || lower.contains('no dr')) return 'L0 — No DR';
    if (lower.contains('l1') || lower.contains('mild')) return 'L1 — Mild';
    if (lower.contains('l2') || lower.contains('moderate')) {
      return 'L2 — Moderate';
    }
    if (lower.contains('l3') || lower.contains('severe')) {
      return 'L3 — Severe';
    }
    if (lower.contains('l4') || lower.contains('proliferative')) {
      return 'L4 — Proliferative DR';
    }
    return grade.isEmpty ? 'Unspecified' : grade;
  }

  bool _isReferable(Map<String, dynamic> screening) {
    return screening['referable'] == 1 || screening['referable'] == true;
  }

  bool _isQualityAcceptable(Map<String, dynamic> screening) {
    return screening['quality_acceptable'] == 1 ||
        screening['quality_acceptable'] == true;
  }

  String _labelForProbability(String label) {
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
                _error ?? 'Unable to load report.',
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
    final patientName = _safeText(screening['patient_name']);
    final screeningId = screening['id']?.toString() ?? '--';
    final grade = _normalizedGrade(screening);
    final confidence = _formatConfidence(screening['confidence']);
    final referral = _isReferable(screening) ? 'Referable' : 'Non-referable';
    final quality = _isQualityAcceptable(screening) ? 'Acceptable' : 'Poor';
    final qualityReason = _safeText(screening['quality_reason']);
    final originalImageName = _safeText(screening['stored_filename']);
    final heatmapFile = _safeText(screening['heatmap_filename']);
    final originalImageUrl = originalImageName == '--'
        ? null
        : '${ApiConstants.baseUrl}/uploads/$originalImageName';
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
      final pct = value is num ? (value * 100.0) : 0.0;
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
              const Text('Back to Reports'),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Screening Report',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF17202A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Screening ID: $screeningId',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${_formatDateTime(screening['created_at']?.toString())}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (patientId != '--')
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    PatientProfileScreen(patientId: patientId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_outline),
                          label: const Text('View Patient'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _infoCard(
                title: 'Patient Summary',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow('Patient name', patientName),
                    if (screening['date_of_birth'] != null)
                      _summaryRow(
                        'Date of birth',
                        _safeText(screening['date_of_birth']),
                      ),
                    if (screening['gender'] != null)
                      _summaryRow('Gender', _safeText(screening['gender'])),
                    if (screening['phone'] != null)
                      _summaryRow('Phone', _safeText(screening['phone'])),
                    if (screening['blood_group'] != null)
                      _summaryRow(
                        'Blood group',
                        _safeText(screening['blood_group']),
                      ),
                    _summaryRow('Patient ID', patientId),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _infoCard(
                title: 'AI Screening Result',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI-assisted screening result',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The result is intended to support clinician review and does not constitute a definitive diagnosis.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 28,
                      runSpacing: 14,
                      children: [
                        _resultValue('DR Grade', grade),
                        _resultValue('Confidence', confidence),
                        _resultValue('Referral', referral),
                        _resultValue('Image quality', quality),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 1000;
                  return Flex(
                    direction: stacked ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _imageCard(
                          'Fundus Image',
                          originalImageUrl,
                          originalImageName,
                          quality,
                        ),
                      ),
                      const SizedBox(width: 20, height: 20),
                      Expanded(
                        child: _imageCard(
                          'AI Attention Map',
                          heatmapUrl,
                          heatmapFile,
                          quality,
                          description:
                              'Highlights retinal regions that contributed most to the model\'s prediction.',
                          secondaryDescription:
                              'This visualization represents model attention and is provided to support clinician interpretation.',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _infoCard(
                title: 'Class Probabilities',
                content: Column(
                  children: probabilityEntries.map((entry) {
                    final label = entry.key;
                    final value = entry.value.toDouble();
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              '$label — ${_labelForProbability(label)}',
                            ),
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
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 56,
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
              const SizedBox(height: 24),
              _infoCard(
                title: 'Image Quality',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $quality',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      qualityReason.isEmpty
                          ? 'No quality assessment note provided.'
                          : 'Reason: $qualityReason',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _infoCard(
                title: 'Clinical Review',
                content: Text(
                  _isReferable(screening)
                      ? 'AI-assisted screening indicates a referable result. Clinical evaluation by an appropriately qualified eye-care professional should be considered.'
                      : 'AI-assisted screening did not meet the configured referral threshold. Continue with appropriate clinical screening protocols.',
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isGeneratingPdf
                        ? null
                        : () async {
                            await _printReport();
                          },
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print Report'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isGeneratingPdf
                        ? null
                        : () async {
                            await _exportPdf();
                          },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Export PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_screening == null) {
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final pdfBytes = await ReportPdfService.generateReportPdf(_screening!);
      final result = await FilePicker.saveFile(
        dialogTitle: 'Save Drishti report',
        fileName: 'Drishti_Report_${_screening!['id']}.pdf',
        mimeType: 'application/pdf',
        bytes: pdfBytes,
      );

      if (result == null) {
        if (!mounted) return;
        setState(() {
          _isGeneratingPdf = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Export cancelled.')));
        return;
      }

      final file = File(result.toFilePath());

      if (!mounted) return;
      setState(() {
        _isGeneratingPdf = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report saved to ${file.path}')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingPdf = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to export report: $error')),
      );
    }
  }

  Future<void> _printReport() async {
    if (_screening == null) {
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Print is only supported on native desktop/mobile builds, not in the browser.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final pdfBytes = await ReportPdfService.generateReportPdf(_screening!);
      final printed = await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      if (!mounted) return;
      setState(() {
        _isGeneratingPdf = false;
      });
      if (!printed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Printing cancelled.')));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingPdf = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to print report: $error')));
    }
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _resultValue(String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required Widget content}) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  Widget _imageCard(
    String title,
    String? imageUrl,
    String filename,
    String quality, {
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
          const SizedBox(height: 8),
          if (description != null)
            Text(
              description,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          if (secondaryDescription != null) ...[
            const SizedBox(height: 4),
            Text(
              secondaryDescription,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          if (filename != '--')
            Text(
              'File: $filename',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const SizedBox(height: 10),
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
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        '$title unavailable',
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
          const SizedBox(height: 10),
          Text(
            'Image quality: $quality',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
