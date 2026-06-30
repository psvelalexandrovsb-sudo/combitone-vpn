/// Эндпоинты VPN — перенесены 1:1 с рабочего Android-клиента
/// (combitone-android/lib/services/vpn_state.dart). Сервер, порты, SNI, ключи
/// REALITY и пароли Hysteria2 — те же, что проверены вживую на Android.
///
/// Hysteria2 (UDP/QUIC) — первый/основной: проходит фильтрацию ТСПУ лучше
/// VLESS+TCP. Дальше 6 запасных VLESS+REALITY и один gRPC (мультиплекс).

/// UUID по умолчанию (как в Android). Если сервер вернёт персональный uuid
/// в подписке — используем его, иначе этот.
const String kDefaultUuid = 'cbf23af3-68bc-4a9e-a1eb-cb2b500b7ac1';

class VpnEndpoint {
  final String id;
  final String label;
  final String protocol; // 'hysteria2' | 'vless'
  final String server;
  final int port;
  final String sni;

  // VLESS+REALITY
  /// Per-endpoint UUID (для публичных серверов из списка).
  /// Пустая строка → использовать uuid из авторизации.
  final String uuid;
  final String pubkey;
  final String shortId;

  // Hysteria2
  final String password;
  final String obfsPassword;

  // Транспорт VLESS: 'tcp' (Reality+Vision) | 'grpc' (Reality+gRPC)
  final String network;
  final String serviceName;

  const VpnEndpoint({
    required this.id,
    required this.label,
    this.protocol = 'vless',
    this.server = '31.57.108.107',
    required this.port,
    required this.sni,
    this.uuid = '',
    this.pubkey = '',
    this.shortId = '',
    this.password = '',
    this.obfsPassword = '',
    this.network = 'tcp',
    this.serviceName = '',
  });

  /// Парсинг из JSON-объекта сервера (GET /app/config → our[]/public[]).
  /// Маппинг: proto→protocol, obfs_password→obfsPassword, short_id→shortId.
  factory VpnEndpoint.fromJson(Map<String, dynamic> json) {
    final proto = (json['proto'] as String?) ?? 'vless';
    return VpnEndpoint(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      protocol: proto,
      server: (json['server'] as String?) ?? '',
      port: (json['port'] as int?) ?? 443,
      sni: (json['sni'] as String?) ?? '',
      uuid: (json['uuid'] as String?) ?? '',
      pubkey: (json['pubkey'] as String?) ?? '',
      shortId: (json['short_id'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
      obfsPassword: (json['obfs_password'] as String?) ?? '',
    );
  }

  bool get isHysteria2 => protocol == 'hysteria2';
  bool get isGrpc => network == 'grpc';
}

/// Fallback-эндпоинты. Порядок = приоритет. Идентичны Android.
const List<VpnEndpoint> kFallbackEndpoints = [
  // --- Hysteria2 (основной, UDP) ---
  VpnEndpoint(
    id: 'hy2-443', label: 'Combitone (быстрый)', protocol: 'hysteria2',
    server: '31.57.108.107', port: 443, sni: 'combitone.com',
    password: 'igwOx0HCS2J52CQ8OA9X', obfsPassword: '1wBWXTiq29GSgT7JuvGs',
  ),
  // --- VLESS+REALITY (запасные, TCP) ---
  VpnEndpoint(id: 'r1-7443', label: 'R-7443', port: 7443, sni: 'swcdn.apple.com',
      pubkey: '1Vwm7dP3ADn6CRmhK78SK5R02PFWCxGpNNWoFzVzXTI', shortId: '11'),
  VpnEndpoint(id: 'r2-2083', label: 'R-2083', port: 2083, sni: 'download.visualstudio.microsoft.com',
      pubkey: '3YtSrteZNuD-PBZxxJ4j4XfsdV3PwpUTIMpJsurzqxk', shortId: 'aa'),
  VpnEndpoint(id: 'r3-2052', label: 'R-2052', port: 2052, sni: 'www.microsoft.com',
      pubkey: 'nFTL91UNDT2QO2ThD45EJEKGzXV5B0lA_74Ep4fhfkU', shortId: '11aa'),
  VpnEndpoint(id: 'r4-8888', label: 'R-8888', port: 8888, sni: 'github.com',
      pubkey: 'lq3UEVe5DzEbDVhySv5oXaCYTaA21oxIOAYiqEQBvSM', shortId: 'a1b2'),
  VpnEndpoint(id: 'r5-2086', label: 'R-2086', port: 2086, sni: 'www.samsung.com',
      pubkey: 'qp-V5fzeG0YepgxgDKA_IeWgBaltdmc9FmDafawgL1w', shortId: 'ff00'),
  VpnEndpoint(id: 'r6-1443', label: 'R-1443', port: 1443, sni: 'www.apple.com',
      pubkey: '1Vwm7dP3ADn6CRmhK78SK5R02PFWCxGpNNWoFzVzXTI', shortId: 'ab'),
  // --- VLESS+REALITY+gRPC (мультиплекс) ---
  VpnEndpoint(id: 'grpc-2087', label: 'gRPC-2087', port: 2087, sni: 'www.microsoft.com',
      pubkey: 'nFTL91UNDT2QO2ThD45EJEKGzXV5B0lA_74Ep4fhfkU', shortId: '11aa',
      network: 'grpc', serviceName: 'grpc'),
];
