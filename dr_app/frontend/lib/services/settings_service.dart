import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.theme,
    required this.compactInterface,
    required this.showConfidence,
    required this.showAttentionMap,
    required this.imageQualityCheck,
    required this.reportFormat,
    required this.includeFundusImage,
    required this.includeAttentionMap,
    required this.includeClassProbabilities,
    required this.includeClinicalDisclaimer,
    required this.reportReviewReminder,
    required this.referableScreeningAlert,
    required this.referralThreshold,
  });

  final String theme;
  final bool compactInterface;
  final bool showConfidence;
  final bool showAttentionMap;
  final bool imageQualityCheck;
  final String reportFormat;
  final bool includeFundusImage;
  final bool includeAttentionMap;
  final bool includeClassProbabilities;
  final bool includeClinicalDisclaimer;
  final bool reportReviewReminder;
  final bool referableScreeningAlert;
  final String referralThreshold;

  factory AppSettings.defaults() {
    return const AppSettings(
      theme: 'Light',
      compactInterface: true,
      showConfidence: true,
      showAttentionMap: true,
      imageQualityCheck: true,
      reportFormat: 'A4',
      includeFundusImage: true,
      includeAttentionMap: true,
      includeClassProbabilities: true,
      includeClinicalDisclaimer: true,
      reportReviewReminder: true,
      referableScreeningAlert: true,
      referralThreshold: 'L2',
    );
  }

  AppSettings copyWith({
    String? theme,
    bool? compactInterface,
    bool? showConfidence,
    bool? showAttentionMap,
    bool? imageQualityCheck,
    String? reportFormat,
    bool? includeFundusImage,
    bool? includeAttentionMap,
    bool? includeClassProbabilities,
    bool? includeClinicalDisclaimer,
    bool? reportReviewReminder,
    bool? referableScreeningAlert,
    String? referralThreshold,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      compactInterface: compactInterface ?? this.compactInterface,
      showConfidence: showConfidence ?? this.showConfidence,
      showAttentionMap: showAttentionMap ?? this.showAttentionMap,
      imageQualityCheck: imageQualityCheck ?? this.imageQualityCheck,
      reportFormat: reportFormat ?? this.reportFormat,
      includeFundusImage: includeFundusImage ?? this.includeFundusImage,
      includeAttentionMap: includeAttentionMap ?? this.includeAttentionMap,
      includeClassProbabilities:
          includeClassProbabilities ?? this.includeClassProbabilities,
      includeClinicalDisclaimer:
          includeClinicalDisclaimer ?? this.includeClinicalDisclaimer,
      reportReviewReminder: reportReviewReminder ?? this.reportReviewReminder,
      referableScreeningAlert:
          referableScreeningAlert ?? this.referableScreeningAlert,
      referralThreshold: referralThreshold ?? this.referralThreshold,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'compactInterface': compactInterface,
      'showConfidence': showConfidence,
      'showAttentionMap': showAttentionMap,
      'imageQualityCheck': imageQualityCheck,
      'reportFormat': reportFormat,
      'includeFundusImage': includeFundusImage,
      'includeAttentionMap': includeAttentionMap,
      'includeClassProbabilities': includeClassProbabilities,
      'includeClinicalDisclaimer': includeClinicalDisclaimer,
      'reportReviewReminder': reportReviewReminder,
      'referableScreeningAlert': referableScreeningAlert,
      'referralThreshold': referralThreshold,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> map) {
    final theme = map['theme']?.toString() ?? 'Light';
    final reportFormat = map['reportFormat']?.toString() ?? 'A4';
    final referralThreshold = map['referralThreshold']?.toString() ?? 'L2';

    return AppSettings(
      theme: ['Light', 'Dark', 'System'].contains(theme) ? theme : 'Light',
      compactInterface: map['compactInterface'] is bool
          ? map['compactInterface'] as bool
          : true,
      showConfidence: map['showConfidence'] is bool
          ? map['showConfidence'] as bool
          : true,
      showAttentionMap: map['showAttentionMap'] is bool
          ? map['showAttentionMap'] as bool
          : true,
      imageQualityCheck: map['imageQualityCheck'] is bool
          ? map['imageQualityCheck'] as bool
          : true,
      reportFormat: ['A4', 'Letter'].contains(reportFormat)
          ? reportFormat
          : 'A4',
      includeFundusImage: map['includeFundusImage'] is bool
          ? map['includeFundusImage'] as bool
          : true,
      includeAttentionMap: map['includeAttentionMap'] is bool
          ? map['includeAttentionMap'] as bool
          : true,
      includeClassProbabilities: map['includeClassProbabilities'] is bool
          ? map['includeClassProbabilities'] as bool
          : true,
      includeClinicalDisclaimer: map['includeClinicalDisclaimer'] is bool
          ? map['includeClinicalDisclaimer'] as bool
          : true,
      reportReviewReminder: map['reportReviewReminder'] is bool
          ? map['reportReviewReminder'] as bool
          : true,
      referableScreeningAlert: map['referableScreeningAlert'] is bool
          ? map['referableScreeningAlert'] as bool
          : true,
      referralThreshold:
          ['L0', 'L1', 'L2', 'L3', 'L4'].contains(referralThreshold)
          ? referralThreshold
          : 'L2',
    );
  }
}

