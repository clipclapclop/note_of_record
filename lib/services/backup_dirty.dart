import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'backup_service.dart';

const _tag = 'AutoBackup';

/// Tracks whether the DB has changed since the last backup. The backup itself
/// runs when the user returns to the home screen (called from HomeScreen).
class BackupDirty {
  static bool _dirty = false;

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

  static bool get isDirty => _dirty;

  /// Called by DAOs after every write.
  static void markDirty() => _dirty = true;

  /// Run a backup if dirty. Call this when the home screen is shown.
  static Future<void> backupIfDirty() async {
    if (!_dirty) return;

    final autoEnabled = _autoEnabledGetter?.call() ?? false;
    final folderPath = _folderPathGetter?.call();
    if (!autoEnabled || folderPath == null || _dbPath == null) return;

    if (!await Permission.manageExternalStorage.isGranted) {
      debugPrint('[$_tag] skipped: storage permission not granted');
      return;
    }

    try {
      await BackupService.backup(_dbPath!, folderPath);
      await _onBackupComplete?.call(DateTime.now());
      _dirty = false;
      debugPrint('[$_tag] backup succeeded');
    } catch (e, st) {
      debugPrint('[$_tag] backup FAILED: $e\n$st');
    }
  }
}
