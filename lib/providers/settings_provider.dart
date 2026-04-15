import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final String? backupFolderPath;
  final bool autoBackupEnabled;
  final DateTime? lastBackupTime;

  const SettingsState({
    this.backupFolderPath,
    this.autoBackupEnabled = false,
    this.lastBackupTime,
  });

  SettingsState copyWith({
    String? backupFolderPath,
    bool? autoBackupEnabled,
    DateTime? lastBackupTime,
  }) {
    return SettingsState(
      backupFolderPath: backupFolderPath ?? this.backupFolderPath,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _keyFolder = 'backup_folder_path';
  static const _keyAutoBackup = 'auto_backup_enabled';
  static const _keyLastBackup = 'last_backup_time_ms';

  @override
  SettingsState build() => const SettingsState();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_keyLastBackup);
    state = SettingsState(
      backupFolderPath: prefs.getString(_keyFolder),
      autoBackupEnabled: prefs.getBool(_keyAutoBackup) ?? false,
      lastBackupTime:
          lastMs != null ? DateTime.fromMillisecondsSinceEpoch(lastMs) : null,
    );
  }

  Future<void> setBackupFolderPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFolder, path);
    state = state.copyWith(backupFolderPath: path);
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackup, enabled);
    state = state.copyWith(autoBackupEnabled: enabled);
  }

  Future<void> recordBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastBackup, time.millisecondsSinceEpoch);
    state = state.copyWith(lastBackupTime: time);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
