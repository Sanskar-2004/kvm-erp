import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

class ApiService {
  final String baseUrl;
  String? _authToken;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  // ── Auth Token ───────────────────────────────────────────────────────

  void setAuthToken(String token) => _authToken = token;
  void clearAuthToken() => _authToken = null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // ── HTTP Methods ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http
        .get(Uri.parse('$baseUrl/$endpoint'), headers: _headers)
        .timeout(const Duration(seconds: AppConstants.apiTimeout));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: AppConstants.apiTimeout));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/$endpoint'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: AppConstants.apiTimeout));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/$endpoint'), headers: _headers)
        .timeout(const Duration(seconds: AppConstants.apiTimeout));
    return _handleResponse(response);
  }

  // ── Response Handler ─────────────────────────────────────────────────

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: body['message'] as String? ?? 'Unknown error',
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
