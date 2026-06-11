import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';

const _authBase = 'https://combitone.com/api';

class AuthService {
  static Future<String?> login(String phone, String password) async {
    final r = await http.post(
      Uri.parse('$_authBase/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    if (r.statusCode == 200) {
      final token = jsonDecode(r.body)['token'] as String?;
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt', token);
      }
      return token;
    }
    return null;
  }

  static Future<String?> savedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
  }

  static Future<VpnConfig?> fetchConfig(String token) async {
    final r = await http.get(
      Uri.parse('$_authBase/subscription'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 200) {
      return VpnConfig.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    }
    return null;
  }
}
