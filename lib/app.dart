import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/features/home/home_screen.dart';
import 'package:note_of_record/services/auto_backup_runner.dart';

class NoteOfRecordApp extends ConsumerStatefulWidget {
  const NoteOfRecordApp({super.key});

  @override
  ConsumerState<NoteOfRecordApp> createState() => _NoteOfRecordAppState();
}

class _NoteOfRecordAppState extends ConsumerState<NoteOfRecordApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      maybeRunBackup(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note of Record',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
