import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _mrnController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
  final TextEditingController _yearsController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isEditing = false;
  String? _error;
  String? _successMessage;
  DrishtiDoctor? _doctor;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _mrnController.dispose();
    _specializationController.dispose();
    _qualificationController.dispose();
    _yearsController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getCurrentDoctor();
      final doctor = DrishtiDoctor.fromJson(
        response['doctor'] as Map<String, dynamic>,
      );
      final current = AuthService.instance.currentDoctor;
      if (current == null || current.doctorId != doctor.doctorId) {
        await AuthService.instance.persistSession(
          AuthService.instance.accessToken ?? '',
          doctor,
        );
      } else {
        await AuthService.instance.updateCurrentDoctor(doctor);
      }

      if (!mounted) return;
      setState(() {
        _doctor = doctor;
        _loading = false;
      });
      _populateControllers();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
      });
    }
  }

  void _populateControllers() {
    final doctor = _doctor;
    if (doctor == null) return;

    _nameController.text = doctor.name;
    _emailController.text = doctor.email;
    _phoneController.text = doctor.phone;
    _dobController.text = doctor.dateOfBirth;
    _genderController.text = doctor.gender;
    _mrnController.text = doctor.medicalRegistrationNumber;
    _specializationController.text = doctor.specialization;
    _qualificationController.text = doctor.qualification;
    _yearsController.text = doctor.yearsOfExperience.toString();
    _hospitalController.text = doctor.hospitalClinic;
  }

  void _resetControllers() {
    _populateControllers();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final doctor = _doctor;
    if (doctor == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final payload = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'date_of_birth': _dobController.text.trim(),
        'gender': _genderController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'qualification': _qualificationController.text.trim(),
        'years_of_experience': int.tryParse(_yearsController.text.trim()) ?? 0,
        'hospital_clinic': _hospitalController.text.trim(),
      };

      final response = await ApiService.updateCurrentDoctor(payload);
      final savedDoctor = DrishtiDoctor.fromJson(
        response['doctor'] as Map<String, dynamic>,
      );
      await AuthService.instance.updateCurrentDoctor(savedDoctor);

      if (!mounted) return;
      setState(() {
        _doctor = savedDoctor;
        _isEditing = false;
        _saving = false;
        _successMessage =
            response['message']?.toString() ?? 'Profile updated successfully.';
      });
      _populateControllers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_successMessage ?? 'Profile updated successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '').trim();
        _saving = false;
      });
    }
  }

  String? _requiredField(String? value, String fieldName) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Email is required.';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(normalized)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Phone number is required.';
    }
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  String? _yearsValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Years of experience is required.';
    }
    final years = int.tryParse(normalized);
    if (years == null || years < 0) {
      return 'Enter a non-negative number.';
    }
    return null;
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6F8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF17202A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final doctor = _doctor;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFDFF4F9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 38,
              color: Color(0xFF176B87),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor?.name ?? 'Doctor',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF17202A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Doctor ID: ${doctor?.doctorId ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF176B87),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    doctor?.role ?? 'Doctor',
                    style: const TextStyle(
                      color: Color(0xFF1F7A4B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 18),
          if (readOnly) ...children else ...children,
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    bool readOnly = false,
    TextInputType? keyboardType,
    int? maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
            minLines: 1,
            decoration: InputDecoration(
              filled: readOnly,
              fillColor: readOnly ? const Color(0xFFF3F6F8) : Colors.white,
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: readOnly
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: readOnly
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyPage() {
    final doctor = _doctor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileHeader(),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth > 1100 ? 2 : 1;
            final itemWidth =
                (constraints.maxWidth - (columnCount - 1) * 20) / columnCount;

            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _buildSectionCard(
                    title: 'Identity Information',
                    readOnly: true,
                    children: [
                      _buildReadOnlyRow('Doctor ID', doctor?.doctorId ?? 'N/A'),
                      _buildReadOnlyRow('Full Name', doctor?.name ?? 'N/A'),
                      _buildReadOnlyRow('Email', doctor?.email ?? 'N/A'),
                      _buildReadOnlyRow('Phone Number', doctor?.phone ?? 'N/A'),
                      _buildReadOnlyRow(
                        'Date of Birth',
                        doctor?.dateOfBirth ?? 'N/A',
                      ),
                      _buildReadOnlyRow('Gender', doctor?.gender ?? 'N/A'),
                    ],
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildSectionCard(
                    title: 'Professional Information',
                    readOnly: true,
                    children: [
                      _buildReadOnlyRow(
                        'Medical Registration Number',
                        doctor?.medicalRegistrationNumber ?? 'N/A',
                      ),
                      _buildReadOnlyRow(
                        'Specialization',
                        doctor?.specialization ?? 'N/A',
                      ),
                      _buildReadOnlyRow(
                        'Qualification',
                        doctor?.qualification ?? 'N/A',
                      ),
                      _buildReadOnlyRow(
                        'Years of Experience',
                        doctor?.yearsOfExperience.toString() ?? '0',
                      ),
                      _buildReadOnlyRow(
                        'Hospital / Clinic',
                        doctor?.hospitalClinic ?? 'N/A',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildSectionCard(
                    title: 'Account Information',
                    readOnly: true,
                    children: [
                      _buildReadOnlyRow('Role', doctor?.role ?? 'Doctor'),
                      _buildReadOnlyRow(
                        'Account Status',
                        doctor?.isActive == true ? 'Active' : 'Inactive',
                      ),
                      _buildReadOnlyRow(
                        'Account Created',
                        doctor?.createdAt.isNotEmpty == true
                            ? (doctor?.createdAt ?? 'N/A')
                            : 'N/A',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEditPage() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth > 1100 ? 2 : 1;
              final itemWidth =
                  (constraints.maxWidth - (columnCount - 1) * 20) / columnCount;

              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildSectionCard(
                      title: 'Identity Information',
                      children: [
                        _buildField(
                          'Doctor ID',
                          TextEditingController(
                            text: _doctor?.doctorId ?? 'N/A',
                          ),
                          readOnly: true,
                        ),
                        _buildField(
                          'Full Name',
                          _nameController,
                          validator: (value) =>
                              _requiredField(value, 'Full Name'),
                        ),
                        _buildField(
                          'Email',
                          _emailController,
                          validator: _emailValidator,
                        ),
                        _buildField(
                          'Phone Number',
                          _phoneController,
                          validator: _phoneValidator,
                          keyboardType: TextInputType.phone,
                        ),
                        _buildField(
                          'Date of Birth',
                          _dobController,
                          validator: (value) =>
                              _requiredField(value, 'Date of Birth'),
                        ),
                        _buildField(
                          'Gender',
                          _genderController,
                          validator: (value) => _requiredField(value, 'Gender'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildSectionCard(
                      title: 'Professional Information',
                      children: [
                        _buildField(
                          'Medical Registration Number',
                          _mrnController,
                          readOnly: true,
                          validator: (value) => _requiredField(
                            value,
                            'Medical Registration Number',
                          ),
                        ),
                        _buildField(
                          'Specialization',
                          _specializationController,
                          validator: (value) =>
                              _requiredField(value, 'Specialization'),
                        ),
                        _buildField(
                          'Qualification',
                          _qualificationController,
                          validator: (value) =>
                              _requiredField(value, 'Qualification'),
                        ),
                        _buildField(
                          'Years of Experience',
                          _yearsController,
                          validator: _yearsValidator,
                          keyboardType: TextInputType.number,
                        ),
                        _buildField(
                          'Hospital / Clinic',
                          _hospitalController,
                          validator: (value) =>
                              _requiredField(value, 'Hospital / Clinic'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildSectionCard(
                      title: 'Account Information',
                      children: [
                        _buildField(
                          'Role',
                          TextEditingController(
                            text: _doctor?.role ?? 'Doctor',
                          ),
                          readOnly: true,
                        ),
                        _buildField(
                          'Account Status',
                          TextEditingController(
                            text: _doctor?.isActive == true
                                ? 'Active'
                                : 'Inactive',
                          ),
                          readOnly: true,
                        ),
                        _buildField(
                          'Account Created',
                          TextEditingController(
                            text: _doctor?.createdAt ?? 'N/A',
                          ),
                          readOnly: true,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF123B4A),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'DRISHTI',
              style: TextStyle(
                color: Color(0xFF123B4A),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Doctor Profile',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF17202A),
                            ),
                          ),
                        ),
                        if (!_isEditing)
                          FilledButton.icon(
                            onPressed: () {
                              _resetControllers();
                              setState(() {
                                _isEditing = true;
                                _error = null;
                                _successMessage = null;
                              });
                            },
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('Edit Profile'),
                          )
                        else
                          Row(
                            children: [
                              TextButton(
                                onPressed: _saving
                                    ? null
                                    : () {
                                        _resetControllers();
                                        setState(() {
                                          _isEditing = false;
                                          _error = null;
                                          _successMessage = null;
                                        });
                                      },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: _saving ? null : _saveProfile,
                                child: _saving
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Saving...'),
                                        ],
                                      )
                                    : const Text('Save Changes'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadProfile,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    if (_successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _isEditing
                            ? _buildEditPage()
                            : _buildReadOnlyPage(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
