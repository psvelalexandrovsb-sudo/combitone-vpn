import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../services/vpn_manager_windows.dart';
import 'exclusions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      VpnStatus.error => mgr.error ?? 'Ошибка',
      VpnStatus.disconnected => 'Отключено',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combitone'),
        backgroundColor: const Color(0xFF1B1A17),
        actions: [
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
            const SizedBox(height: 32),
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
            const SizedBox(height: 40),
            const Text('Протокол', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<VpnLayer>(
              selected: {mgr.selectedLayer},
              onSelectionChanged: (s) => mgr.selectLayer(s.first),
              segments: const [
                ButtonSegment(value: VpnLayer.reality, label: Text('Reality')),
                ButtonSegment(value: VpnLayer.grpc, label: Text('gRPC')),
                ButtonSegment(value: VpnLayer.hysteria2, label: Text('Hysteria2')),
              ],
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
}
