import 'dart:io' as io;

String? _logFilePath;

Future<String?> initLogWriter() async {
  if (_logFilePath != null) return _logFilePath;

  final logDir = await _resolveLogDirectory();
  if (!await logDir.exists()) {
    await logDir.create(recursive: true);
  }

  final logFile = io.File('${logDir.path}${io.Platform.pathSeparator}coinscape.log');
  if (!await logFile.exists()) {
    await logFile.create(recursive: true);
  }

  _logFilePath = logFile.path;
  return _logFilePath;
}

Future<io.Directory> _resolveLogDirectory() async {
  final current = io.Directory.current;
  final backendData = _findBackendDataDirectory(current);
  final baseDir = backendData ?? io.Directory('${current.path}${io.Platform.pathSeparator}backend${io.Platform.pathSeparator}data');
  return io.Directory('${baseDir.path}${io.Platform.pathSeparator}logs');
}

io.Directory? _findBackendDataDirectory(io.Directory start) {
  var dir = start;
  while (true) {
    final candidate = io.Directory('${dir.path}${io.Platform.pathSeparator}backend${io.Platform.pathSeparator}data');
    if (candidate.existsSync()) {
      return candidate;
    }

    final parent = dir.parent;
    if (parent.path == dir.path) {
      return null;
    }
    dir = parent;
  }
}

Future<void> appendLog(String line) async {
  final path = _logFilePath;
  if (path == null) return;

  await io.File(path).writeAsString(
    '$line${io.Platform.lineTerminator}',
    mode: io.FileMode.append,
    flush: true,
  );
}