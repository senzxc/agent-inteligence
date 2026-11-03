import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://163.128.212.19:5003';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static String? _token;
  static bool get hasSession => _token != null;

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> login(
    String stambuk,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'stambuk': stambuk, 'password': password}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Simpan token hanya jika login berhasil.
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true &&
        data['token'] != null) {
      _token = data['token'].toString();
    }

    return {'statusCode': response.statusCode, 'data': data};
  }

  static Future<void> saveSession(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak tersedia untuk disimpan.');
    }

    final preferences = await SharedPreferences.getInstance();
    final userSaved = await preferences.setString(_userKey, jsonEncode(user));
    final tokenSaved = await preferences.setString(_tokenKey, token);
    if (!userSaved || !tokenSaved) {
      await clearSession();
      throw Exception('Sesi login tidak dapat disimpan di perangkat.');
    }
  }

  static Future<Map<String, dynamic>?> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final encodedUser = preferences.getString(_userKey);

    if (token == null || token.isEmpty || encodedUser == null) {
      if (token != null || encodedUser != null) {
        await clearSession();
      }
      return null;
    }

    try {
      final decodedUser = jsonDecode(encodedUser);
      if (decodedUser is! Map) {
        throw const FormatException('Format data sesi tidak valid.');
      }

      _token = token;
      return Map<String, dynamic>.from(decodedUser);
    } on FormatException {
      await clearSession();
      return null;
    }
  }

  static Future<void> clearSession() async {
    _token = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_userKey);
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    if (_token == null) {
      throw Exception('Token belum tersedia. Silakan login ulang.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _authHeaders,
    );

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Format respons sesi tidak valid.');
    }

    if (response.statusCode == 401) {
      await clearSession();
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ?? 'Sesi login tidak dapat divalidasi.',
      );
    }

    final user = decoded['user'];
    if (user is! Map) {
      throw Exception('Data pengguna pada sesi tidak valid.');
    }

    return Map<String, dynamic>.from(user);
  }

  static Future<Map<String, dynamic>> getKantor() async {
    final response = await http.get(Uri.parse('$baseUrl/api/kantor'));

    return {
      'statusCode': response.statusCode,
      'data': jsonDecode(response.body),
    };
  }

  // Helper untuk request tracking.
  static Future<Map<String, dynamic>> _trackingRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    if (_token == null) {
      throw Exception('Token belum tersedia. Silakan login ulang.');
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = _authHeaders;

    late http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        );
        break;

      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Method API tidak didukung.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      final responseBody = response.body.trimLeft();
      final contentType = response.headers['content-type'] ?? '';
      if (responseBody.startsWith('<') ||
          !contentType.contains('application/json')) {
        throw Exception(
          'Server tidak mengembalikan JSON untuk ${uri.path} '
          '(HTTP ${response.statusCode}). Pastikan backend terbaru sudah '
          'dijalankan dan endpoint tersebut tersedia.',
        );
      }
      rethrow;
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Format respons API tracking tidak valid.');
    }
    final data = decoded;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ??
            'Request gagal (HTTP ${response.statusCode}).',
      );
    }

    if (data['success'] == false) {
      throw Exception(data['message']?.toString() ?? 'Request tracking gagal.');
    }

    return {'statusCode': response.statusCode, 'data': data};
  }

  static Future<Map<String, dynamic>> startTracking() {
    return _trackingRequest('POST', '/api/agent-tracking/start');
  }

  static Future<Map<String, dynamic>> getTrackingStatus() {
    return _trackingRequest('GET', '/api/agent-tracking/status');
  }

  static Future<Map<String, dynamic>> sendTrackingLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
    required double speed,
    bool isMocked = false,
  }) {
    return _trackingRequest(
      'POST',
      '/api/agent-tracking/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'isMocked': isMocked,
      },
    );
  }

  static Future<Map<String, dynamic>> stopTracking() {
    return _trackingRequest('POST', '/api/agent-tracking/stop');
  }

  static Future<Map<String, dynamic>> getAgents() {
    return _trackingRequest('GET', '/api/agent-tracking/agents');
  }

  static Future<Map<String, dynamic>> getDashboardAgentStats() {
    return _trackingRequest('GET', '/api/dashboard/agent-stats');
  }

  // Mengambil daftar seluruh agen dari endpoint /api/agents.
  static Future<Map<String, dynamic>> getAgentList({String? kantor}) =>
      getAgentProfiles(kantor: kantor);

  // ========================================
  // TUGAS AGEN
  // ========================================

  // Mengambil daftar tugas milik agen.
  static Future<Map<String, dynamic>> getAgentTasks(String agentId) {
    return _trackingRequest(
      'GET',
      '/api/agents/${Uri.encodeComponent(agentId)}/tasks',
    );
  }

  // Membuat tugas baru untuk agen.
  static Future<Map<String, dynamic>> createAgentTask({
    required String agentId,
    required String judul,
    required String deskripsi,
    required String tenggat,
  }) {
    return _trackingRequest(
      'POST',
      '/api/agents/${Uri.encodeComponent(agentId)}/tasks',
      body: {'judul': judul, 'deskripsi': deskripsi, 'tenggat': tenggat},
    );
  }

  // Memperbarui informasi tugas.
  static Future<Map<String, dynamic>> updateAgentTask({
    required String taskId,
    required String judul,
    required String deskripsi,
    required String tenggat,
  }) {
    return _trackingRequest(
      'PATCH',
      '/api/tasks/${Uri.encodeComponent(taskId)}',
      body: {'judul': judul, 'deskripsi': deskripsi, 'tenggat': tenggat},
    );
  }

  // Mengubah status tugas.
  static Future<Map<String, dynamic>> updateTaskStatus({
    required String taskId,
    required String status,
  }) {
    return _trackingRequest(
      'PATCH',
      '/api/tasks/${Uri.encodeComponent(taskId)}/status',
      body: {'status': status},
    );
  }

  // Menghapus tugas.
  static Future<Map<String, dynamic>> deleteTask(String taskId) {
    return _trackingRequest(
      'DELETE',
      '/api/tasks/${Uri.encodeComponent(taskId)}',
    );
  }

  static Future<Map<String, dynamic>> getAgentProfiles({
    String? search,
    String? jabatan,
    String? kantor,
  }) {
    final query = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (jabatan != null && jabatan.trim().isNotEmpty) {
      query['jabatan'] = jabatan.trim();
    }

    if (kantor != null && kantor.trim().isNotEmpty) {
      query['kantor'] = kantor.trim();
    }

    final queryString = query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';

    return _trackingRequest('GET', '/api/agents$queryString');
  }
}
