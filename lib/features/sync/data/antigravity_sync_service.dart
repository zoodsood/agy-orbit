import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';

class RemoteFileEntry {
  final String relativePath;
  final int sizeBytes;
  final String sha256;
  final bool isDirectory;

  const RemoteFileEntry({
    required this.relativePath,
    required this.sizeBytes,
    required this.sha256,
    this.isDirectory = false,
  });

  factory RemoteFileEntry.fromJson(Map<String, dynamic> json) {
    return RemoteFileEntry(
      relativePath: json['path'] as String? ?? '',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      sha256: json['sha256'] as String? ?? '',
      isDirectory: json['isDirectory'] as bool? ?? false,
    );
  }
}

/// Result of downsync operation detailing written files and generated safety backups.
class SyncResult {
  final Directory targetDirectory;
  final List<String> writtenFiles;
  final List<String> backedUpFiles;
  final List<String> detectedConflicts;

  const SyncResult({
    required this.targetDirectory,
    this.writtenFiles = const [],
    this.backedUpFiles = const [],
    this.detectedConflicts = const [],
  });

  bool get hadCollisions => backedUpFiles.isNotEmpty;
}

/// Antigravity Sync Service.
/// Synchronizes approved code changes from remote `/workspace/output`
/// to the user's local filesystem with Git-safe guardrails and `.orbit.bak` preservation.
class AntigravitySyncService {
  final http.Client httpClient;
  final AppConfig appConfig;

  AntigravitySyncService({
    required this.httpClient,
    required this.appConfig,
  });

  /// Lists modified artifacts in remote `/workspace/output`.
  Future<List<RemoteFileEntry>> listRemoteArtifacts({
    required String sessionId,
    required String apiKey,
  }) async {
    final uri = appConfig.buildDataPlaneUri(
      'sessions/$sessionId/workspace/output',
      queryParameters: {'key': apiKey},
    );

    final response = await httpClient.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(Duration(seconds: appConfig.requestTimeoutSeconds));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final files = (json['files'] as List<dynamic>? ?? [])
          .map((f) => RemoteFileEntry.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
      return files;
    } else {
      // In offline or mock mode, return empty list
      return [];
    }
  }

  /// Downsyncs modified files from remote sandbox to target local directory.
  /// Folder will be named `orbit-$sessionId-workspace`.
  /// Before overwriting any existing file, creates an automatic `.orbit.bak` backup.
  Future<Directory> downsyncToLocal({
    required String targetParentPath,
    required String sessionId,
    required List<RemoteFileEntry> filesToSync,
    required String apiKey,
    Map<String, String>? inMemoryFileContents,
    bool enableOrbitBackups = true,
  }) async {
    final result = await downsyncWithResult(
      targetParentPath: targetParentPath,
      sessionId: sessionId,
      filesToSync: filesToSync,
      apiKey: apiKey,
      inMemoryFileContents: inMemoryFileContents,
      enableOrbitBackups: enableOrbitBackups,
    );
    return result.targetDirectory;
  }

  /// Downsyncs with comprehensive collision inspection and backup reporting.
  Future<SyncResult> downsyncWithResult({
    required String targetParentPath,
    required String sessionId,
    required List<RemoteFileEntry> filesToSync,
    required String apiKey,
    Map<String, String>? inMemoryFileContents,
    bool enableOrbitBackups = true,
  }) async {
    final workspaceDirName = 'orbit-$sessionId-workspace';
    final targetDir = Directory(p.join(targetParentPath, workspaceDirName));

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final List<String> written = [];
    final List<String> backedUp = [];
    final List<String> conflicts = [];

    for (final file in filesToSync) {
      if (file.isDirectory) continue;
      final localFilePath = p.join(targetDir.path, file.relativePath);
      final localFile = File(localFilePath);

      // Collision guardrail: Check if target file already exists
      if (await localFile.exists()) {
        conflicts.add(file.relativePath);
        if (enableOrbitBackups) {
          final backupPath = '$localFilePath.orbit.bak';
          await localFile.copy(backupPath);
          backedUp.add(backupPath);
        }
      }

      await localFile.parent.create(recursive: true);

      // Write content from memory or download from remote data plane
      if (inMemoryFileContents != null && inMemoryFileContents.containsKey(file.relativePath)) {
        await localFile.writeAsString(inMemoryFileContents[file.relativePath]!);
      } else {
        final uri = appConfig.buildDataPlaneUri(
          'sessions/$sessionId/workspace/files',
          queryParameters: {
            'key': apiKey,
            'path': file.relativePath,
          },
        );

        final response = await httpClient.get(uri);
        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
        }
      }
      written.add(localFilePath);
    }

    return SyncResult(
      targetDirectory: targetDir,
      writtenFiles: written,
      backedUpFiles: backedUp,
      detectedConflicts: conflicts,
    );
  }
}
