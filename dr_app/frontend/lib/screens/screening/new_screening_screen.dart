import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_constants.dart';
import '../../services/api_service.dart';
import '../reports/report_detail_screen.dart';

bool parseBooleanFlag(dynamic value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }

  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return false;
}

class NewScreeningScreen extends StatefulWidget {
  const NewScreeningScreen({super.key});

  @override
  State<NewScreeningScreen> createState() => _NewScreeningScreenState();
}

class _NewScreeningScreenState extends State<NewScreeningScreen> {
  final TextEditingController _patientSearchController =
      TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _newPatientFormKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _allPatients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  Map<String, dynamic>? _selectedPatient;
  String? _selectedImagePath;
  String? _selectedImageName;
  Map<String, dynamic>? _analysisResult;
  bool _loadingPatients = true;
  bool _creatingPatient = false;
  bool _isAnalyzing = false;
  bool _showCreatePatientForm = false;
  bool _qualityFailure = false;
  String? _screeningError;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _patientNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loadingPatients = true;
      _screeningError = null;
    });

    try {
      final patientList = await ApiService.getPatients();
      final patients = patientList
          .map<Map<String, dynamic>>(
            (patient) => Map<String, dynamic>.from(patient as Map),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _allPatients = patients;
        _filteredPatients = patients;
        _loadingPatients = false;
      });
      _applyPatientFilter();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _screeningError = _formatException(error, 'Unable to load patients.');
        _loadingPatients = false;
      });
    }
  }

  void _applyPatientFilter() {
    final query = _patientSearchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredPatients = _allPatients;
      });
      return;
    }

    final matches = _allPatients.where((patient) {
      final patientId = (patient['patient_id'] ?? '').toString().toLowerCase();
      final name = (patient['name'] ?? '').toString().toLowerCase();
      return patientId.contains(query) || name.contains(query);
    }).toList();

    setState(() {
      _filteredPatients = matches;
    });
  }

  Future<void> _pickFundusImage() async {
    try {
      final result = await FilePicker.pickFile(type: FileType.image);

      if (result == null) {
        return;
      }

      final path = result.path;

      if (path == null || path.isEmpty) {
        setState(() {
          _screeningError = 'No image path was returned. Please try again.';
        });
        return;
      }

      final validationMessage = await _validateImageFile(path);
      if (validationMessage != null) {
        setState(() {
          _screeningError = validationMessage;
          _selectedImagePath = null;
          _selectedImageName = null;
        });
        return;
      }

      setState(() {
        _selectedImagePath = path;
        _selectedImageName = result.name;
        _screeningError = null;
        _qualityFailure = false;
      });
    } catch (error) {
      setState(() {
        _screeningError = _formatException(
          error,
          'Unable to access the selected image.',
        );
      });
    }
  }

  Future<String?> _validateImageFile(String path) async {
    final file = File(path);

    if (!file.existsSync()) {
      return 'Please select a valid fundus image file.';
    }

    final extension = path.toLowerCase();
    if (!extension.endsWith('.jpg') &&
        !extension.endsWith('.jpeg') &&
        !extension.endsWith('.png')) {
      return 'Unsupported image format. Please upload a JPG, JPEG, or PNG image.';
    }

    try {
      final size = await file.length();
      if (size <= 0) {
        return 'The selected image is empty. Please choose a readable fundus image.';
      }

      if (size > 25 * 1024 * 1024) {
        return 'The selected image is too large. Please choose a fundus image under 25 MB.';
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return 'The selected image could not be read. Please choose a different file.';
      }

      await decodeImageFromList(bytes);
    } catch (_) {
      return 'The selected image could not be read. Please choose a valid retinal image.';
    }

    return null;
  }

  Future<void> _createPatient() async {
    final isValid = _newPatientFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _creatingPatient = true;
      _screeningError = null;
    });

    try {
      final result = await ApiService.createPatient(
        name: _patientNameController.text.trim(),
        dateOfBirth: _dobController.text.trim().isEmpty
            ? null
            : _dobController.text.trim(),
        gender: _selectedGenderValue(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        bloodGroup: _selectedBloodGroupValue(),
      );

      final patientId = result['patient_id']?.toString();
      if (patientId == null || patientId.isEmpty) {
        throw Exception('Patient created without a patient ID.');
      }

      await _loadPatients();

      final createdPatient = {
        'patient_id': patientId,
        'name': _patientNameController.text.trim(),
        'date_of_birth': _dobController.text.trim(),
        'gender': _selectedGenderValue(),
        'phone': _phoneController.text.trim(),
        'blood_group': _selectedBloodGroupValue(),
      };

      if (!mounted) return;

      setState(() {
        _selectedPatient = createdPatient;
        _showCreatePatientForm = false;
        _patientNameController.clear();
        _dobController.clear();
        _phoneController.clear();
        _qualificationGender = null;
        _qualificationBloodGroup = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient created successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _screeningError = _formatException(error, 'Unable to create patient.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingPatient = false;
        });
      }
    }
  }

  String? _selectedGenderValue() {
    return _qualificationGender?.trim().isNotEmpty == true
        ? _qualificationGender
        : null;
  }

  String? _selectedBloodGroupValue() {
    return _qualificationBloodGroup?.trim().isNotEmpty == true
        ? _qualificationBloodGroup
        : null;
  }

  String? _qualificationGender;
  String? _qualificationBloodGroup;

  Future<void> _analyzeScreening() async {
    if (_selectedPatient == null) {
      setState(() {
        _screeningError = 'Please select or create a patient first.';
      });
      return;
    }

    final patientId = (_selectedPatient!['patient_id'] ?? '').toString();
    if (patientId.isEmpty) {
      setState(() {
        _screeningError = 'Please select or create a patient first.';
      });
      return;
    }

    if (_selectedImagePath == null || !File(_selectedImagePath!).existsSync()) {
      setState(() {
        _screeningError = 'Please select a fundus image before analysis.';
      });
      return;
    }

    final validationMessage = await _validateImageFile(_selectedImagePath!);
    if (validationMessage != null) {
      setState(() {
        _screeningError = validationMessage;
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _screeningError = null;
      _analysisResult = null;
      _qualityFailure = false;
    });

    try {
      final result = await ApiService.analyzeScreening(
        patientId: patientId,
        filePath: _selectedImagePath!,
      );

      final isQualityFailure = _resultIsQualityFailure(result);
      if (isQualityFailure) {
        setState(() {
          _qualityFailure = true;
          _analysisResult = result;
          _screeningError = _resultQualityReason(result);
        });
        return;
      }

      setState(() {
        _qualityFailure = false;
        _analysisResult = result;
      });
    } catch (error) {
      setState(() {
        _screeningError = _formatException(
          error,
          'Unable to analyze the retinal image. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  bool _resultIsQualityFailure(Map<String, dynamic> result) {
    final status = (result['status'] ?? '').toString().toLowerCase();
    if (status == 'quality_failed') {
      return true;
    }

    final quality = result['quality'];
    if (quality is Map) {
      final acceptable = parseBooleanFlag(quality['acceptable']);
      if (!acceptable) {
        return true;
      }
      final acceptableAlt = parseBooleanFlag(quality['quality_acceptable']);
      if (!acceptableAlt) {
        return true;
      }
    }

    final rootFlag = parseBooleanFlag(result['quality_acceptable']);
    if (!rootFlag) {
      return true;
    }

    return false;
  }

  String _resultQualityReason(Map<String, dynamic> result) {
    final quality = result['quality'];
    if (quality is Map) {
      final reason = quality['reason'];
      if (reason != null && reason.toString().trim().isNotEmpty) {
        return reason.toString();
      }
    }

    final fallback = result['quality_reason'];
    if (fallback != null && fallback.toString().trim().isNotEmpty) {
      return fallback.toString();
    }

    return 'The image appears unsuitable for reliable analysis.';
  }

  void _resetScreeningWorkflow() {
    setState(() {
      _selectedPatient = null;
      _selectedImagePath = null;
      _selectedImageName = null;
      _analysisResult = null;
      _qualityFailure = false;
      _screeningError = null;
      _patientSearchController.clear();
      _filteredPatients = _allPatients;
    });
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? '--' : text;
  }

  String _formatException(Object error, String fallback) {
    final message = error.toString();
    final cleaned = message.startsWith('Exception: ')
        ? message.replaceFirst('Exception: ', '')
        : message;
    return cleaned.trim().isEmpty ? fallback : cleaned.trim();
  }

  String _normalizeGradeLabel(dynamic value) {
    final label = (value ?? '').toString().trim();
    if (label.isEmpty) {
      return 'Unspecified';
    }
    final lower = label.toLowerCase();
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
    return label;
  }

  bool _isReferable(Map<String, dynamic> result) {
    final prediction = result['prediction'];
    final referable = prediction is Map
        ? prediction['referable']
        : result['referable'];
    final normalized = parseBooleanFlag(referable);
    if (normalized) {
      return true;
    }
    if (referable is num) {
      return referable == 1;
    }
    return false;
  }

  String _formatConfidence(dynamic value) {
    if (value is num) {
      final percentage = value * 100.0;
      return '${percentage.toStringAsFixed(1)}%';
    }
    return '--';
  }

  String _getImageUrl(String? relativePath) {
    final path = relativePath?.trim();
    if (path == null || path.isEmpty) {
      return '';
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${ApiConstants.baseUrl}$normalized';
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
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<MapEntry<String, double>> _buildProbabilityEntries(
    Map<String, dynamic> result,
  ) {
    final prediction = result['prediction'];
    final map = prediction is Map
        ? Map<String, dynamic>.from(
            prediction['class_probabilities'] is Map
                ? prediction['class_probabilities'] as Map
                : {},
          )
        : <String, dynamic>{};

    final probabilities = _normalizeProbabilities(
      prediction is Map
          ? prediction['class_probabilities']
          : result['class_probabilities'],
    );

    final orderedLabels = ['L0', 'L1', 'L2', 'L3', 'L4'];
    return orderedLabels.map((label) {
      final keyCandidates = [label.toLowerCase(), label];
      dynamic value;
      for (final key in keyCandidates) {
        value = probabilities[key];
        if (value != null) {
          break;
        }
      }
      if (value == null && map.isNotEmpty) {
        final fallback = map.entries.where((entry) {
          final key = entry.key.toString().toLowerCase();
          return key.contains(label.toLowerCase().replaceFirst('l', '')) ||
              key.contains(label.toLowerCase());
        }).firstOrNull;
        value = fallback?.value;
      }
      final doubleValue = value is num ? value.toDouble() : 0.0;
      return MapEntry(label, doubleValue * 100.0);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final patientName = _selectedPatient?['name'] ?? '--';
    final patientId = _selectedPatient?['patient_id'] ?? '--';
    final patientDob = _selectedPatient?['date_of_birth'] ?? '--';
    final patientGender = _selectedPatient?['gender'] ?? '--';
    final patientBloodGroup = _selectedPatient?['blood_group'] ?? '--';
    final patientPhone = _selectedPatient?['phone'] ?? '--';

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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 60,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Screening',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF17202A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create an AI-assisted retinal screening for a patient.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 28),
                _buildSectionCard(
                  title: 'Patient',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _patientSearchController,
                        onChanged: (_) => _applyPatientFilter(),
                        decoration: InputDecoration(
                          hintText:
                              'Search existing patient by name or patient ID',
                          prefixIcon: const Icon(Icons.search_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showCreatePatientForm = !_showCreatePatientForm;
                              _screeningError = null;
                            });
                          },
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('+ Create New Patient'),
                        ),
                      ),
                      if (_showCreatePatientForm) ...[
                        const SizedBox(height: 8),
                        Form(
                          key: _newPatientFormKey,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _patientNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Patient Name *',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Patient name is required.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _dobController,
                                  decoration: const InputDecoration(
                                    labelText: 'Date of Birth',
                                  ),
                                  keyboardType: TextInputType.datetime,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Gender',
                                  ),
                                  initialValue: _qualificationGender,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Male',
                                      child: Text('Male'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Female',
                                      child: Text('Female'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Other',
                                      child: Text('Other'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Prefer not to say',
                                      child: Text('Prefer not to say'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _qualificationGender = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone',
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Blood Group',
                                  ),
                                  initialValue: _qualificationBloodGroup,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'A+',
                                      child: Text('A+'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'A-',
                                      child: Text('A-'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'B+',
                                      child: Text('B+'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'B-',
                                      child: Text('B-'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'AB+',
                                      child: Text('AB+'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'AB-',
                                      child: Text('AB-'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'O+',
                                      child: Text('O+'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'O-',
                                      child: Text('O-'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _qualificationBloodGroup = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _creatingPatient
                                        ? null
                                        : _createPatient,
                                    child: _creatingPatient
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Save Patient'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (_loadingPatients)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_filteredPatients.isEmpty)
                        const Text(
                          'No matching patients found.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _filteredPatients.length,
                            itemBuilder: (context, index) {
                              final patient = _filteredPatients[index];
                              final isSelected =
                                  _selectedPatient?['patient_id'] ==
                                  patient['patient_id'];
                              return Material(
                                color: isSelected
                                    ? const Color(0xFFE8F4F7)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    setState(() {
                                      _selectedPatient =
                                          Map<String, dynamic>.from(patient);
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(
                                            0xFF176B87,
                                          ),
                                          child: Text(
                                            (patient['name'] ?? 'P')
                                                .toString()[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _safeText(patient['name']),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'ID: ${_safeText(patient['patient_id'])}',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF176B87),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 6),
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (_selectedPatient != null) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Selected Patient',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 18,
                          runSpacing: 10,
                          children: [
                            _summaryField('Name', patientName),
                            _summaryField('Patient ID', patientId),
                            _summaryField('Date of birth', patientDob),
                            _summaryField('Gender', patientGender),
                            _summaryField('Blood group', patientBloodGroup),
                            _summaryField('Phone', patientPhone),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buildSectionCard(
                  title: 'Fundus Image',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _pickFundusImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFB8DDE8),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                            color: const Color(0xFFEAF7FB),
                          ),
                          child: _selectedImagePath == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.upload_file_outlined,
                                      size: 42,
                                      color: Color(0xFF176B87),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Upload Fundus Image',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF123B4A),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Select a retinal/fundus image for AI-assisted screening.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'JPG / JPEG / PNG',
                                      style: TextStyle(
                                        color: Color(0xFF176B87),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(_selectedImagePath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                        ),
                      ),
                      if (_selectedImagePath != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedImageName ?? 'Selected image',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickFundusImage,
                              icon: const Icon(Icons.swap_horiz_outlined),
                              label: const Text('Change Image'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedImagePath = null;
                                  _selectedImageName = null;
                                  _screeningError = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove Image'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (_screeningError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEA4A4)),
                    ),
                    child: Text(
                      _screeningError!,
                      style: const TextStyle(color: Color(0xFF8A1F1F)),
                    ),
                  ),
                if (_screeningError != null) const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeScreening,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _isAnalyzing
                          ? 'Analyzing retinal image...'
                          : 'Analyze Screening',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF176B87),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_analysisResult != null) ...[
                  const SizedBox(height: 28),
                  if (_qualityFailure)
                    _buildQualityFailurePanel()
                  else
                    _buildResultPanel(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualityFailurePanel() {
    final qualityReason = _resultQualityReason(_analysisResult!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Image Quality Check Failed',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            qualityReason,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedImagePath = null;
                  _selectedImageName = null;
                  _analysisResult = null;
                  _qualityFailure = false;
                  _screeningError = null;
                });
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Another Image'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    final result = _analysisResult ?? {};
    final prediction = result['prediction'] is Map
        ? Map<String, dynamic>.from(result['prediction'] as Map)
        : <String, dynamic>{};
    final label = _normalizeGradeLabel(
      prediction['label'] ?? result['dr_grade_label'] ?? result['grade_label'],
    );
    final confidence = _formatConfidence(
      prediction['confidence'] ?? result['confidence'],
    );
    final referable = _isReferable(result) ? 'Referable' : 'Non-referable';
    final quality =
        (parseBooleanFlag(result['quality_acceptable']) ||
            (result['quality'] is Map &&
                parseBooleanFlag(result['quality']['acceptable'])))
        ? 'Acceptable'
        : 'Acceptable';

    final originalImage = _getImageUrl(
      (result['files'] is Map ? result['files']['original_image'] : null) ??
              result['stored_filename'] == null
          ? null
          : '/uploads/${result['stored_filename']}',
    );
    final heatmapImage = _getImageUrl(
      (result['files'] is Map ? result['files']['heatmap'] : null) ??
              result['heatmap_filename'] == null
          ? null
          : '/heatmaps/${result['heatmap_filename']}',
    );

    final screeningId = result['screening_id'];
    final probabilityEntries = _buildProbabilityEntries(result);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Screening Complete',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI-Assisted Screening Result',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _resultStatCard(
                  'DR Grade',
                  label,
                  Icons.remove_red_eye_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _resultStatCard(
                  'Confidence',
                  confidence,
                  Icons.percent_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _resultStatCard(
                  'Referral Status',
                  referable,
                  Icons.warning_amber_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _resultStatCard(
                  'Image Quality',
                  quality,
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'This result is intended to support clinician review and does not constitute a definitive diagnosis.',
            style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 12),
          Text(
            _isReferable(result)
                ? 'The AI-assisted screening result meets the configured referral threshold. Clinical evaluation by an appropriately qualified eye-care professional should be considered.'
                : 'The AI-assisted screening result does not meet the configured referral threshold. This result should be interpreted within the appropriate clinical screening protocol.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 24),
          if (originalImage.isNotEmpty || heatmapImage.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (originalImage.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Original Fundus Image',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            originalImage,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 220,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  height: 220,
                                  child: Center(
                                    child: Text('Image unavailable'),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (heatmapImage.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Attention Map',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI attention map — highlights retinal regions that contributed most to the model\'s prediction.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            heatmapImage,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 220,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  height: 220,
                                  child: Center(
                                    child: Text('Heatmap unavailable'),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 24),
          const Text(
            'Class Probabilities',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: probabilityEntries.map((entry) {
              return SizedBox(
                width: 180,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.key} — ${_labelForProbability(entry.key)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('${entry.value.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (screeningId != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ReportDetailScreen(
                          screeningId:
                              int.tryParse(screeningId.toString()) ?? 0,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('View Report'),
                ),
              ElevatedButton.icon(
                onPressed: _resetScreeningWorkflow,
                icon: const Icon(Icons.refresh),
                label: const Text('New Screening'),
              ),
            ],
          ),
        ],
      ),
    );
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

  Widget _resultStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF176B87)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryField(String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              fontWeight: FontWeight.bold,
              color: Color(0xFF17202A),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
