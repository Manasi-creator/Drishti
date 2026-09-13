import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_constants.dart';

class DrishtiDoctor {
  const DrishtiDoctor({
    required this.doctorId,
    required this.name,
    required this.email,
    required this.role,
  });

  final String doctorId;
  final String name;
  final String email;
  final String role;

  factory DrishtiDoctor.fromJson(Map<String, dynamic> json) {
    return DrishtiDoctor(
      doctorId: (json['doctor_id'] ?? json['doctorId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'doctor').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'doctor_id': doctorId,
    'name': name,
    'email': email,
    'role': role,
  };
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _tokenKey = 'drishti_auth_token';
  static const String _doctorKey = 'drishti_auth_doctor';

  String? _token;
  DrishtiDoctor? _doctor;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);

    final doctorJson = prefs.getString(_doctorKey);
    if (doctorJson != null && doctorJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(doctorJson);
        if (decoded is Map<String, dynamic>) {
          _doctor = DrishtiDoctor.fromJson(decoded);
        }
      } catch (_) {
        _doctor = null;
      }
    }
  }

  String? get accessToken => _token;

  DrishtiDoctor? get currentDoctor => _doctor;

  bool get isAuthenticated => (_token ?? '').isNotEmpty && _doctor != null;

  Future<void> persistSession(String token, DrishtiDoctor doctor) async {
    final prefs = await SharedPreferences.getInstance();
    _token = token;
    _doctor = doctor;
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_doctorKey, jsonEncode(doctor.toJson()));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _token = null;
    _doctor = null;
    await prefs.remove(_tokenKey);
    await prefs.remove(_doctorKey);
  }

  Future<DrishtiDoctor> login({
    required String identifier,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Unable to connect to the Drishti backend. Please check that the backend server is running.';
      throw Exception(detail);
    }

    final decoded = jsonDecode(response.body);
    final doctorData = decoded['doctor'];
    final doctor = DrishtiDoctor.fromJson(doctorData);
    final token = decoded['token']?.toString() ?? '';

    if (token.isEmpty) {
      throw const FormatException('Authentication token missing from the backend response.');
    }

    await persistSession(token, doctor);
    return doctor;
  }
}
