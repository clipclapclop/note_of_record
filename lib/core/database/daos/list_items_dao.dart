import 'package:drift/drift.dart';

import '../../../services/backup_dirty.dart';
import '../app_database.dart';

part 'list_items_dao.g.dart';

@DriftAccessor(tables: [ListItems])
class ListItemsDao extends DatabaseAccessor<AppDatabase>
    with _$ListItemsDaoMixin {
  ListItemsDao(super.db);

  Stream<List<ListItem>> watchItemsForNote(String noteId) {
    return (select(listItems)
          ..where((i) => i.noteId.equals(noteId)))
        .watch();
  }

  Future<List<ListItem>> getItemsForNote(String noteId) {
    return (select(listItems)
          ..where((i) => i.noteId.equals(noteId)))
        .get();
  }

  Future<void> insertItem(ListItemsCompanion item) async {
    await into(listItems).insert(item);
    BackupDirty.markDirty();
  }

  Future<void> updateItem(ListItemsCompanion item) async {
    await (update(listItems)..where((i) => i.id.equals(item.id.value)))
        .write(item);
    BackupDirty.markDirty();
  }

  Future<void> deleteItem(String id) async {
    await (delete(listItems)..where((i) => i.id.equals(id))).go();
    BackupDirty.markDirty();
  }

  Future<void> deleteItemsForNote(String noteId) async {
    await (delete(listItems)..where((i) => i.noteId.equals(noteId))).go();
    BackupDirty.markDirty();
  }

  Future<List<ListItem>> searchItemsByContent(String query) {
    final q = '%$query%';
    return (select(listItems)..where((i) => i.content.like(q))).get();
  }

  Future<int> getMaxPositionInGroup(String noteId, bool isChecked) async {
    final result = await customSelect(
      'SELECT COALESCE(MAX(position), -1) as max_pos FROM list_items '
      'WHERE note_id = ? AND is_checked = ?',
      variables: [Variable.withString(noteId), Variable.withBool(isChecked)],
      readsFrom: {listItems},
    ).getSingle();
    return result.read<int>('max_pos');
  }

  /// Shifts all items in a group at or after [fromPosition] by [delta].
  Future<void> shiftPositions(
      String noteId, bool isChecked, int fromPosition, int delta) async {
    await customUpdate(
      'UPDATE list_items SET position = position + ? '
      'WHERE note_id = ? AND is_checked = ? AND position >= ?',
      variables: [
        Variable.withInt(delta),
        Variable.withString(noteId),
        Variable.withBool(isChecked),
        Variable.withInt(fromPosition),
      ],
      updates: {listItems},
    );
    BackupDirty.markDirty();
  }

  Future<void> updatePositions(
      List<({String id, int position})> updates) async {
    await batch((b) {
      for (final u in updates) {
        b.update(
          listItems,
          ListItemsCompanion(position: Value(u.position)),
          where: (i) => i.id.equals(u.id),
        );
      }
    });
    BackupDirty.markDirty();
  }
}
