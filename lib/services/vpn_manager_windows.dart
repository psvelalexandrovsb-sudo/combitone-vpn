import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';
import '../models/vpn_endpoint.dart';
import 'auth_service.dart';
import 'logger.dart';
import 'singbox_runner.dart';

enum VpnStatus { disconnected, connecting, connected, error }

class VpnManagerWindows extends ChangeNotifier {
  final _singbox = SingboxRunner();
  VpnStatus _status = VpnStatus.disconnected;
  String? _error;
  VpnConfig? _config;
  String? _token;
  String _uuid = kDefaultUuid;

  /// Список серверов (как на Android): Hysteria2 + 6 REALITY + gRPC.
  final List<VpnEndpoint> _endpoints = kFallbackEndpoints;
  VpnEndpoint _selected = kFallbackEndpoints.first;

  List<String> _exclusions = [];
  bool _initializing = true;
  Timer? _refreshTimer;
  static const _exclusionsKey = 'app_exclusions';
  static const _selectedKey = 'selected_endpoint';

  VpnStatus get status => _status;
  String? get error => _error;
  VpnConfig? get config => _config;
  List<VpnEndpoint> get endpoints => _endpoints;
  VpnEndpoint get selected => _selected;
  bool get isConnected => _status == VpnStatus.connected;
  bool get isAuthenticated => _config != null;
  bool get isInitializing => _initializing;
  List<String> get exclusions => _exclusions;

  Future<void> init() async {
    _initializing = true;
    final prefs = await SharedPreferences.getInstance();
    _exclusions = prefs.getStringList(_exclusionsKey) ?? [];
    final savedId = prefs.getString(_selectedKey);
    if (savedId != null) {
      _selected = _endpoints.firstWhere((e) => e.id == savedId,
          orElse: () => _endpoints.first);
    }
    _token = await AuthService.savedToken();
    if (_token != null) {
      _config = await AuthService.fetchConfig(_token!);
      if (_config == null) {
        await AuthService.logout();
        _token = null;
      } else {
        _uuid = _config!.uuid ?? kDefaultUuid;
        _startAutoRefresh();
      }
    }
    _initializing = false;
    AppLogger.log('init: авторизован=${_config != null}, сервер=${_selected.id}');
    notifyListeners();
  }

  /// Авто-обновление подписки каждые 30 минут (как в Android).
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      if (_token == null) return;
      final fresh = await AuthService.fetchConfig(_token!);
      if (fresh != null) {
        _config = fresh;
        _uuid = fresh.uuid ?? kDefaultUuid;
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
    _uuid = _config!.uuid ?? kDefaultUuid;
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

  Future<void> selectEndpoint(VpnEndpoint ep) async {
    _selected = ep;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, ep.id);
    notifyListeners();
  }

