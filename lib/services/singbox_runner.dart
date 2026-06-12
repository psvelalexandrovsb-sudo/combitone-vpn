import 'dart:io';
import 'dart:convert';

class SingboxRunner {
  Process? _process;
  bool _running = false;

  bool get running => _running;

  /// Ищем sing-box.exe рядом с exe приложения, затем в PATH.
  String _singboxPath() {
    final appDir = File(Platform.resolvedExecutable).parent.path;
    final bundled = '$appDir\\sing-box.exe';
    if (File(bundled).existsSync()) return bundled;
    return 'sing-box.exe';
  }

  Future<bool> start(Map<String, dynamic> config) async {
    if (_running) return true;
    try {
      final configFile = File('${Directory.systemTemp.path}\\combitone_singbox.json');
      await configFile.writeAsString(jsonEncode(config));
      final exePath = _singboxPath();
      _process = await Process.start(
        exePath,
        ['run', '-c', configFile.path],
        runInShell: false,
      );
      _running = true;
      _process!.exitCode.then((_) {
        _running = false;
        _process = null;
      });
      return true;
    } catch (_) {
      _running = false;
      return false;
    }
  }

  Future<void> stop() async {
    _process?.kill(ProcessSignal.sigterm);
    await Future.delayed(const Duration(milliseconds: 300));
    _process?.kill();
    _process = null;
    _running = false;
  }
}
