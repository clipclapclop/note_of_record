import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/providers/sort_mode_provider.dart';
import 'package:note_of_record/providers/view_mode_provider.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(sortModeProvider.notifier).load();
  await container.read(viewModeProvider.notifier).load();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NoteOfRecordApp(),
    ),
  );
}
