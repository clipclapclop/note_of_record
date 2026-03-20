import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/backup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _backupBusy = false;
  bool _restoreBusy = false;
  String? _dbPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = ref.read(databaseProvider);
      final rows = await db.customSelect('PRAGMA database_list').get();
      final path = rows.first.data['file'] as String?;
      await db.close();
      ref.invalidate(databaseProvider);
      if (mounted) setState(() => _dbPath = path);
    });
  }

  /// Returns true if the app has all-files access, requesting it if needed.
  Future<bool> _ensureStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All files access is required for backup. '
            'Grant it in Settings → Apps → Note of Record → Permissions.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
    return false;
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select backup folder',
    );
    if (path == null || !mounted) return;
    await ref.read(settingsProvider.notifier).setBackupFolderPath(path);
  }

  Future<void> _pickBackupTime() async {
    final current = ref.read(settingsProvider).scheduledBackupTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 2, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    await ref.read(settingsProvider.notifier).setScheduledBackupTime(picked);
  }

  Future<void> _backupNow() async {
    final folderPath = ref.read(settingsProvider).backupFolderPath;
    if (folderPath == null || _dbPath == null) return;

    if (!await _ensureStoragePermission()) return;
    setState(() => _backupBusy = true);
    try {
      await BackupService.backup(_dbPath!, folderPath);
      await ref.read(settingsProvider.notifier).recordBackupTime(DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreFromBackup() async {
    if (_dbPath == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This will replace all current notes with the contents of the '
          'selected backup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
      dialogTitle: 'Select a note_of_record.zip backup',
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;

    setState(() => _restoreBusy = true);
    try {
      await BackupService.restore(bytes, _dbPath!);
      ref.invalidate(databaseProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore complete')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ref.invalidate(databaseProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final folderSet = settings.backupFolderPath != null;
    final timeSet = settings.scheduledBackupTime != null;
    final canAutoBackup = folderSet && timeSet;
    final lastBackup = settings.lastBackupTime;
    final lastBackupText = lastBackup != null
        ? DateFormat('MMM d, yyyy  h:mm a').format(lastBackup)
        : 'Never';
    final ready = _dbPath != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Backup'),
          ListTile(
            title: const Text('Backup folder'),
            subtitle: Text(
              settings.backupFolderPath ?? 'No folder selected',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TextButton(
              onPressed: _pickFolder,
              child: Text(folderSet ? 'Change' : 'Select'),
            ),
          ),
          ListTile(
            title: const Text('Backup time'),
            subtitle: Text(
              timeSet ? _formatTime(settings.scheduledBackupTime!) : 'Not set',
            ),
            trailing: TextButton(
              onPressed: _pickBackupTime,
              child: Text(timeSet ? 'Change' : 'Set'),
            ),
          ),
          SwitchListTile(
            title: const Text('Auto backup'),
            subtitle: Text(
              canAutoBackup
                  ? 'Backs up daily at ${_formatTime(settings.scheduledBackupTime!)}'
                  : 'Select a folder and time to enable',
            ),
            value: settings.autoBackupEnabled,
            onChanged: canAutoBackup
                ? (val) =>
                    ref.read(settingsProvider.notifier).setAutoBackupEnabled(val)
                : null,
          ),
          ListTile(
            title: const Text('Last backup'),
            subtitle: Text(lastBackupText),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: (folderSet && ready && !_backupBusy) ? _backupNow : null,
              icon: _backupBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup),
              label: const Text('Backup now'),
            ),
          ),
          const Divider(),
          _SectionHeader('Restore'),
          const ListTile(
            subtitle: Text(
              'Select a note_of_record.zip backup to restore from. '
              'All current notes will be replaced.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: (ready && !_restoreBusy) ? _restoreFromBackup : null,
              icon: _restoreBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore),
              label: const Text('Restore from backup'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
