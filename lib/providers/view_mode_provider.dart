import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode { grid, list }

const _kViewModeKey = 'view_mode';

class ViewModeNotifier extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.grid;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kViewModeKey);
    if (saved != null) {
      state = ViewMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ViewMode.grid,
      );
    }
  }

  Future<void> toggle() async {
    final next = state == ViewMode.grid ? ViewMode.list : ViewMode.grid;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kViewModeKey, next.name);
  }
}

final viewModeProvider = NotifierProvider<ViewModeNotifier, ViewMode>(
  ViewModeNotifier.new,
);
