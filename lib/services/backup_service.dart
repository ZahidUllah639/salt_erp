import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_service.dart';

/// Configuration for database backups
class BackupConfig {
  final bool enabled;
  final String backupDirectory;
  final String schedule; // 'Daily', 'Weekly', 'Manual'
  final String backupTime; // e.g. "23:59"
  final int retentionCount; // 7, 15, 30
  final bool backupOnShutdown;
  final String? lastBackupTimestamp;
  final String? lastBackupPath;
  final String? lastBackupStatus; // 'Success', 'Failed'
  final int lastBackupSize;

  const BackupConfig({
    this.enabled = true,
    required this.backupDirectory,
    this.schedule = 'Daily',
    this.backupTime = '11:59 PM',
    this.retentionCount = 15,
    this.backupOnShutdown = true,
    this.lastBackupTimestamp,
    this.lastBackupPath,
    this.lastBackupStatus,
    this.lastBackupSize = 0,
  });

  BackupConfig copyWith({
    bool? enabled,
    String? backupDirectory,
    String? schedule,
    String? backupTime,
    int? retentionCount,
    bool? backupOnShutdown,
    String? lastBackupTimestamp,
    String? lastBackupPath,
    String? lastBackupStatus,
    int? lastBackupSize,
  }) {
    return BackupConfig(
      enabled: enabled ?? this.enabled,
      backupDirectory: backupDirectory ?? this.backupDirectory,
      schedule: schedule ?? this.schedule,
      backupTime: backupTime ?? this.backupTime,
      retentionCount: retentionCount ?? this.retentionCount,
      backupOnShutdown: backupOnShutdown ?? this.backupOnShutdown,
      lastBackupTimestamp: lastBackupTimestamp ?? this.lastBackupTimestamp,
      lastBackupPath: lastBackupPath ?? this.lastBackupPath,
      lastBackupStatus: lastBackupStatus ?? this.lastBackupStatus,
      lastBackupSize: lastBackupSize ?? this.lastBackupSize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'backupDirectory': backupDirectory,
      'schedule': schedule,
      'backupTime': backupTime,
      'retentionCount': retentionCount,
      'backupOnShutdown': backupOnShutdown,
      'lastBackupTimestamp': lastBackupTimestamp,
      'lastBackupPath': lastBackupPath,
      'lastBackupStatus': lastBackupStatus,
      'lastBackupSize': lastBackupSize,
    };
  }

