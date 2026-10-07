import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://163.128.212.19:5003';

  static Future<Map<String, dynamic>> login(
    String stambuk,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'stambuk': stambuk,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    return {
      'statusCode': response.statusCode,
      'data': data,
    };
  }
    static Future<Map<String, dynamic>> getKantor() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/kantor'),
    );

    final data = jsonDecode(response.body);

    return {
      'statusCode': response.statusCode,
      'data': data,
    };
  }
}