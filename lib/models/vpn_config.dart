enum VpnLayer { reality, grpc, hysteria2 }

class VpnProfile {
  final VpnLayer layer;
  final String name;
  final String server;
  final int port;
  final Map<String, dynamic> params;

  const VpnProfile({
    required this.layer,
    required this.name,
    required this.server,
    required this.port,
    required this.params,
  });
}

class VpnConfig {
  final List<VpnProfile> profiles;
  final List<String> sniPool;

  const VpnConfig({required this.profiles, required this.sniPool});

  factory VpnConfig.fromJson(Map<String, dynamic> json) {
    final profiles = (json['profiles'] as List).map((p) {
      VpnLayer layer;
      switch (p['name'] as String) {
        case 'Layer1-Reality':
          layer = VpnLayer.reality;
        case 'Layer2-gRPC':
          layer = VpnLayer.grpc;
        default:
          layer = VpnLayer.hysteria2;
      }
      return VpnProfile(
        layer: layer,
        name: p['name'],
        server: p['server'],
        port: p['port'],
        params: Map<String, dynamic>.from(p),
      );
    }).toList();
    return VpnConfig(
      profiles: profiles,
      sniPool: List<String>.from(json['sni_pool'] ?? []),
    );
  }
}
