import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ConferenceService {
  static int activeConferenceId = 1;
  static List<dynamic> enrolledConferences = [];

  static Future<void> saveEnrolledConferences(List<dynamic> confs) async {
    enrolledConferences = confs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('enrolledConferences', jsonEncode(confs));
    if (confs.isNotEmpty) {
      final exists = confs.any((item) => (item['id'] is int ? item['id'] : int.tryParse(item['id'].toString())) == activeConferenceId);
      if (!exists) {
        activeConferenceId = confs[0]['id'] is int ? confs[0]['id'] : (int.tryParse(confs[0]['id'].toString()) ?? 1);
        await prefs.setInt('activeConferenceId', activeConferenceId);
      }
    }
  }

  static Future<void> loadSavedConferences() async {
    final prefs = await SharedPreferences.getInstance();
    activeConferenceId = prefs.getInt('activeConferenceId') ?? 1;
    final raw = prefs.getString('enrolledConferences');
    if (raw != null && raw.isNotEmpty) {
      try {
        enrolledConferences = jsonDecode(raw) as List<dynamic>;
      } catch (_) {}
    }
  }

  static Future<List<dynamic>> refreshEnrolledConferences() async {
    try {
      final res = await ApiService.get('/me/conferences');
      List<dynamic> confs = [];
      if (res is Map && res['data'] is List) {
        confs = res['data'] as List<dynamic>;
      } else if (res is List) {
        confs = res;
      }
      if (confs.isNotEmpty) {
        await saveEnrolledConferences(confs);
      }
      return enrolledConferences;
    } catch (_) {
      return enrolledConferences;
    }
  }

  static Future<void> switchConference(int conferenceId) async {
    activeConferenceId = conferenceId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('activeConferenceId', conferenceId);
  }
}

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
    await ConferenceService.loadSavedConferences();
    String formattedPath = path;
    if (!formattedPath.contains('conferenceId=')) {
      final connector = formattedPath.contains('?') ? '&' : '?';
      formattedPath = '$formattedPath${connector}conferenceId=${ConferenceService.activeConferenceId}';
    }

    final url = Uri.parse('$apiBaseUrl$formattedPath');

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

  static Future<Map<String, dynamic>> conference() async {
    final data = await get('/conference');

    if (data is! Map) {
      throw Exception('Invalid conference response from server');
    }

    if (data['success'] == true && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }

    return Map<String, dynamic>.from(data);
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

  static Future<dynamic> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$apiBaseUrl$path');

    print('PUT $url');
    print('BODY: $body');

    final response = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    print('PUT ${response.statusCode}: ${response.body}');

    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        _errorMessage(data, 'Request failed (${response.statusCode})'),
      );
    }

    return data;
  }

  static Future<dynamic> delete(String path) async {
    final url = Uri.parse('$apiBaseUrl$path');

    print('DELETE $url');

    final response = await http.delete(
      url,
      headers: await _headers(),
    );

    print('DELETE ${response.statusCode}: ${response.body}');

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

    if (data['enrolledConferences'] is List) {
      await ConferenceService.saveEnrolledConferences(data['enrolledConferences'] as List);
    }

    return Map<String, dynamic>.from(data);
  }
}
