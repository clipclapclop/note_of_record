import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_of_record/models/sort_mode.dart';

const _kSortModeKey = 'sort_mode';

class SortModeNotifier extends Notifier<SortMode> {
  @override
  SortMode build() => SortMode.lastModified;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kSortModeKey);
    if (saved != null) {
      state = SortMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => SortMode.lastModified,
      );
    }
  }

  Future<void> set(SortMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortModeKey, mode.name);
  }
}

final sortModeProvider = NotifierProvider<SortModeNotifier, SortMode>(
  SortModeNotifier.new,
);
