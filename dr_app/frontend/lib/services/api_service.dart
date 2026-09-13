import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api/api_constants.dart';
import 'auth_service.dart';

class ApiService {
  static final String baseUrl = ApiConstants.baseUrl;

  static Future<Map<String, String>> _authHeaders({
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{};
    final token = AuthService.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  static Future<bool> checkHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    return response.statusCode == 200;
  }

  static Future<List<dynamic>> getPatients() async {
    final response = await http.get(
      Uri.parse('$baseUrl/patients'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load patients');
    }

    final data = jsonDecode(response.body);
    return data['patients'] ?? [];
  }

  static Future<Map<String, dynamic>> getPatient(String patientId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/patients/$patientId'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load patient');
    }

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCurrentDoctor() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please sign in again.');
    }
    if (response.statusCode != 200) {
      throw Exception('Unable to load your profile right now.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Malformed doctor profile response.');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> updateCurrentDoctor(
    Map<String, dynamic> profile,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/auth/me'),
      headers: {...await _authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode(profile),
    );

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please sign in again.');
    }
    if (response.statusCode == 400) {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Please correct the highlighted profile fields.';
      throw Exception(detail);
    }
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Unable to update the profile at the moment.';
      throw Exception(detail);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Malformed doctor update response.');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> createPatient({
    required String name,
    String? dateOfBirth,
    String? gender,
    String? phone,
    String? bloodGroup,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/patients'),
    );

    final token = AuthService.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['name'] = name;
    if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty) {
      request.fields['date_of_birth'] = dateOfBirth;
    }
    if (gender != null && gender.trim().isNotEmpty) {
      request.fields['gender'] = gender;
    }
    if (phone != null && phone.trim().isNotEmpty) {
      request.fields['phone'] = phone;
    }
    if (bloodGroup != null && bloodGroup.trim().isNotEmpty) {
      request.fields['blood_group'] = bloodGroup;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Unable to create patient.';
      throw Exception(detail);
    }

    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getPatientScreenings(String patientId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/patients/$patientId/screenings'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load patient screenings');
    }

    final data = jsonDecode(response.body);
    return data['screenings'] ?? [];
  }

  static Future<List<dynamic>> getScreenings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/screenings'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load screenings');
    }

    final data = jsonDecode(response.body);
    return data['screenings'] ?? [];
  }

  static Future<Map<String, dynamic>> getScreening(int screeningId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/screening/$screeningId'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load screening');
    }

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> analyzeScreening({
    required String patientId,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('The selected image file no longer exists.');
    }

    final lowerPath = file.path.toLowerCase();
    final mimeType = lowerPath.endsWith('.png')
        ? 'image/png'
        : lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')
        ? 'image/jpeg'
        : 'image/jpeg';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/screening/analyze'),
    );

    final token = AuthService.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['patient_id'] = patientId;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'fundus_image',
        contentType: http.MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        throw Exception('The AI analysis timed out. Please try again.');
      },
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Unable to analyze the retinal image.';
      throw Exception(detail);
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Malformed response from the Drishti backend.');
    }

    return data;
  }
}
