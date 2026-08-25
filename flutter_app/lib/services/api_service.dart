import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ApiService {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decode(String body) {
    if (body.isEmpty) {
      return {};
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  static String _errorMessage(dynamic data, String fallback) {
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }

    return fallback;
  }

  static Future<dynamic> get(String path) async {
    final url = Uri.parse('$apiBaseUrl$path');

    print('GET $url');

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    print('GET ${response.statusCode}: ${response.body}');

    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        _errorMessage(data, 'Request failed (${response.statusCode})'),
      );
    }

    return data;
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$apiBaseUrl$path');

    print('POST $url');
    print('BODY: $body');

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    print('POST ${response.statusCode}: ${response.body}');

    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        _errorMessage(data, 'Request failed (${response.statusCode})'),
      );
    }

    return data;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final url = Uri.parse('$apiBaseUrl/auth/login');

    print('LOGIN POST $url');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    print('LOGIN STATUS: ${response.statusCode}');
    print('LOGIN RESPONSE: ${response.body}');

    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        _errorMessage(data, 'Login failed (${response.statusCode})'),
      );
    }

    if (data is! Map) {
      throw Exception('Invalid login response from server');
    }

    return Map<String, dynamic>.from(data);
  }
}