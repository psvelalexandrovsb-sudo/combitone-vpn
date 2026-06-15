import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_manager_windows.dart';

class ExclusionsScreen extends StatefulWidget {
  const ExclusionsScreen({super.key});

  @override
  State<ExclusionsScreen> createState() => _ExclusionsScreenState();
}

class _ExclusionsScreenState extends State<ExclusionsScreen> {
  final _ctrl = TextEditingController();

  void _add() {
    final host = _ctrl.text.trim();
    if (host.isEmpty) return;
    context.read<VpnManagerWindows>().addExclusion(host);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<VpnManagerWindows>();
    return Scaffold(
      appBar: AppBar(title: const Text('Исключения'), backgroundColor: const Color(0xFF1B1A17)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Приложение (напр. chrome.exe)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _add,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF348E52)),
                child: const Text('Добавить'),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Эти приложения будут обходить VPN (прямое подключение). '
                'Имя процесса, напр. chrome.exe, Telegram.exe',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const Divider(),
          Expanded(
            child: mgr.exclusions.isEmpty
                ? const Center(child: Text('Список исключений пуст', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: mgr.exclusions.length,
                    itemBuilder: (ctx, i) => ListTile(
                      title: Text(mgr.exclusions[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => mgr.removeExclusion(mgr.exclusions[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
