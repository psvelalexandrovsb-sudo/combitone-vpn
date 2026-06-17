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
    // Нативный заголовок Windows — рабочие свернуть/развернуть/закрыть.
    // (Кастомная панель с hidden-заголовком на Windows ломала minimize —
    // серое перекрытие вместо сворачивания.)
    titleBarStyle: TitleBarStyle.normal,
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
      home: const AuthGate(),
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
