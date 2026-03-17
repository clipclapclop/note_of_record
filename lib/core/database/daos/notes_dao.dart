import 'package:drift/drift.dart';

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

  Future<void> insertNote(NotesCompanion note) => into(notes).insert(note);

  Future<void> updateNote(NotesCompanion note) =>
      (update(notes)..where((n) => n.id.equals(note.id.value)))
          .write(note);

  Future<void> deleteNote(String id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();

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
  }
}
