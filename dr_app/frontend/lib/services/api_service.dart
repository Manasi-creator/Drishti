import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api/api_constants.dart';

class ApiService {
  static final String baseUrl = ApiConstants.baseUrl;

  static Future<bool> checkHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));

    return response.statusCode == 200;
  }

  static Future<List<dynamic>> getPatients() async {
    final response = await http.get(Uri.parse('$baseUrl/patients'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load patients');
    }

    final data = jsonDecode(response.body);

    return data['patients'] ?? [];
  }

  static Future<Map<String, dynamic>> getPatient(String patientId) async {
    final response = await http.get(Uri.parse('$baseUrl/patients/$patientId'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load patient');
    }

    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getPatientScreenings(String patientId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/patients/$patientId/screenings'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load patient screenings');
    }

    final data = jsonDecode(response.body);
    return data['screenings'] ?? [];
  }

  static Future<List<dynamic>> getScreenings() async {
    final response = await http.get(Uri.parse('$baseUrl/screenings'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load screenings');
    }

    final data = jsonDecode(response.body);

    return data['screenings'] ?? [];
  }
}
