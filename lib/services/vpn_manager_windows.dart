import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Timer? _refreshTimer;
  static const _exclusionsKey = 'app_exclusions';

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
    final prefs = await SharedPreferences.getInstance();
    _exclusions = prefs.getStringList(_exclusionsKey) ?? [];
    _token = await AuthService.savedToken();
    if (_token != null) {
      _config = await AuthService.fetchConfig(_token!);
      if (_config == null) {
        // Токен устарел или сервер недоступен — сбрасываем
        await AuthService.logout();
        _token = null;
      } else {
        _startAutoRefresh();
      }
    }
    _initializing = false;
    notifyListeners();
  }

  /// Авто-обновление списка подключений с сервера каждые 30 минут (как в Android).
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      if (_token == null) return;
      final fresh = await AuthService.fetchConfig(_token!);
      if (fresh != null) {
        _config = fresh;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
    _startAutoRefresh();
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

  Future<void> _saveExclusions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_exclusionsKey, _exclusions);
  }

  void addExclusion(String host) {
    final v = host.trim().toLowerCase();
    if (v.isNotEmpty && !_exclusions.contains(v)) {
      _exclusions = [..._exclusions, v];
      _saveExclusions();
      notifyListeners();
    }
  }

  void removeExclusion(String host) {
    _exclusions = _exclusions.where((e) => e != host).toList();
    _saveExclusions();
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
          // gvisor — userspace-стек. system-стек на Windows падает с
          // "listen udp4 :0: bind: lacked sufficient buffer space" → нет трафика.
          'stack': 'gvisor',
          'sniff': true,
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
            // ${profile.server}/32 — сам VPN-сервер ИДЁТ НАПРЯМУЮ, иначе auto_route
            // заворачивает соединение sing-box к серверу обратно в туннель →
            // маршрутная петля (100% CPU, нет трафика). Критично для UDP/Hysteria2.
            'ip_cidr': [
              '${profile.server}/32',
              '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '127.0.0.0/8'
            ],
            'outbound': 'direct'
          },
          // Split-tunnel по приложениям: указанные exe идут мимо VPN (напрямую).
          if (_exclusions.isNotEmpty)
            {'process_name': _exclusions, 'outbound': 'direct'},
        ],
        'final': switch (profile.layer) {
          VpnLayer.reality => 'vless-out',
          VpnLayer.grpc => 'grpc-out',
          VpnLayer.hysteria2 => 'hy2-out',
        },
      }
    };
  }

  Map<String, dynamic> _buildOutbound(VpnProfile profile) {
    final p = profile.params;
    final realityMap = (p['reality'] as Map?)?.cast<String, dynamic>() ?? {};
    final shortIds = (realityMap['shortIds'] as List?)?.cast<String>() ?? [];
    // SNI — свой у каждого слоя: reality/grpc берут из reality.sni, hysteria2 — из sni.
    final realitySni = (realityMap['sni'] as String?) ?? profile.server;

    switch (profile.layer) {
      case VpnLayer.reality:
        return {
          'type': 'vless',
          'tag': 'vless-out',
          'server': profile.server,
          'server_port': profile.port,
          'uuid': p['uuid'] ?? '',
          'flow': p['flow'] ?? 'xtls-rprx-vision',
          'tls': {
            'enabled': true,
            'server_name': realitySni,
            'utls': {'enabled': true, 'fingerprint': p['fingerprint'] ?? 'chrome'},
            'reality': {
              'enabled': true,
              'public_key': realityMap['publicKey'] ?? '',
              'short_id': shortIds.isNotEmpty ? shortIds.first : '',
            }
          }
        };

      case VpnLayer.grpc:
        // VLESS+REALITY+gRPC: мультиплекс, flow пустой (vision только для TCP).
        return {
          'type': 'vless',
          'tag': 'grpc-out',
          'server': profile.server,
          'server_port': profile.port,
          'uuid': p['uuid'] ?? '',
          'transport': {'type': 'grpc', 'service_name': p['serviceName'] ?? 'grpc'},
          'tls': {
            'enabled': true,
            'server_name': realitySni,
            'utls': {'enabled': true, 'fingerprint': p['fingerprint'] ?? 'chrome'},
            'reality': {
              'enabled': true,
              'public_key': realityMap['publicKey'] ?? '',
              'short_id': shortIds.isNotEmpty ? shortIds.first : '',
            }
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
            'server_name': (p['sni'] as String?) ?? profile.server,
          }
        };
    }
  }
}