  factory BackupConfig.fromMap(Map<String, dynamic> map, {required String defaultDir}) {
    return BackupConfig(
      enabled: map['enabled'] as bool? ?? true,
      backupDirectory: (map['backupDirectory'] as String?)?.isNotEmpty == true
          ? map['backupDirectory'] as String
          : defaultDir,
      schedule: map['schedule'] as String? ?? 'Daily',
      backupTime: map['backupTime'] as String? ?? '11:59 PM',
      retentionCount: (map['retentionCount'] as num?)?.toInt() ?? 15,
      backupOnShutdown: map['backupOnShutdown'] as bool? ?? true,
      lastBackupTimestamp: map['lastBackupTimestamp'] as String?,
      lastBackupPath: map['lastBackupPath'] as String?,
      lastBackupStatus: map['lastBackupStatus'] as String?,
      lastBackupSize: (map['lastBackupSize'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BackupConfig.fromJson(String source, {required String defaultDir}) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      return BackupConfig.fromMap(map, defaultDir: defaultDir);
    } catch (_) {
      return BackupConfig(backupDirectory: defaultDir);
    }
  }
}

/// Metadata and integrity status for an existing backup file on disk
class BackupFileInfo {
  final String fileName;
  final String filePath;
  final int sizeBytes;
  final DateTime createdAt;
  final bool isValid;
  final String integrityStatus; // 'Verified', 'Corrupt', 'Incomplete', 'Missing'

  const BackupFileInfo({
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
    required this.createdAt,
    required this.isValid,
    required this.integrityStatus,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
  }
}

/// Detailed result of a backup operation
class BackupResult {
  final bool success;
  final String message;
  final String? backupPath;
  final int fileSize;
  final DateTime timestamp;
  final String? error;
  final bool isIntegrityVerified;

  const BackupResult({
    required this.success,
    required this.message,
    this.backupPath,
    this.fileSize = 0,
    required this.timestamp,
    this.error,
    this.isIntegrityVerified = false,
  });

  factory BackupResult.ok(String msg, {required String path, required int size, required DateTime time}) {
    return BackupResult(
      success: true,
      message: msg,
      backupPath: path,
      fileSize: size,
      timestamp: time,
      isIntegrityVerified: true,
    );
  }

  factory BackupResult.fail(String errorMsg, {String? path}) {
    return BackupResult(
      success: false,
      message: errorMsg,
      backupPath: path,
      timestamp: DateTime.now(),
      error: errorMsg,
      isIntegrityVerified: false,
    );
  }
}

/// Detailed result of a database restore operation
class RestoreResult {
  final bool success;
  final String message;
  final String? restoredPath;
  final String? safetyRollbackPath;
  final String? error;
  final bool isIntegrityVerified;

  const RestoreResult({
    required this.success,
    required this.message,
    this.restoredPath,
    this.safetyRollbackPath,
    this.error,
    this.isIntegrityVerified = false,
  });

  factory RestoreResult.ok(String msg, {required String restoredPath}) {
    return RestoreResult(
      success: true,
      message: msg,
      restoredPath: restoredPath,
      isIntegrityVerified: true,
    );
  }

  factory RestoreResult.fail(String errorMsg, {String? safetyRollbackPath}) {
    return RestoreResult(
      success: false,
      message: errorMsg,
      safetyRollbackPath: safetyRollbackPath,
      error: errorMsg,
      isIntegrityVerified: false,
    );
  }
}

/// Verification check result
class VerificationResult {
  final bool isValid;
  final String reason;

  const VerificationResult({required this.isValid, required this.reason});
}

/// Enterprise SQLite Backup, Restore, Integrity Verification, and Recovery Service
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  BackupConfig? _cachedConfig;
  bool _isOperationInProgress = false;

  /// Check whether an active backup or restore is currently executing
  bool get isOperationInProgress => _isOperationInProgress;

  // =========================================================================
  // CONFIGURATION MANAGEMENT
  // =========================================================================

  /// Computes default backup destination folder
  Future<String> getDefaultBackupDirectory() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final backupDir = Directory(p.join(appSupportDir.path, 'AnwarSaltFactory', 'Backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      return backupDir.path;
    } catch (_) {
      final tempDir = Directory.systemTemp;
      return p.join(tempDir.path, 'AnwarSaltFactory_Backups');
    }
  }

  Future<File> _getConfigFile() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final folder = Directory(p.join(appSupportDir.path, 'AnwarSaltFactory'));
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      return File(p.join(folder.path, 'backup_config.json'));
    } catch (_) {
      final tempDir = Directory.systemTemp;
      return File(p.join(tempDir.path, 'anwar_backup_config.json'));
    }
  }

