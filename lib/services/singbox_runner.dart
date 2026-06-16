import 'dart:io';
import 'dart:convert';
import 'logger.dart';

/// Результат запуска sing-box.
class StartResult {
  final bool ok;
  final String? error;
  const StartResult(this.ok, [this.error]);
}

class SingboxRunner {
  Process? _process;
  bool _running = false;
  int? _lastExitCode;

  bool get running => _running;

  /// Ищем sing-box.exe рядом с exe приложения, затем в PATH.
  String _singboxPath() {
    final appDir = File(Platform.resolvedExecutable).parent.path;
    final bundled = '$appDir\\sing-box.exe';
    if (File(bundled).existsSync()) return bundled;
    return 'sing-box.exe';
  }

  /// Запускает sing-box и УБЕЖДАЕТСЯ, что процесс не упал сразу.
  /// Раньше success = «процесс стартовал», из-за чего приложение показывало
  /// «Подключено» даже когда sing-box падал через долю секунды (битый конфиг,
  /// нет прав админа, нет wintun). Теперь ждём 1.5 с и проверяем, что жив.
  Future<StartResult> start(Map<String, dynamic> config) async {
    if (_running) return const StartResult(true);
    _lastExitCode = null;
    try {
      final json = const JsonEncoder.withIndent('  ').convert(config);
      AppLogger.saveConfig(json);
      AppLogger.resetSingboxLog();

      final configFile = File('${Directory.systemTemp.path}\\combitone_singbox.json');
      await configFile.writeAsString(jsonEncode(config));

      final exePath = _singboxPath();
      AppLogger.log('start: sing-box=$exePath config=${configFile.path}');
      final foundBundled = exePath != 'sing-box.exe';
      AppLogger.log('start: sing-box ${foundBundled ? 'найден рядом с приложением' : 'НЕ найден рядом — ищем в PATH'}');

      _process = await Process.start(
        exePath,
        ['run', '-c', configFile.path],
        runInShell: false,
      );

      // Перехват stdout/stderr → singbox.log
      _process!.stdout.transform(utf8.decoder).listen(AppLogger.appendSingbox);
      _process!.stderr.transform(utf8.decoder).listen(AppLogger.appendSingbox);

      _running = true;
      var exitedEarly = false;
      _process!.exitCode.then((code) {
        _lastExitCode = code;
        _running = false;
        _process = null;
        exitedEarly = true;
        AppLogger.log('sing-box завершился, код=$code');
      });

      // Даём sing-box время поднять TUN или упасть.
      await Future.delayed(const Duration(milliseconds: 1500));

      if (exitedEarly || !_running) {
        final tail = AppLogger.tailSingbox(maxChars: 600);
        final code = _lastExitCode;
        AppLogger.log('start: НЕУДАЧА — sing-box не работает (код=$code)');
        return StartResult(false,
            'sing-box не запустился (код $code). Запустите приложение от имени '
            'администратора. Подробности — кнопка «Открыть логи».\n$tail');
      }

      AppLogger.log('start: OK — sing-box работает');
      return const StartResult(true);
    } catch (e) {
      _running = false;
      AppLogger.log('start: ИСКЛЮЧЕНИЕ — $e');
      return StartResult(false, 'Ошибка запуска sing-box: $e');
    }
  }

  Future<void> stop() async {
    AppLogger.log('stop: остановка sing-box');
    _process?.kill(ProcessSignal.sigterm);
    await Future.delayed(const Duration(milliseconds: 300));
    _process?.kill();
    _process = null;
    _running = false;
  }
}
