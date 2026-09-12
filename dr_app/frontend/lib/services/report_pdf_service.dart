import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/api/api_constants.dart';

class ReportPdfService {
  static Future<Uint8List> generateReportPdf(
    Map<String, dynamic> screening,
  ) async {
    final pdf = pw.Document();

    final screeningId = screening['id'] ?? 'unknown';
    final patientId = _safeText(screening['patient_id']);
    final patientName = _safeText(
      screening['patient_name'] ?? screening['name'],
    );
    final generatedAt = DateTime.now().toLocal();
    final qualityStatus = _isQualityAcceptable(screening)
        ? 'ACCEPTABLE'
        : 'POOR';
    final referralStatus = _isReferable(screening)
        ? 'REFERABLE'
        : 'NON-REFERABLE';
    final confidence = _formatConfidence(screening['confidence']);
    final gradeLabel = _safeText(screening['dr_grade_label']);
    final gradeValue = _normalizedGrade(screening);
    final qualityReason = _safeText(screening['quality_reason']);
    final probabilities = _normalizeProbabilities(
      screening['class_probabilities'],
    );
    final originalImageName = _safeText(screening['stored_filename']);
    final heatmapFilename = _safeText(screening['heatmap_filename']);
    final originalImageBytes = originalImageName == '--'
        ? null
        : await _fetchImageBytes(
            '${ApiConstants.baseUrl}/uploads/$originalImageName',
          );
    final heatmapBytes = heatmapFilename == '--'
        ? null
        : await _fetchImageBytes(
            '${ApiConstants.baseUrl}/heatmaps/$heatmapFilename',
          );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final bodyStyle = pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey800,
          );
          final sectionStyle = pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal800,
          );

          return [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.teal700, width: 1.5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DRISHTI',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'AI-Assisted Diabetic Retinopathy Screening Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Report Information', style: sectionStyle),
                  pw.SizedBox(height: 10),
                  _rowText(
                    'Report ID',
                    'DR-${screeningId.toString().padLeft(6, '0')}',
                  ),
                  _rowText(
                    'Screening Date & Time',
                    _formatDisplayDate(screening['created_at']?.toString()),
                  ),
                  _rowText('Patient ID', patientId),
                  _rowText('Patient Name', patientName),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text('Section 1 — Patient Information', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _rowText('Patient Name', patientName),
                  _rowText('Patient ID', patientId),
                  if (screening['date_of_birth'] != null)
                    _rowText(
                      'Date of Birth',
                      _safeText(screening['date_of_birth']),
                    ),
                  if (screening['gender'] != null)
                    _rowText('Gender', _safeText(screening['gender'])),
                  if (screening['blood_group'] != null)
                    _rowText(
                      'Blood Group',
                      _safeText(screening['blood_group']),
                    ),
                  if (screening['phone'] != null)
                    _rowText('Phone', _safeText(screening['phone'])),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Section 2 — AI-Assisted Screening Result',
              style: sectionStyle,
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    gradeValue,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    gradeLabel.isEmpty ? 'Unspecified' : gradeLabel,
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                  ),
                  pw.SizedBox(height: 12),
                  _rowText('Confidence', confidence),
                  _rowText('Referral Status', referralStatus),
                  _rowText('Image Quality', qualityStatus),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'This AI-assisted screening result is intended to support clinician review and does not constitute a definitive diagnosis.',
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text('Section 3 — Retinal Images', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _imageBlock(
                    title: 'Original Fundus Image',
                    bytes: originalImageBytes,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _imageBlock(
                    title: 'AI Attention Map',
                    bytes: heatmapBytes,
                    description:
                        'The AI attention map highlights retinal regions that contributed to the model\'s prediction. It is provided as a model-interpretability aid and should not be interpreted as definitive lesion detection.',
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text('Section 4 — Class Probabilities', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: [
                  for (final label in ['L0', 'L1', 'L2', 'L3', 'L4'])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 130,
                            child: pw.Text(
                              '$label — ${_labelForProbability(label)}',
                              style: bodyStyle,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Container(
                              height: 12,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey200,
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(6),
                                ),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Expanded(
                                    flex:
                                        ((probabilities[label] is num
                                                    ? (probabilities[label]
                                                              as num)
                                                          .toDouble()
                                                    : 0.0) *
                                                10)
                                            .round()
                                            .clamp(0, 100),
                                    child: pw.Container(
                                      height: 12,
                                      decoration: const pw.BoxDecoration(
                                        color: PdfColors.teal600,
                                        borderRadius: pw.BorderRadius.all(
                                          pw.Radius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(width: 4),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.SizedBox(
                            width: 54,
                            child: pw.Text(
                              '${_percentageFor(probabilities[label]).toStringAsFixed(1)}%',
                              style: bodyStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Section 5 — Image Quality Assessment',
              style: sectionStyle,
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Quality Status: $qualityStatus',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    qualityReason.isEmpty
                        ? 'No quality assessment note provided.'
                        : 'Reason: $qualityReason',
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text('Section 6 — Clinical Review', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(
                _isReferable(screening)
                    ? 'The AI-assisted screening result meets the configured referral threshold. Clinical evaluation by an appropriately qualified eye-care professional should be considered.'
                    : 'The AI-assisted screening result does not meet the configured referral threshold. This result should be interpreted within the appropriate clinical screening protocol.',
                style: bodyStyle,
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text('Section 7 — Important Disclaimer', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(
                'Drishti provides AI-assisted screening support and is not a substitute for professional medical judgment or definitive ophthalmic diagnosis. Results should be reviewed by an appropriately qualified healthcare professional.',
                style: bodyStyle,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey400, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DRISHTI | AI-Assisted Retinal Screening',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Generated on: ${_formatDisplayDateTime(generatedAt.toIso8601String())}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Report ID: DR-${screeningId.toString().padLeft(6, '0')}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _imageBlock({
    required String title,
    required Uint8List? bytes,
    String? description,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          if (description != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              description,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 8),
          if (bytes != null)
            pw.Container(
              width: 200,
              height: 180,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Center(
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
              ),
            )
          else
            pw.Container(
              width: 200,
              height: 180,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Center(
                child: pw.Text(
                  'Image unavailable',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _rowText(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static String _safeText(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? '--' : text;
  }

  static String _formatDisplayDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '--';
    }

    try {
      final date = DateTime.parse(value);
      return '${date.day} ${_monthName(date.month)} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  static String _formatDisplayDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '--';
    }

    try {
      final date = DateTime.parse(value);
      return '${date.day} ${_monthName(date.month)} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  static String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }

  static String _normalizedGrade(Map<String, dynamic> screening) {
    final grade = screening['dr_grade_label']?.toString() ?? '';
    final lower = grade.toLowerCase();

    if (lower.contains('l0') || lower.contains('no dr')) return 'L0';
    if (lower.contains('l1') || lower.contains('mild')) return 'L1';
    if (lower.contains('l2') || lower.contains('moderate')) return 'L2';
    if (lower.contains('l3') || lower.contains('severe')) return 'L3';
    if (lower.contains('l4') || lower.contains('proliferative')) return 'L4';
    return grade.isEmpty ? 'Unspecified' : grade;
  }

  static bool _isReferable(Map<String, dynamic> screening) {
    return screening['referable'] == 1 || screening['referable'] == true;
  }

  static bool _isQualityAcceptable(Map<String, dynamic> screening) {
    return screening['quality_acceptable'] == 1 ||
        screening['quality_acceptable'] == true;
  }

  static String _formatConfidence(dynamic value) {
    if (value is num) {
      return '${(value * 100).toStringAsFixed(1)}%';
    }
    return '--';
  }

  static Map<String, dynamic> _normalizeProbabilities(dynamic rawValue) {
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

  static String _labelForProbability(String label) {
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

  static double _percentageFor(dynamic value) {
    if (value is num) {
      return (value * 100.0).clamp(0.0, 100.0);
    }
    return 0.0;
  }
}
