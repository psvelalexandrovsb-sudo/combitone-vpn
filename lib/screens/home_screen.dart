import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_endpoint.dart';
import '../services/vpn_manager_windows.dart';
import 'exclusions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<VpnManagerWindows>();

    final statusColor = switch (mgr.status) {
      VpnStatus.connected => const Color(0xFF348E52),
      VpnStatus.connecting => Colors.orange,
      VpnStatus.error => Colors.redAccent,
      VpnStatus.disconnected => Colors.grey,
    };

    final statusLabel = switch (mgr.status) {
      VpnStatus.connected => 'Подключено',
      VpnStatus.connecting => 'Подключение...',
      VpnStatus.error => 'Ошибка',
      VpnStatus.disconnected => 'Отключено',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combitone'),
        backgroundColor: const Color(0xFF1B1A17),
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: 'Открыть логи',
            onPressed: () => mgr.openLogs(),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Исключения',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ExclusionsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () => mgr.logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.1),
                border: Border.all(color: statusColor, width: 3),
              ),
              child: Icon(
                mgr.isConnected ? Icons.shield : Icons.shield_outlined,
                size: 56, color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(statusLabel,
              style: TextStyle(fontSize: 18, color: statusColor, fontWeight: FontWeight.w600)),
            if (mgr.status == VpnStatus.error && mgr.error != null) ...[
              const SizedBox(height: 8),
              Text(
                mgr.error!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Сервер', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: mgr.selected.id,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              items: [
                for (final e in mgr.endpoints)
                  DropdownMenuItem(
                    value: e.id,
                    child: Text(_epTitle(e)),
                  ),
              ],
              onChanged: mgr.isConnected
                  ? null
                  : (id) {
                      if (id == null) return;
                      final ep = mgr.endpoints.firstWhere((e) => e.id == id);
                      mgr.selectEndpoint(ep);
                    },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: mgr.status == VpnStatus.connecting
                    ? null
                    : mgr.isConnected
                        ? mgr.disconnect
                        : mgr.connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mgr.isConnected ? Colors.redAccent : const Color(0xFF348E52),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  mgr.isConnected ? 'Отключить' : 'Подключить',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _epTitle(VpnEndpoint e) {
    final proto = e.isHysteria2
        ? 'Hysteria2'
        : e.isGrpc
            ? 'REALITY+gRPC'
            : 'REALITY';
    return '${e.label}  ·  $proto';
  }
}
