import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import 'backup_dirty.dart';

/// Resolve the DB path and wire up [BackupDirty] so backups run immediately
/// after every DB write. Call once during app startup.
Future<void> initAutoBackup(ProviderContainer container) async {
  final db = container.read(databaseProvider);
  final rows = await db.customSelect('PRAGMA database_list').get();
  final dbPath = rows.first.data['file'] as String;

  BackupDirty.init(
    dbPath: dbPath,
    folderPathGetter: () =>
        container.read(settingsProvider).backupFolderPath,
    autoEnabledGetter: () =>
        container.read(settingsProvider).autoBackupEnabled,
    onBackupComplete: (time) async =>
        container.read(settingsProvider.notifier).recordBackupTime(time),
  );
}
