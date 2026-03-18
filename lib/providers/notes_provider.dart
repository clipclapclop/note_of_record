import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/core/database/app_database.dart';
import 'package:note_of_record/providers/database_provider.dart';
import 'package:note_of_record/providers/sort_mode_provider.dart';

final notesProvider = StreamProvider<List<Note>>((ref) {
  final db = ref.watch(databaseProvider);
  final sortMode = ref.watch(sortModeProvider);
  return db.notesDao.watchAllNotes(sortMode.name);
});

final listItemsProvider =
    StreamProvider.family<List<ListItem>, String>((ref, noteId) {
  final db = ref.watch(databaseProvider);
  return db.listItemsDao.watchItemsForNote(noteId);
});