class AppReportSettings {
  const AppReportSettings({
    required this.pageFormat,
    required this.includeFundusImage,
    required this.includeAttentionMap,
    required this.includeClassProbabilities,
    required this.includeClinicalDisclaimer,
  });

  final String pageFormat;
  final bool includeFundusImage;
  final bool includeAttentionMap;
  final bool includeClassProbabilities;
  final bool includeClinicalDisclaimer;
}

class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  SharedPreferences? _prefs;
  AppSettings _settings = AppSettings.defaults();

  AppSettings get settings => _settings;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final rawConfig = _prefs!.getString('drishti_app_settings');

    if (rawConfig == null || rawConfig.isEmpty) {
      _settings = AppSettings.defaults();
      notifyListeners();
      return;
    }

    try {
      final decoded = Map<String, dynamic>.from(_decodeJson(rawConfig));
      _settings = AppSettings.fromJson(decoded);
    } catch (_) {
      _settings = AppSettings.defaults();
    }

    notifyListeners();
  }

  Future<void> _save() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(
        'drishti_app_settings',
        _encodeJson(_settings.toJson()),
      );
    } catch (_) {
      // Ignore storage failures and continue with in-memory settings.
    }
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_settings.theme) {
      case 'Dark':
        return ThemeMode.dark;
      case 'System':
        return ThemeMode.system;
      case 'Light':
      default:
        return ThemeMode.light;
    }
  }

  AppReportSettings get reportSettings => AppReportSettings(
    pageFormat: _settings.reportFormat,
    includeFundusImage: _settings.includeFundusImage,
    includeAttentionMap: _settings.includeAttentionMap,
    includeClassProbabilities: _settings.includeClassProbabilities,
    includeClinicalDisclaimer: _settings.includeClinicalDisclaimer,
  );

  bool get showConfidence => _settings.showConfidence;
  bool get showAttentionMap => _settings.showAttentionMap;
  bool get includeFundusImage => _settings.includeFundusImage;
  bool get includeClassProbabilities => _settings.includeClassProbabilities;
  bool get reportReviewReminder => _settings.reportReviewReminder;
  bool get referableScreeningAlert => _settings.referableScreeningAlert;
  String get referralThresholdLabel => _settings.referralThreshold;

  Future<void> setTheme(String theme) async {
    if (!['Light', 'Dark', 'System'].contains(theme)) {
      return;
    }
    _settings = _settings.copyWith(theme: theme);
    await _save();
  }

  Future<void> setCompactInterface(bool value) async {
    _settings = _settings.copyWith(compactInterface: value);
    await _save();
  }

  Future<void> setShowConfidence(bool value) async {
    _settings = _settings.copyWith(showConfidence: value);
    await _save();
  }

  Future<void> setShowAttentionMap(bool value) async {
    _settings = _settings.copyWith(showAttentionMap: value);
    await _save();
  }

  Future<void> setImageQualityCheck(bool value) async {
    _settings = _settings.copyWith(imageQualityCheck: value);
    await _save();
  }

  Future<void> setReportFormat(String value) async {
    if (!['A4', 'Letter'].contains(value)) {
      return;
    }
    _settings = _settings.copyWith(reportFormat: value);
    await _save();
  }

  Future<void> setIncludeFundusImage(bool value) async {
    _settings = _settings.copyWith(includeFundusImage: value);
    await _save();
  }

  Future<void> setIncludeAttentionMap(bool value) async {
    _settings = _settings.copyWith(includeAttentionMap: value);
    await _save();
  }

  Future<void> setIncludeClassProbabilities(bool value) async {
    _settings = _settings.copyWith(includeClassProbabilities: value);
    await _save();
  }

  Future<void> setReportReviewReminder(bool value) async {
    _settings = _settings.copyWith(reportReviewReminder: value);
    await _save();
  }

  Future<void> setReferableScreeningAlert(bool value) async {
    _settings = _settings.copyWith(referableScreeningAlert: value);
    await _save();
  }

  Future<void> setReferralThreshold(String value) async {
    if (!['L0', 'L1', 'L2', 'L3', 'L4'].contains(value)) {
      return;
    }
    _settings = _settings.copyWith(referralThreshold: value);
    await _save();
  }

  Future<void> resetToDefaults() async {
    _settings = AppSettings.defaults();
    await _save();
  }

  bool isScreeningReferable(Map<String, dynamic> screening) {
    final label = screening['dr_grade_label']?.toString() ?? '';
    final currentIndex = _gradeIndex(label);
    final thresholdIndex = _gradeIndex(_settings.referralThreshold);
    return currentIndex >= thresholdIndex;
  }

  int _gradeIndex(String gradeLabel) {
    final normalized = gradeLabel.trim().toUpperCase();
    if (normalized.contains('L4') || normalized.contains('PROLIFERATIVE')) {
      return 4;
    }
    if (normalized.contains('L3') || normalized.contains('SEVERE')) {
      return 3;
    }
    if (normalized.contains('L2') || normalized.contains('MODERATE')) {
      return 2;
    }
    if (normalized.contains('L1') || normalized.contains('MILD')) {
      return 1;
    }
    if (normalized.contains('L0') || normalized.contains('NO DR')) {
      return 0;
    }
    return 0;
  }

  String _encodeJson(Map<String, dynamic> value) {
    return jsonEncode(value);
  }

  Map<String, dynamic> _decodeJson(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      return <String, dynamic>{};
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
}
