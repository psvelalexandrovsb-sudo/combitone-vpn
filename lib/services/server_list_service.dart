import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_endpoint.dart';
import 'logger.dart';

const _configUrl = 'https://api.munofit.ru/app/config';
const _cacheKey = 'server_config_json';
const _timeout = Duration(seconds: 10);

/// Результат загрузки списка серверов.
class ServerListResult {
  /// «Наши» серверы (секция "our" в JSON).
  final List<VpnEndpoint> our;

  /// Публичные / резервные серверы (секция "public" в JSON).
  final List<VpnEndpoint> public;

  /// true — данные из кэша, false — свежие с сети.
  final bool fromCache;

  const ServerListResult({
    required this.our,
    required this.public,
    this.fromCache = false,
  });

  bool get isEmpty => our.isEmpty && public.isEmpty;
}

class ServerListService {
  /// Загрузить из кэша (SharedPreferences).
  /// Возвращает null, если кэша нет или он пустой.
  static Future<ServerListResult?> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final result = _parse(raw, fromCache: true);
      AppLogger.log(
          'ServerList: кэш our=${result.our.length} public=${result.public.length}');
      return result.isEmpty ? null : result;
    } catch (e) {
      AppLogger.log('ServerList: ошибка кэша — $e');
      return null;
    }
  }

  /// Запросить с сети, обновить кэш. Возвращает null при ошибке.
  static Future<ServerListResult?> fetchAndUpdate() async {
    try {
      AppLogger.log('ServerList: GET $_configUrl');
      final r = await http.get(Uri.parse(_configUrl)).timeout(_timeout);
      if (r.statusCode != 200) {
        AppLogger.log('ServerList: HTTP ${r.statusCode}');
        return null;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, r.body);
      final result = _parse(r.body);
      AppLogger.log(
          'ServerList: обновлён our=${result.our.length} public=${result.public.length}');
      return result.isEmpty ? null : result;
    } catch (e) {
      AppLogger.log('ServerList: сеть — $e');
      return null;
    }
  }

  static ServerListResult _parse(String raw, {bool fromCache = false}) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;

      List<VpnEndpoint> parseSection(String key) {
        final arr = json[key];
        if (arr is! List) return [];
        return arr
            .whereType<Map<String, dynamic>>()
            .where((m) =>
                m['id'] is String &&
                (m['id'] as String).isNotEmpty &&
                m['server'] is String &&
                (m['server'] as String).isNotEmpty)
            .map(VpnEndpoint.fromJson)
            .toList();
      }

      return ServerListResult(
        our: parseSection('our'),
        public: parseSection('public'),
        fromCache: fromCache,
      );
    } catch (e) {
      AppLogger.log('ServerList: парсинг — $e');
      return const ServerListResult(our: [], public: []);
    }
  }
}
