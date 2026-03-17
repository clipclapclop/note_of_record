import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/list_items_dao.dart';
import 'daos/notes_dao.dart';

part 'app_database.g.dart';

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'text' or 'list'
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class ListItems extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get content => text()();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes, ListItems], daos: [NotesDao, ListItemsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'note_of_record'));

  @override
  int get schemaVersion => 1;
}
