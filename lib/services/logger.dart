import 'dart:io';

/// Простое файловое логирование для диагностики VPN на Windows.
/// Пишет в %LOCALAPPDATA%\Combitone\logs\ (или во временную папку, если нет).
///
/// Файлы:
///   app.log      — события приложения (connect/disconnect, пути, коды выхода)
///   singbox.log  — захваченный stdout/stderr процесса sing-box
///   config.json  — последний сгенерированный конфиг sing-box
class AppLogger {
  static Directory? _dir;

  static Directory get dir {
    if (_dir != null) return _dir!;
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final d = Directory('$base\\Combitone\\logs');
    try {
      d.createSync(recursive: true);
    } catch (_) {}
    _dir = d;
    return d;
  }

  static String get appLogPath => '${dir.path}\\app.log';
  static String get singboxLogPath => '${dir.path}\\singbox.log';
  static String get configPath => '${dir.path}\\config.json';

  static String _stamp() => DateTime.now().toIso8601String();

  /// Записать строку в app.log (с меткой времени).
  static void log(String msg) {
    final line = '${_stamp()}  $msg\n';
    try {
      File(appLogPath).writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {}
    // ignore: avoid_print
    print('[combitone] $msg');
  }

  /// Дозаписать сырой вывод процесса sing-box в singbox.log.
  static void appendSingbox(String chunk) {
    try {
      File(singboxLogPath).writeAsStringSync(chunk, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  /// Очистить singbox.log перед новым запуском.
  static void resetSingboxLog() {
    try {
      File(singboxLogPath).writeAsStringSync('');
    } catch (_) {}
  }

  /// Сохранить сгенерированный конфиг для разбора.
  static void saveConfig(String json) {
    try {
      File(configPath).writeAsStringSync(json, flush: true);
    } catch (_) {}
  }

  /// Прочитать последние [maxChars] символов singbox.log (для показа ошибки в UI).
  static String tailSingbox({int maxChars = 1500}) {
    try {
      final f = File(singboxLogPath);
      if (!f.existsSync()) return '';
      final s = f.readAsStringSync();
      return s.length <= maxChars ? s : s.substring(s.length - maxChars);
    } catch (_) {
      return '';
    }
  }

  /// Открыть папку с логами в Проводнике.
  static Future<void> openFolder() async {
    try {
      await Process.start('explorer.exe', [dir.path]);
    } catch (_) {}
  }
}
