import 'dart:async';

/// Web/non-IO stub for `dart:io` primitives.
/// Selected automatically when `dart.library.io` is unavailable (e.g. Web / Wasm).

class FileMode {
  static const read = FileMode._(0);
  static const write = FileMode._(1);
  static const append = FileMode._(2);
  static const writeOnly = FileMode._(3);
  static const writeOnlyAppend = FileMode._(4);

  final int _mode;
  const FileMode._(this._mode);

  @override
  bool operator ==(Object other) => other is FileMode && other._mode == _mode;

  @override
  int get hashCode => _mode.hashCode;
}

class FileStat {
  final int size;
  const FileStat({this.size = 0});
}

abstract class FileSystemEntity {
  String get path;
  Directory get parent;
  Future<bool> exists();
  Future<FileStat> stat();
  Future<FileSystemEntity> delete({bool recursive = false});
}

class Directory implements FileSystemEntity {
  @override
  final String path;

  Directory(this.path);

  static Directory get current => Directory('.');
  static Directory get systemTemp => Directory('/tmp');

  @override
  Directory get parent => Directory('.');

  @override
  Future<bool> exists() async => false;

  bool existsSync() => false;

  Future<Directory> create({bool recursive = false}) async => this;

  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      const Stream.empty();

  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      const [];

  @override
  Future<FileStat> stat() async => const FileStat();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async => this;
}

class File implements FileSystemEntity {
  @override
  final String path;

  File(this.path);

  @override
  Directory get parent => Directory('.');

  @override
  Future<bool> exists() async => false;

  Future<File> create({bool recursive = false}) async => this;

  Future<String> readAsString() async => '';

  Future<List<String>> readAsLines() async => const [];

  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async =>
      this;

  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {}

  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async =>
      this;

  Future<File> copy(String newPath) async => File(newPath);

  Future<int> length() async => 0;

  @override
  Future<FileStat> stat() async => const FileStat();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async => this;
}

class ProcessResult {
  final int pid;
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;

  const ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);
}

class Process {
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    return const ProcessResult(0, 1, '', 'Process.run unsupported on Web');
  }
}

class Platform {
  static bool get isLinux => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static int get numberOfProcessors => 1;
  static Map<String, String> get environment => const {};
}

class SocketException implements Exception {
  final String message;
  const SocketException([this.message = '']);

  @override
  String toString() => 'SocketException: $message';
}
