import 'dart:async';
import 'dart:io';

class SyncLogger {
  /// Captures all `print` output during [action] into a timestamped log file
  /// under `sync_logs/` and also forwards prints to the console.
  /// Returns the result of [action].
  static Future<T> capture<T>(Future<T> Function() action, {String? prefix}) async {
    final now = DateTime.now();
    final ts = _fmtTs(now);
    final dir = Directory('sync_logs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = '${prefix != null ? '${prefix}_' : ''}sync_$ts.log';
    final file = File('${dir.path}/$fileName');
    final sink = file.openWrite(mode: FileMode.writeOnlyAppend);

    sink.writeln('=== Sync Log Start ===');
    sink.writeln('Timestamp: ${now.toIso8601String()}');
    sink.writeln('File: ${file.path}');
    sink.writeln('======================');

    Future<void> _close([String? trailer]) async {
      if (trailer != null) sink.writeln(trailer);
      sink.writeln('=== Sync Log End ===');
      await sink.flush();
      await sink.close();
    }

    try {
      final result = await runZoned<Future<T>>(() async {
        try {
          final r = await action();
          await _close('Status: success at ${DateTime.now().toIso8601String()}');
          return r;
        } catch (e, st) {
          sink.writeln('[ERROR] $e');
          sink.writeln(st.toString());
          await _close('Status: error at ${DateTime.now().toIso8601String()}');
          rethrow;
        }
      }, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          final tsLine = '[${DateTime.now().toIso8601String()}] $line';
          sink.writeln(tsLine);
          parent.print(zone, line);
        },
      ));
      return await result;
    } catch (e) {
      // In case runZoned fails (unlikely), ensure sink is closed
      await _close('Status: fatal at ${DateTime.now().toIso8601String()}');
      rethrow;
    }
  }

  static String _fmtTs(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }
}