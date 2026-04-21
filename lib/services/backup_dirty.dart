import 'package:flutter/foundation.dart';

import 'backup_service.dart';

const _tag = 'AutoBackup';

/// Runs a backup immediately after every DB write. No debounce, no timer —
/// the DB is small and zipping it takes milliseconds.
class BackupDirty {
  // Set once at app startup via [init].
  static String? _dbPath;
  static String? Function()? _folderPathGetter;
  static bool Function()? _autoEnabledGetter;
  static Future<void> Function(DateTime)? _onBackupComplete;

  /// Call once at startup to wire up the dependencies.
  static void init({
    required String dbPath,
    required String? Function() folderPathGetter,
    required bool Function() autoEnabledGetter,
    required Future<void> Function(DateTime) onBackupComplete,
  }) {
    _dbPath = dbPath;
    _folderPathGetter = folderPathGetter;
    _autoEnabledGetter = autoEnabledGetter;
    _onBackupComplete = onBackupComplete;
  }

  /// Called by DAOs after every write. Backs up immediately.
  static void markDirty() {
    _runBackup();
  }

  static Future<void> _runBackup() async {
    final autoEnabled = _autoEnabledGetter?.call() ?? false;
    final folderPath = _folderPathGetter?.call();
    if (!autoEnabled || folderPath == null || _dbPath == null) return;

    try {
      await BackupService.backup(_dbPath!, folderPath);
      await _onBackupComplete?.call(DateTime.now());
      debugPrint('[$_tag] backup succeeded');
    } catch (e, st) {
      debugPrint('[$_tag] backup FAILED: $e\n$st');
    }
  }
}
