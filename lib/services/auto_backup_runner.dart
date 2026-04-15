import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import 'backup_dirty.dart';
import 'backup_service.dart';

/// Runs a backup if auto-backup is configured and there are unsaved changes
/// since the last backup. Called on `AppLifecycleState.paused`. Silent on
/// failure — user sees last-backup timestamp in Settings.
Future<void> maybeRunBackup(WidgetRef ref) async {
  if (!BackupDirty.isDirty) return;

  final settings = ref.read(settingsProvider);
  if (!settings.autoBackupEnabled || settings.backupFolderPath == null) return;

  if (!await Permission.manageExternalStorage.isGranted) return;

  try {
    final db = ref.read(databaseProvider);
    final rows = await db.customSelect('PRAGMA database_list').get();
    final dbPath = rows.first.data['file'] as String;
    await BackupService.backup(dbPath, settings.backupFolderPath!);
    await ref.read(settingsProvider.notifier).recordBackupTime(DateTime.now());
    BackupDirty.markClean();
  } catch (_) {
    // Silent — next paused event with dirty=true will retry.
  }
}