  Future<void> connect() async {
    _status = VpnStatus.connecting;
    _error = null;
    notifyListeners();

    AppLogger.log('connect: сервер=${_selected.id} (${_selected.protocol}:${_selected.port}) uuid=${_uuid.substring(0, 8)}…');
    final singboxConfig = _buildSingboxConfig(_selected);
    final res = await _singbox.start(singboxConfig);
    if (res.ok) {
      _status = VpnStatus.connected;
      AppLogger.log('connect: статус=Подключено');
    } else {
      _status = VpnStatus.error;
      _error = res.error ?? 'Не удалось подключиться';
      AppLogger.log('connect: статус=Ошибка — ${res.error}');
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
    // НЕ приводим к нижнему регистру: sing-box на Windows сопоставляет
    // process_name с учётом регистра (Telegram.exe != telegram.exe).
    // Дедуп — регистронезависимый, чтобы не плодить дубли.
    final v = host.trim();
    final exists = _exclusions.any((e) => e.toLowerCase() == v.toLowerCase());
    if (v.isNotEmpty && !exists) {
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

  /// Открыть папку с логами в Проводнике.
  Future<void> openLogs() => AppLogger.openFolder();

  Map<String, dynamic> _buildSingboxConfig(VpnEndpoint ep) {
    return {
      // warn — продакшн-уровень: только ошибки. debug писал каждое соединение и
      // DNS-запрос → грузил CPU sing-box и раздувал память gvisor (и singbox.log).
      'log': {'level': 'warn', 'timestamp': true},
      // DNS: ВСЕ запросы резолвятся удалённо через туннель (Cloudflare DoH по IP,
      // detour=proxy). Без этого браузер спрашивал провайдерский DNS, а ТСПУ
      // травит заблокированные домены → ERR_NAME_NOT_RESOLVED (svoboda.org и т.п.).
      // ipv4_only — на случай, если у домена есть AAAA, который не маршрутизируется.
      // Адрес DoH — IP (1.1.1.1), поэтому bootstrap-DNS не нужен.
      'dns': {
        'servers': [
          {'tag': 'remote', 'address': 'https://1.1.1.1/dns-query', 'detour': 'proxy'},
        ],
        'final': 'remote',
        'strategy': 'ipv4_only',
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'address': ['172.19.0.1/30'],
          'auto_route': true,
          'strict_route': false,
          // gvisor — userspace-стек. system-стек на Windows падает с
          // "lacked sufficient buffer space" → нет трафика.
          'stack': 'gvisor',
          'sniff': true,
        }
      ],
      'outbounds': [
        _buildOutbound(ep),
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
        // dns-out — перехваченные TUN'ом DNS-запросы (UDP 53) уходят сюда,
        // во внутренний DNS-модуль sing-box, а не «мимо» к провайдеру.
        {'type': 'dns', 'tag': 'dns-out'},
      ],
      'route': {
        'rules': [
          // Перехват DNS: любой DNS-трафик → внутренний резолвер (см. блок dns).
          {'protocol': 'dns', 'outbound': 'dns-out'},
          // Гасим локальный discovery-флуд, который Windows постоянно льёт в TUN
          // (SSDP/UPnP :1900, WS-Discovery :3702, mDNS :5353, LLMNR :5355,
          // NetBIOS :137-139) + multicast/broadcast + сама TUN-подсеть.
          // Без этого gvisor молотил тысячи соединений к 172.19.0.2:1900 →
          // 50-60% CPU и singbox.log раздувался до десятков МБ.
          {'ip_cidr': ['224.0.0.0/3', '255.255.255.255/32', '172.19.0.0/30'], 'outbound': 'block'},
          {'port': [1900, 3702, 5353, 5355, 137, 138, 139], 'outbound': 'block'},
          {
            // server/32 — сам VPN-сервер идёт НАПРЯМУЮ, иначе auto_route
            // заворачивает соединение sing-box к серверу обратно в туннель →
            // маршрутная петля (100% CPU, нет трафика). Критично для UDP/Hysteria2.
            'ip_cidr': [
              '${ep.server}/32',
              '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '127.0.0.0/8'
            ],
            'outbound': 'direct'
          },
          // Split-tunnel по приложениям: указанные exe идут мимо VPN.
          if (_exclusions.isNotEmpty)
            {'process_name': _exclusions, 'outbound': 'direct'},
        ],
        // auto_detect_interface — выход прокси к серверу идёт через физический
        // интерфейс, а не обратно в TUN. Штатное решение петли auto_route.
        'auto_detect_interface': true,
        'final': 'proxy',
      }
    };
  }

  /// Outbound — 1:1 с Android (combitone-android/lib/services/singbox_config.dart).
  Map<String, dynamic> _buildOutbound(VpnEndpoint ep) {
    if (ep.isHysteria2) {
      return {
        'type': 'hysteria2',
        'tag': 'proxy',
        'server': ep.server,
        'server_port': ep.port,
        'password': ep.password,
        if (ep.obfsPassword.isNotEmpty)
          'obfs': {'type': 'salamander', 'password': ep.obfsPassword},
        'tls': {
          'enabled': true,
          'server_name': ep.sni,
        },
      };
    }
    // VLESS+REALITY (tcp/vision) или +gRPC (мультиплекс).
    return {
      'type': 'vless',
      'tag': 'proxy',
      'server': ep.server,
      'server_port': ep.port,
      'uuid': _uuid,
      // gRPC мультиплексирует один поток — flow xtls-rprx-vision только для TCP.
      if (!ep.isGrpc) 'flow': 'xtls-rprx-vision',
      if (ep.isGrpc)
        'transport': {'type': 'grpc', 'service_name': ep.serviceName},
      'tls': {
        'enabled': true,
        'server_name': ep.sni,
        'utls': {'enabled': true, 'fingerprint': 'chrome'},
        'reality': {
          'enabled': true,
          'public_key': ep.pubkey,
          'short_id': ep.shortId,
        },
      },
    };
  }
}
