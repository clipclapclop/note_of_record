import 'package:drift/drift.dart';

import '../../../services/backup_dirty.dart';
import '../app_database.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Stream<List<Note>> watchAllNotes(String sortMode) {
    final query = select(notes);
    switch (sortMode) {
      case 'alphabetical':
        query.orderBy([
          (n) => OrderingTerm(
                expression: coalesce([n.title.lower(), n.body.lower(),
                    const Constant('')]),
              ),
        ]);
      case 'custom':
        query.orderBy([(n) => OrderingTerm(expression: n.sortOrder)]);
      default: // lastModified
        query.orderBy([
          (n) => OrderingTerm(
                expression: n.updatedAt,
                mode: OrderingMode.desc,
              ),
        ]);
    }
    return query.watch();
  }

  Future<List<Note>> searchNotes(String query) {
    final q = '%$query%';
    return (select(notes)
          ..where(
            (n) =>
                n.title.like(q) |
                n.body.like(q),
          ))
        .get();
  }

  Future<void> insertNote(NotesCompanion note) async {
    await into(notes).insert(note);
    BackupDirty.markDirty();
  }

  Future<void> updateNote(NotesCompanion note) async {
    await (update(notes)..where((n) => n.id.equals(note.id.value)))
        .write(note);
    BackupDirty.markDirty();
  }

  Future<void> deleteNote(String id) async {
    await (delete(notes)..where((n) => n.id.equals(id))).go();
    BackupDirty.markDirty();
  }

  Future<Note?> getNoteById(String id) =>
      (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> getMaxSortOrder() async {
    final result = await customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) as max_order FROM notes',
      readsFrom: {notes},
    ).getSingle();
    return result.read<int>('max_order');
  }

  Future<void> updateSortOrders(List<({String id, int order})> updates) async {
    await batch((b) {
      for (final u in updates) {
        b.update(
          notes,
          NotesCompanion(sortOrder: Value(u.order)),
          where: (n) => n.id.equals(u.id),
        );
      }
    });
    BackupDirty.markDirty();
  }
}
