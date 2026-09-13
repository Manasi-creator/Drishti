import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api/api_constants.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loadingHealth = false;
  bool _backendConnected = false;
  String _backendStatus = 'Backend unavailable';
  final String _apiUrl = ApiConstants.baseUrl;

  final _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    setState(() {
      _loadingHealth = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/health'),
      );
      final connected = response.statusCode == 200;
      setState(() {
        _backendConnected = connected;
        _backendStatus = connected
            ? 'Connected to Drishti Backend'
            : 'Backend unavailable';
      });
    } catch (_) {
      setState(() {
        _backendConnected = false;
        _backendStatus = 'Backend unavailable';
      });
    } finally {
      setState(() {
        _loadingHealth = false;
      });
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all application preferences?'),
        content: const Text(
          'This resets only the app-level preferences and does not delete patients, screenings, reports, images, or database data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _settings.resetToDefaults();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application settings reset to defaults.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings.settings;
    final doctor = AuthService.instance.currentDoctor;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF17202A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage Drishti application preferences, screening configuration and report settings.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Appearance',
                  children: [
                    _buildSettingRow(
                      label: 'Theme',
                      description: 'Application display theme',
                      trailing: DropdownButton<String>(
                        value: settings.theme,
                        items: const [
                          DropdownMenuItem(
                            value: 'Light',
                            child: Text('Light'),
                          ),
                          DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                          DropdownMenuItem(
                            value: 'System',
                            child: Text('System'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await _settings.setTheme(value);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    _buildSwitchRow(
                      label: 'Compact Interface',
                      description:
                          'Use a tighter desktop layout for relevant views.',
                      value: settings.compactInterface,
                      onChanged: (value) async {
                        await _settings.setCompactInterface(value);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Screening Preferences',
                  children: [
                    _buildSettingRow(
                      label: 'Application referral threshold',
                      description:
                          'Screenings at or above this configured grade are marked as referable.',
                      trailing: DropdownButton<String>(
                        value: settings.referralThreshold,
                        items: const [
                          DropdownMenuItem(
                            value: 'L0',
                            child: Text('L0 — No DR'),
                          ),
                          DropdownMenuItem(
                            value: 'L1',
                            child: Text('L1 — Mild'),
                          ),
                          DropdownMenuItem(
                            value: 'L2',
                            child: Text('L2 — Moderate'),
                          ),
                          DropdownMenuItem(
                            value: 'L3',
                            child: Text('L3 — Severe'),
                          ),
                          DropdownMenuItem(
                            value: 'L4',
                            child: Text('L4 — Proliferative DR'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await _settings.setReferralThreshold(value);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    _buildSwitchRow(
                      label: 'Show AI Confidence',
                      description:
                          'Display model confidence alongside screening results.',
                      value: settings.showConfidence,
                      onChanged: (value) async {
                        await _settings.setShowConfidence(value);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchRow(
                      label: 'Show AI Attention Map',
                      description:
                          'Display the model attention visualization when available.',
                      value: settings.showAttentionMap,
                      onChanged: (value) async {
                        await _settings.setShowAttentionMap(value);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchRow(
                      label: 'Image Quality Check',
                      description:
                          'Perform image quality screening before AI analysis.',
                      value: settings.imageQualityCheck,
                      onChanged: (value) async {
                        await _settings.setImageQualityCheck(value);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Report Preferences',
                  children: [
                    _buildSettingRow(
                      label: 'Report Format',
                      description: 'Default layout for generated reports.',
                      trailing: DropdownButton<String>(
                        value: settings.reportFormat,
                        items: const [
                          DropdownMenuItem(value: 'A4', child: Text('A4')),
                          DropdownMenuItem(
                            value: 'Letter',
                            child: Text('Letter'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await _settings.setReportFormat(value);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    _buildSwitchRow(
                      label: 'Include Fundus Image',
                      description:
                          'Include retinal fundus images in exported PDFs.',
                      value: settings.includeFundusImage,
                      onChanged: (value) async {
                        await _settings.setIncludeFundusImage(value);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchRow(
                      label: 'Include AI Attention Map',
                      description:
                          'Include the attention map visualization in exported PDFs.',
                      value: settings.includeAttentionMap,
                      onChanged: (value) async {
                        await _settings.setIncludeAttentionMap(value);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchRow(
                      label: 'Include Class Probabilities',
                      description:
                          'Include class probability breakdowns in report exports.',
                      value: settings.includeClassProbabilities,
                      onChanged: (value) async {
                        await _settings.setIncludeClassProbabilities(value);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSettingRow(
                      label: 'Include Clinical Disclaimer',
                      description:
                          'Required for safe presentation of AI-assisted screening results.',
                      trailing: const Text('Always On'),
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Notifications',
                  children: [
                    _buildSwitchRow(
                      label: 'Report Review Reminder',
                      description:
                          'Notify the clinician when a screening report requires review.',
                      value: settings.reportReviewReminder,
                      onChanged: (value) async {
                        await _settings.setReportReviewReminder(value);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchRow(
                      label: 'Referable Screening Alert',
                      description:
                          'Highlight referable screening results in the application.',
                      value: settings.referableScreeningAlert,
                      onChanged: (value) async {
                        await _settings.setReferableScreeningAlert(value);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Data & Storage',
                  children: [
                    _buildInfoRow(
                      label: 'Backend',
                      value: _backendStatus,
                      trailing: _loadingHealth
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _backendConnected
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              color: _backendConnected
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                    ),
                    _buildActionRow(
                      label: 'Local Database',
                      value: 'SQLite',
                      description:
                          'Drishti currently uses a local SQLite database for the development environment.',
                      onPressed: _checkBackendHealth,
                      buttonLabel: 'Refresh Connection',
                    ),
                    _buildInfoRow(
                      label: 'Uploaded Screening Images',
                      value: 'Managed by the Drishti backend',
                    ),
                    _buildInfoRow(
                      label: 'Generated AI Attention Maps',
                      value: 'Managed by the Drishti backend',
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Security & Session',
                  children: [
                    _buildInfoRow(
                      label: 'Signed in as',
                      value: doctor?.name ?? 'Doctor',
                    ),
                    _buildInfoRow(
                      label: 'Doctor ID',
                      value: doctor?.doctorId ?? 'N/A',
                    ),
                    _buildInfoRow(
                      label: 'Role',
                      value: (doctor?.role ?? 'Doctor')
                          .split('_')
                          .map(
                            (part) => part.isEmpty
                                ? part
                                : part[0].toUpperCase() + part.substring(1),
                          )
                          .join(' '),
                    ),
                    _buildInfoRow(label: 'Session', value: 'Active'),
                    _buildInfoRow(label: 'API Endpoint', value: _apiUrl),
                  ],
                ),
                _buildSection(
                  title: 'System Information',
                  children: [
                    _buildInfoRow(label: 'Application', value: 'Drishti'),
                    _buildInfoRow(label: 'Version', value: '1.0.0+1'),
                    _buildInfoRow(label: 'Platform', value: 'Windows'),
                    _buildInfoRow(label: 'Backend', value: 'FastAPI'),
                    _buildInfoRow(label: 'Database', value: 'SQLite'),
                    _buildInfoRow(label: 'AI Model', value: 'EfficientNet-B0'),
                    _buildInfoRow(label: 'Input Size', value: '224 × 224'),
                    _buildInfoRow(label: 'DR Classes', value: '5'),
                    _buildInfoRow(
                      label: 'Classes',
                      value:
                          'L0 — No DR • L1 — Mild • L2 — Moderate • L3 — Severe • L4 — Proliferative DR',
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Drishti',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17202A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'AI-assisted diabetic retinopathy screening support for clinicians.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'AI-assisted screening results are intended to support clinician review and do not constitute a definitive diagnosis.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _resetSettings,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Reset to Defaults'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17202A),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required String label,
    required String description,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF17202A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF17202A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        spacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF17202A),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required String label,
    required String value,
    required String description,
    required VoidCallback onPressed,
    required String buttonLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF17202A),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
