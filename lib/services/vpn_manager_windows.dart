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

  VpnStatus get status => _status;
  String? get error => _error;
  VpnConfig? get config => _config;
  VpnLayer get selectedLayer => _selectedLayer;
  bool get isConnected => _status == VpnStatus.connected;
  List<String> get exclusions => _exclusions;

  Future<bool> init() async {
    _token = await AuthService.savedToken();
    if (_token == null) return false;
    _config = await AuthService.fetchConfig(_token!);
    notifyListeners();
    return _config != null;
  }

  Future<bool> login(String phone, String password) async {
    _token = await AuthService.login(phone, password);
    if (_token == null) return false;
    _config = await AuthService.fetchConfig(_token!);
    notifyListeners();
    return _config != null;
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
      _error = 'Не удалось запустить sing-box.exe';
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
        'final': profile.layer == VpnLayer.reality
            ? 'vless-out'
            : profile.layer == VpnLayer.xhttp
                ? 'xhttp-out'
                : 'hy2-out',
      }
    };
  }

  Map<String, dynamic> _buildOutbound(VpnProfile profile) {
    final p = profile.params;
    switch (profile.layer) {
      case VpnLayer.reality:
        return {
          'type': 'vless',
          'tag': 'vless-out',
          'server': profile.server,
          'server_port': profile.port,
          'uuid': p['uuid'] ?? '',
          'flow': 'xtls-rprx-vision',
          'tls': {
            'enabled': true,
            'server_name': p['sni'] ?? profile.server,
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
            'reality': {
              'enabled': true,
              'public_key': p['public_key'] ?? '',
              'short_id': p['short_id'] ?? '',
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
            'server_name': p['sni'] ?? profile.server,
            'utls': {'enabled': true, 'fingerprint': 'chrome'},
          }
        };
      case VpnLayer.hysteria2:
        return {
          'type': 'hysteria2',
          'tag': 'hy2-out',
          'server': profile.server,
          'server_port': profile.port,
          'password': p['password'] ?? '',
          'tls': {
            'enabled': true,
            'server_name': p['sni'] ?? profile.server,
          }
        };
    }
  }
}
