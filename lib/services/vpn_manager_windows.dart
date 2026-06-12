import 'package:flutter/foundation.dart';
import '../models/vpn_config.dart';
import 'auth_service.dart';
import 'singbox_runner.dart';

enum VpnStatus { disconnected, connecting, connected, error }

class VpnManagerWindows extends ChangeNotifier {
  final _singbox = SingboxRunner();
  VpnStatus _status = VpnStatus.disconnected;
  String? _error;
  VpnConfig? _config;
  VpnLayer _selectedLayer = VpnLayer.reality;
  String? _token;
  List<String> _exclusions = [];
  bool _initializing = true;

  VpnStatus get status => _status;
  String? get error => _error;
  VpnConfig? get config => _config;
  VpnLayer get selectedLayer => _selectedLayer;
  bool get isConnected => _status == VpnStatus.connected;
  bool get isAuthenticated => _config != null;
  bool get isInitializing => _initializing;
  List<String> get exclusions => _exclusions;

  Future<void> init() async {
    _initializing = true;
    _token = await AuthService.savedToken();
    if (_token != null) {
      _config = await AuthService.fetchConfig(_token!);
      if (_config == null) {
        // Токен устарел или сервер недоступен — сбрасываем
        await AuthService.logout();
        _token = null;
      }
    }
    _initializing = false;
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    _token = await AuthService.login(phone, password);
    if (_token == null) return false;
    _config = await AuthService.fetchConfig(_token!);
    if (_config == null) {
      await AuthService.logout();
      _token = null;
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await disconnect();
    await AuthService.logout();
    _token = null;
    _config = null;
    notifyListeners();
  }

  void selectLayer(VpnLayer layer) {
    _selectedLayer = layer;
    notifyListeners();
  }

  Future<void> connect() async {
    if (_config == null) return;
    _status = VpnStatus.connecting;
    _error = null;
    notifyListeners();

    final profile = _config!.profiles.firstWhere(
      (p) => p.layer == _selectedLayer,
      orElse: () => _config!.profiles.first,
    );

    final singboxConfig = _buildSingboxConfig(profile);
    final ok = await _singbox.start(singboxConfig);
    if (ok) {
      _status = VpnStatus.connected;
    } else {
      _status = VpnStatus.error;
      _error = 'Не удалось запустить sing-box. Запустите приложение от имени администратора.';
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _singbox.stop();
    _status = VpnStatus.disconnected;
    notifyListeners();
  }

  void addExclusion(String host) {
    if (!_exclusions.contains(host)) {
      _exclusions = [..._exclusions, host];
      notifyListeners();
    }
  }

  void removeExclusion(String host) {
    _exclusions = _exclusions.where((e) => e != host).toList();
    notifyListeners();
  }

  Map<String, dynamic> _buildSingboxConfig(VpnProfile profile) {
    return {
      'log': {'level': 'warn'},
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'address': ['172.19.0.1/30'],
          'auto_route': true,
          'strict_route': false,
        }
      ],
      'outbounds': [
        _buildOutbound(profile),
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
      ],
      'route': {
        'rules': [
          {
            'ip_cidr': ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '127.0.0.0/8'],
            'outbound': 'direct'
          },
          if (_exclusions.isNotEmpty)
            {'domain': _exclusions, 'outbound': 'direct'},
        ],
        'final': switch (profile.layer) {
          VpnLayer.reality => 'vless-out',
          VpnLayer.xhttp => 'xhttp-out',
          VpnLayer.hysteria2 => 'hy2-out',
        },
      }
    };
  }

  Map<String, dynamic> _buildOutbound(VpnProfile profile) {
    final p = profile.params;
    final sniPool = _config?.sniPool ?? [];
    final sni = sniPool.isNotEmpty ? (sniPool..shuffle()).first : profile.server;

    switch (profile.layer) {
      case VpnLayer.reality:
        // API: reality.publicKey (string), reality.shortIds (List)
        final realityMap = (p['reality'] as Map?)?.cast<String, dynamic>() ?? {};
        final shortIds = (realityMap['shortIds'] as List?)?.cast<String>() ?? [];
        return {
          'type': 'vless',
          'tag': 'vless-out',
          'server': profile.server,
          'server_port': profile.port,
          'uuid': p['uuid'] ?? '',
          'flow': p['flow'] ?? 'xtls-rprx-vision',
          'tls': {
            'enabled': true,
            'server_name': sni,
            'utls': {'enabled': true, 'fingerprint': p['fingerprint'] ?? 'chrome'},
            'reality': {
              'enabled': true,
              'public_key': realityMap['publicKey'] ?? '',
              'short_id': shortIds.isNotEmpty ? shortIds.first : '',
            }
          }
        };

      case VpnLayer.xhttp:
        return {
          'type': 'vless',
          'tag': 'xhttp-out',
          'server': profile.server,
          'server_port': profile.port,
          'uuid': p['uuid'] ?? '',
          'transport': {'type': 'xhttp', 'path': p['path'] ?? '/'},
          'tls': {
            'enabled': true,
            'server_name': sni,
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
          }
        };

      case VpnLayer.hysteria2:
        final obfs = p['obfs'] as String?;
        final obfsPwd = p['obfsPassword'] as String?;
        return {
          'type': 'hysteria2',
          'tag': 'hy2-out',
          'server': profile.server,
          'server_port': profile.port,
          'password': p['password'] ?? '',
          if (obfs != null && obfsPwd != null)
            'obfs': {'type': obfs, 'password': obfsPwd},
          'tls': {
            'enabled': true,
            'server_name': sni,
          }
        };
    }
  }
}
