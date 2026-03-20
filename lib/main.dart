import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/providers/database_provider.dart';
import 'package:note_of_record/providers/settings_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:note_of_record/providers/sort_mode_provider.dart';
import 'package:note_of_record/providers/view_mode_provider.dart';
import 'package:note_of_record/services/backup_service.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(sortModeProvider.notifier).load();
  await container.read(viewModeProvider.notifier).load();
  await container.read(settingsProvider.notifier).load();
  await _runAutoBackupIfDue(container);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NoteOfRecordApp(),
    ),
  );
}

Future<void> _runAutoBackupIfDue(ProviderContainer container) async {
  final settings = container.read(settingsProvider);
  if (!settings.autoBackupEnabled ||
      settings.backupFolderPath == null ||
      settings.scheduledBackupTime == null) {
    return;
  }

  final now = DateTime.now();
  final scheduled = settings.scheduledBackupTime!;

  // The scheduled moment for today.
  final scheduledToday = DateTime(
      now.year, now.month, now.day, scheduled.hour, scheduled.minute);

  // Only run if we're past the scheduled time today.
  if (now.isBefore(scheduledToday)) { return; }

  // Skip if we've already backed up since the scheduled time today.
  final last = settings.lastBackupTime;
  if (last != null && last.isAfter(scheduledToday)) return;

  try {
    if (!await Permission.manageExternalStorage.isGranted) return;
    final db = container.read(databaseProvider);
    final rows = await db.customSelect('PRAGMA database_list').get();
    final dbPath = rows.first.data['file'] as String;
    await db.close();
    container.invalidate(databaseProvider);
    await BackupService.backup(dbPath, settings.backupFolderPath!);
    await container.read(settingsProvider.notifier).recordBackupTime(now);
  } catch (_) {
    // Auto backup failures are silent — user will see the last backup time
    // in Settings and can trigger a manual backup.
  }
}
