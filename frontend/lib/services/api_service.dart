import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    }
    try {
      if (Platform.isAndroid) {
        return "http://10.0.2.2:8000";
      }
    } catch (_) {}
    return "http://127.0.0.1:8000";
  }

  static Future<dynamic> generatePlan(
    Map<String, dynamic> requestBody,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/generate-plan"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      "Failed: ${response.statusCode}",
    );
  }

  static Future<dynamic> analyzeTopics(String subjectName) async {
    final response = await http.post(
      Uri.parse("$baseUrl/analyze-topics"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "subject_name": subjectName,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      "Failed: ${response.statusCode}",
    );
  }

  static Future<dynamic> getOnboardingStrategy(String course, String year) async {
    final response = await http.post(
      Uri.parse("$baseUrl/onboarding-strategy"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "course": course,
        "year": year,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      "Failed: ${response.statusCode}",
    );
  }
}