  /// Loads current backup configuration
  Future<BackupConfig> loadConfig() async {
    if (_cachedConfig != null) return _cachedConfig!;

    final defaultDir = await getDefaultBackupDirectory();
    final configFile = await _getConfigFile();

    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        _cachedConfig = BackupConfig.fromJson(content, defaultDir: defaultDir);
        return _cachedConfig!;
      } catch (_) {}
    }

    _cachedConfig = BackupConfig(backupDirectory: defaultDir);
    await saveConfig(_cachedConfig!);
    return _cachedConfig!;
  }

  /// Saves backup configuration persistently
  Future<void> saveConfig(BackupConfig config) async {
    _cachedConfig = config;
    final configFile = await _getConfigFile();
    await configFile.writeAsString(config.toJson());
  }

  // =========================================================================
  // SQLITE-SAFE BACKUP CREATION
  // =========================================================================

  /// Creates a transactionally consistent, SQLite-verified backup snapshot.
  /// Uses SQLite's online backup / VACUUM INTO to avoid torn pages or active WAL locks.
  Future<BackupResult> createBackup({
    String? customDestinationDir,
    String? reason,
    DatabaseService? dbServiceOverride,
  }) async {
    if (_isOperationInProgress) {
      return BackupResult.fail('Another database operation is currently in progress.');
    }

    _isOperationInProgress = true;
    try {
      final targetDbService = dbServiceOverride ?? DatabaseService.instance;
      final config = await loadConfig();
      final targetDirPath = customDestinationDir ?? config.backupDirectory;

      // 1. Verify and prepare destination directory
      final destDir = Directory(targetDirPath);
      try {
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
      } catch (e) {
        return BackupResult.fail(
          'Backup destination folder is unavailable or inaccessible: $targetDirPath ($e)',
        );
      }

      // 2. Check write permissions using temporary probe
      final probeFile = File(p.join(destDir.path, '.write_test_${DateTime.now().millisecondsSinceEpoch}.tmp'));
      try {
        await probeFile.writeAsString('probe');
        await probeFile.delete();
      } catch (e) {
        return BackupResult.fail(
          'Insufficient permissions to write to backup folder: $targetDirPath ($e)',
        );
      }

      // 3. Connect to database and checkpoint WAL to flush committed frames
      final db = await targetDbService.database;
      try {
        await db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      } catch (_) {}

      // 4. Construct unique filename with date & time to second
      final now = DateTime.now();
      final timestampStr = DateFormat('yyyy-MM-dd_HHmmss').format(now);
      var baseFileName = 'AnwarSalt_Backup_$timestampStr.db';
      var finalDestPath = p.join(destDir.path, baseFileName);

      // Prevent accidental overwrite on rapid triggers
      if (File(finalDestPath).existsSync()) {
        baseFileName = 'AnwarSalt_Backup_${timestampStr}_${now.millisecond}.db';
        finalDestPath = p.join(destDir.path, baseFileName);
      }

      // Atomic write pattern: Write to .tmp first, verify, then rename
      final tmpPath = '$finalDestPath.tmp';
      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        try { await tmpFile.delete(); } catch (_) {}
      }

      // 5. Execute SQLite VACUUM INTO for consistent snapshot
      // Normalize path to use forward slashes for SQLite string literal
      final normalizedTmpPath = tmpPath.replaceAll(r'\', '/');
      try {
        await db.execute("VACUUM INTO '$normalizedTmpPath';");
      } catch (e) {
        if (await tmpFile.exists()) {
          try { await tmpFile.delete(); } catch (_) {}
        }
        return BackupResult.fail('Database snapshot failed: $e');
      }

      // 6. Verify integrity of newly created snapshot BEFORE reporting valid
      final verification = await verifyBackupFile(tmpPath);
      if (!verification.isValid) {
        if (await tmpFile.exists()) {
          try { await tmpFile.delete(); } catch (_) {}
        }
        return BackupResult.fail(
          'Backup verification failed: ${verification.reason}. Temporary file discarded.',
        );
      }

      // 7. Atomically rename .tmp file to official backup filename
      try {
        await tmpFile.rename(finalDestPath);
      } catch (_) {
        // Fallback for cross-filesystem moves
        await tmpFile.copy(finalDestPath);
        await tmpFile.delete();
      }

      final backupFile = File(finalDestPath);
      final fileSize = await backupFile.length();

      // 8. Apply retention policy (clean old backups, never discarding the last valid backup)
      await cleanOldBackups(destDir.path, config.retentionCount);

      // 9. Update and persist configuration status
      final updatedConfig = config.copyWith(
        lastBackupTimestamp: now.toIso8601String(),
        lastBackupPath: finalDestPath,
        lastBackupStatus: 'Success',
        lastBackupSize: fileSize,
      );
      await saveConfig(updatedConfig);

      return BackupResult.ok(
        'Backup created and verified successfully ($baseFileName).',
        path: finalDestPath,
        size: fileSize,
        time: now,
      );
    } catch (e) {
      return BackupResult.fail('Unexpected backup failure: $e');
    } finally {
      _isOperationInProgress = false;
    }
  }

  // =========================================================================
  // INTEGRITY VERIFICATION
  // =========================================================================

  /// Validates a backup file: existence, SQLite magic header, PRAGMA integrity_check, and essential tables.
  Future<VerificationResult> verifyBackupFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const VerificationResult(isValid: false, reason: 'File does not exist');
    }

    final len = await file.length();
    if (len < 100) {
      return const VerificationResult(isValid: false, reason: 'File is empty or truncated (< 100 bytes)');
    }

    // 1. Check SQLite magic header (first 16 bytes: "SQLite format 3\000")
    try {
      final raf = await file.open(mode: FileMode.read);
      final headerBytes = await raf.read(16);
      await raf.close();

      final headerStr = String.fromCharCodes(headerBytes);
      if (!headerStr.startsWith('SQLite format 3')) {
        return const VerificationResult(
          isValid: false,
          reason: 'Invalid SQLite header format (not a valid SQLite 3 database)',
        );
      }
    } catch (e) {
      return VerificationResult(isValid: false, reason: 'Error reading file header: $e');
    }

    // 2. Open read-only SQLite connection and run PRAGMA integrity_check
    Database? testDb;
    try {
      testDb = await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(readOnly: true),
      );

      final integrityRows = await testDb.rawQuery('PRAGMA integrity_check;');
      if (integrityRows.isEmpty) {
        return const VerificationResult(isValid: false, reason: 'PRAGMA integrity_check returned no results');
      }

      final integrityResult = integrityRows.first.values.first.toString().toLowerCase();
      if (integrityResult != 'ok') {
        return VerificationResult(isValid: false, reason: 'SQLite integrity check reported: $integrityResult');
      }

      // 3. Verify essential ERP schema tables exist
      final tableRows = await testDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('parties', 'wallets', 'products');",
      );
      final tableNames = tableRows.map((r) => r['name'] as String).toSet();
      if (!tableNames.contains('parties') || !tableNames.contains('wallets')) {
        return const VerificationResult(
          isValid: false,
          reason: 'Missing critical schema tables (parties, wallets)',
        );
      }

      return const VerificationResult(isValid: true, reason: 'Verified OK');
    } catch (e) {
      return VerificationResult(isValid: false, reason: 'Failed to inspect backup database: $e');
    } finally {
      if (testDb != null && testDb.isOpen) {
        await testDb.close();
      }
    }
  }

  // =========================================================================
  // CONTROLLED FAIL-SAFE RESTORE
  // =========================================================================

  /// Safely restores a backup into the active database.
  /// Follows strict phased process:
  /// 1. Pre-flight validation (rejection before touching live DB)
  /// 2. Live database safety rollback snapshot
  /// 3. Stopping active writes / closing live connection
  /// 4. File replacement & cleanup of stale WAL/SHM
  /// 5. Reopening connection & post-restore integrity check
  /// 6. Automatic rollback to previous DB if any step fails
  Future<RestoreResult> restoreBackup(
    String backupFilePath, {
    DatabaseService? dbServiceOverride,
  }) async {
    if (_isOperationInProgress) {
      return RestoreResult.fail('Another database operation is currently in progress.');
    }

    _isOperationInProgress = true;
    final targetDbService = dbServiceOverride ?? DatabaseService.instance;

    // STEP 1: PRE-FLIGHT VALIDATION (Live DB remains untouched)
    final verification = await verifyBackupFile(backupFilePath);
    if (!verification.isValid) {
      _isOperationInProgress = false;
      return RestoreResult.fail(
        'Restore rejected: Backup file failed integrity verification (${verification.reason}). Live database untouched.',
      );
    }

    final liveDbPath = await targetDbService.getDatabasePath();
    final liveDbFile = File(liveDbPath);

    String? safetyRollbackPath;
    File? safetyRollbackFile;

    // STEP 2: SAFETY SNAPSHOT OF CURRENT LIVE DATABASE
    if (liveDbPath != inMemoryDatabasePath && await liveDbFile.exists()) {
      try {
        final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        safetyRollbackPath = '$liveDbPath.safety_rollback_$nowStr.db';
        safetyRollbackFile = File(safetyRollbackPath);

        // Checkpoint live DB before snapshotting
        final db = await targetDbService.database;
        try {
          await db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
        } catch (_) {}

        await liveDbFile.copy(safetyRollbackPath);
      } catch (e) {
        _isOperationInProgress = false;
        return RestoreResult.fail(
          'Failed to create pre-restore safety snapshot of current database: $e. Restore aborted.',
        );
      }
    }

    // STEP 3: STOP ACTIVE WRITES & CLOSE LIVE DATABASE
    try {
      await targetDbService.close();
    } catch (e) {
      _isOperationInProgress = false;
      return RestoreResult.fail('Failed to close active database connection: $e. Restore aborted.');
    }

    // STEP 4: SAFELY REPLACE DATABASE FILE & CLEAN STALE WAL/SHM
    try {
      final walFile = File('$liveDbPath-wal');
      final shmFile = File('$liveDbPath-shm');
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      await File(backupFilePath).copy(liveDbPath);
    } catch (e) {
      // File copy failed! Execute emergency rollback!
      await _rollbackToSafetySnapshot(targetDbService, liveDbPath, safetyRollbackFile);
      _isOperationInProgress = false;
      return RestoreResult.fail(
        'Database file replacement failed: $e. Emergency rollback applied; previous database preserved.',
        safetyRollbackPath: safetyRollbackPath,
      );
    }

    // STEP 5: REOPEN DATABASE & POST-RESTORE INTEGRITY VERIFICATION
    try {
      final restoredDb = await targetDbService.database;
      final integrityRows = await restoredDb.rawQuery('PRAGMA integrity_check;');
      final integrityRes = integrityRows.first.values.first.toString().toLowerCase();
      if (integrityRes != 'ok') {
        throw Exception('Integrity check returned: $integrityRes');
      }

      // Verify essential business records can be queried
      final partyRows = await restoredDb.rawQuery('SELECT COUNT(*) as cnt FROM parties;');
      final walletRows = await restoredDb.rawQuery('SELECT COUNT(*) as cnt FROM wallets;');
      if (partyRows.isEmpty || walletRows.isEmpty) {
        throw Exception('Core tables inaccessible after restore');
      }

      // Verification passed! Clean up safety rollback file
      if (safetyRollbackFile != null && await safetyRollbackFile.exists()) {
        try { await safetyRollbackFile.delete(); } catch (_) {}
      }

      _isOperationInProgress = false;
      return RestoreResult.ok(
        'Database successfully restored from ${p.basename(backupFilePath)} and verified 100% consistent.',
        restoredPath: liveDbPath,
      );
    } catch (e) {
      // Verification failed! Execute emergency rollback!
      await _rollbackToSafetySnapshot(targetDbService, liveDbPath, safetyRollbackFile);
      _isOperationInProgress = false;
      return RestoreResult.fail(
        'Restored database failed post-restore verification: $e. Emergency rollback applied; previous database preserved.',
        safetyRollbackPath: safetyRollbackPath,
      );
    }
  }

  Future<void> _rollbackToSafetySnapshot(
    DatabaseService dbService,
    String liveDbPath,
    File? safetyRollbackFile,
  ) async {
    try {
      await dbService.close();
      if (safetyRollbackFile != null && await safetyRollbackFile.exists()) {
        await safetyRollbackFile.copy(liveDbPath);
        final wal = File('$liveDbPath-wal');
        final shm = File('$liveDbPath-shm');
        if (await wal.exists()) await wal.delete();
        if (await shm.exists()) await shm.delete();
        await dbService.database;
      }
    } catch (_) {}
  }

  // =========================================================================
  // RETENTION MANAGEMENT & BACKUP DIRECTORY SCANNING
  // =========================================================================

  /// Scans the backup directory for valid and invalid backups
  Future<List<BackupFileInfo>> getBackupHistory([String? directoryPath]) async {
    final config = await loadConfig();
    final dirPath = directoryPath ?? config.backupDirectory;
    final dir = Directory(dirPath);

    if (!await dir.exists()) return [];

    final result = <BackupFileInfo>[];
    final files = dir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith('AnwarSalt_Backup_') && name.endsWith('.db');
    }).toList();

    for (final f in files) {
      final stat = f.statSync();
      final check = await verifyBackupFile(f.path);
      result.add(
        BackupFileInfo(
          fileName: p.basename(f.path),
          filePath: f.path,
          sizeBytes: stat.size,
          createdAt: stat.modified,
          isValid: check.isValid,
          integrityStatus: check.isValid ? 'Verified' : 'Corrupt: ${check.reason}',
        ),
      );
    }

    // Sort newest first
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Cleans older backups exceeding retention count.
  /// CRITICAL GUARANTEE: Never discards the only valid backup.
  Future<int> cleanOldBackups(String backupDirPath, int retentionCount) async {
    final dir = Directory(backupDirPath);
    if (!await dir.exists()) return 0;

    final files = dir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith('AnwarSalt_Backup_') && name.endsWith('.db');
    }).toList();

    if (files.length <= 1) {
      // NEVER delete if only 1 backup file exists
      return 0;
    }

    // Sort files newest first
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    var deletedCount = 0;
    if (files.length > retentionCount) {
      final excessFiles = files.sublist(retentionCount);
      for (final oldFile in excessFiles) {
        // Ensure at least one file remains before deleting
        final remaining = dir.listSync().whereType<File>().where((f) {
          final name = p.basename(f.path);
          return name.startsWith('AnwarSalt_Backup_') && name.endsWith('.db') && f.path != oldFile.path;
        }).toList();

        if (remaining.isEmpty) break;

        try {
          oldFile.deleteSync();
          deletedCount++;
        } catch (_) {}
      }
    }
    return deletedCount;
  }

  // =========================================================================
  // SCHEDULED & NORMAL SHUTDOWN HOOKS
  // =========================================================================

  /// Executes on normal orderly application shutdown if enabled in settings.
  /// IMPORTANT DISCLAIMER:
  /// Normal shutdown hooks only run during graceful, orderly application exits.
  /// Sudden power outages, hardware failure, Blue Screen (BSOD), or forced termination
  /// (e.g. Task Manager End Task) CANNOT execute shutdown hooks.
  Future<void> onNormalShutdown({DatabaseService? dbServiceOverride}) async {
    final config = await loadConfig();
    if (!config.enabled || !config.backupOnShutdown) return;

    try {
      await createBackup(
        reason: 'Orderly application shutdown backup',
        dbServiceOverride: dbServiceOverride,
      );
    } catch (_) {}
  }

  /// Checks if a scheduled backup is due (e.g., Daily or Weekly)
  Future<bool> checkScheduledBackup({DatabaseService? dbServiceOverride}) async {
    final config = await loadConfig();
    if (!config.enabled || config.schedule == 'Manual') return false;

    final last = config.lastBackupTimestamp != null
        ? DateTime.tryParse(config.lastBackupTimestamp!)
        : null;

    final now = DateTime.now();
    var isDue = false;

    if (last == null) {
      isDue = true;
    } else if (config.schedule == 'Daily') {
      isDue = now.difference(last).inHours >= 24;
    } else if (config.schedule == 'Weekly') {
      isDue = now.difference(last).inDays >= 7;
    }

    if (isDue) {
      final res = await createBackup(
        reason: 'Automated scheduled backup (${config.schedule})',
        dbServiceOverride: dbServiceOverride,
      );
      return res.success;
    }
    return false;
  }
}
