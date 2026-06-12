import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/vpn_manager_windows.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const WindowOptions windowOptions = WindowOptions(
    size: Size(400, 620),
    minimumSize: Size(360, 500),
    center: true,
    title: 'Combitone',
    backgroundColor: Color(0xFF1B1A17),
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ChangeNotifierProvider(
      create: (_) => VpnManagerWindows(),
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
      home: const HomeScreen(),
    );
  }
}
