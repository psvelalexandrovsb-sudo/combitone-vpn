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

    final canSelect = mgr.status == VpnStatus.disconnected;

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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExclusionsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () => mgr.logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),

                  // Статус-иконка
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withValues(alpha: 0.1),
                      border: Border.all(color: statusColor, width: 3),
                    ),
                    child: Icon(
                      mgr.isConnected ? Icons.shield : Icons.shield_outlined,
                      size: 48,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 17,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // Имя активного сервера при подключении
                  if (mgr.isConnected) ...[
                    const SizedBox(height: 4),
                    Text(
                      mgr.selected.label,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],

                  if (mgr.status == VpnStatus.error && mgr.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      mgr.error!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Заголовок секции
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Сервер',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Список серверов с секциями
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _ServerList(
                          ourEndpoints: mgr.ourEndpoints,
                          publicEndpoints: mgr.publicEndpoints,
                          selected: mgr.selected,
                          canSelect: canSelect,
                          onSelect: mgr.selectEndpoint,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Кнопка подключить / отключить
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: mgr.status == VpnStatus.connecting
                          ? null
                          : mgr.isConnected
                              ? mgr.disconnect
                              : mgr.connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mgr.isConnected
                            ? Colors.redAccent
                            : const Color(0xFF348E52),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        mgr.isConnected ? 'Отключить' : 'Подключить',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// ─── Список серверов с секциями ────────────────────────────────────────────

class _ServerList extends StatelessWidget {
  final List<VpnEndpoint> ourEndpoints;
  final List<VpnEndpoint> publicEndpoints;
  final VpnEndpoint selected;
  final bool canSelect;
  final void Function(VpnEndpoint) onSelect;

  const _ServerList({
    required this.ourEndpoints,
    required this.publicEndpoints,
    required this.selected,
    required this.canSelect,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (ourEndpoints.isNotEmpty) {
      items.add(const _SectionHeader(label: 'Наши серверы'));
      for (final ep in ourEndpoints) {
        items.add(_ServerTile(
          ep: ep,
          isSelected: ep.id == selected.id,
          enabled: canSelect,
          onTap: () => onSelect(ep),
        ));
      }
    }

    if (publicEndpoints.isNotEmpty) {
      items.add(const _SectionHeader(label: 'Резервные'));
      for (final ep in publicEndpoints) {
        items.add(_ServerTile(
          ep: ep,
          isSelected: ep.id == selected.id,
          enabled: canSelect,
          onTap: () => onSelect(ep),
        ));
      }
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Загрузка серверов…',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ListView(padding: EdgeInsets.zero, children: items);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final VpnEndpoint ep;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _ServerTile({
    required this.ep,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  String get _protoLabel {
    if (ep.isHysteria2) return 'Hysteria2 · UDP';
    if (ep.isGrpc) return 'REALITY · gRPC';
    return 'REALITY · TCP';
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF348E52);

    return Material(
      color: isSelected
          ? green.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        hoverColor: isSelected
            ? green.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected ? green : Colors.white24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ep.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _protoLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? green : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_outline,
                    size: 16, color: green.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
