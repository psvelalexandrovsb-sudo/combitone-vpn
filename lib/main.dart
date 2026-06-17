import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/vpn_manager_windows.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const WindowOptions windowOptions = WindowOptions(
    size: Size(400, 620),
    minimumSize: Size(360, 500),
    center: true,
    title: 'Combitone',
    backgroundColor: Color(0xFF1B1A17),
    // Прячем нативный заголовок — рисуем свою панель с кнопками (см. _WindowBar).
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final mgr = VpnManagerWindows();
  await mgr.init();

  runApp(
    ChangeNotifierProvider.value(
      value: mgr,
      child: const CombitoneApp(),
    ),
  );
}

class CombitoneApp extends StatelessWidget {
  const CombitoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Combitone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1B1A17),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF348E52)),
      ),
      // Своя панель окна сверху на всех экранах (заголовок + кнопки).
      builder: (context, child) => Column(
        children: [
          const _WindowBar(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
      home: const AuthGate(),
    );
  }
}

/// Кастомная верхняя панель окна: перетаскивание + свернуть/развернуть/закрыть.
class _WindowBar extends StatelessWidget {
  const _WindowBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 12),
                color: Colors.transparent,
                child: const Text(
                  'Combitone',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9A968C)),
                ),
              ),
            ),
          ),
          _WinBtn(icon: Icons.remove, tooltip: 'Свернуть', onTap: () => windowManager.minimize()),
          _WinBtn(
            icon: Icons.crop_square,
            tooltip: 'Развернуть',
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WinBtn(icon: Icons.close, tooltip: 'Закрыть', danger: true, onTap: () => windowManager.close()),
        ],
      ),
    );
  }
}

class _WinBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  const _WinBtn({required this.icon, required this.tooltip, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        hoverColor: danger ? const Color(0xFFE0533D) : Colors.white24,
        child: SizedBox(
          width: 44,
          height: 36,
          child: Icon(icon, size: 15, color: const Color(0xFFCFCABF)),
        ),
      ),
    );
  }
}

/// Показывает LoginScreen или HomeScreen в зависимости от состояния авторизации.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<VpnManagerWindows>();
    if (mgr.isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return mgr.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}
