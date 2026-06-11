import 'dart:io';
import 'dart:convert';

class SingboxRunner {
  Process? _process;
  bool _running = false;

  bool get running => _running;

  Future<bool> start(Map<String, dynamic> config) async {
    if (_running) return true;
    final configFile = File('${Directory.systemTemp.path}\\combitone_singbox.json');
    await configFile.writeAsString(jsonEncode(config));
    try {
      _process = await Process.start('sing-box.exe', ['run', '-c', configFile.path]);
      _running = true;
      _process!.exitCode.then((_) => _running = false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
    _running = false;
  }
}
