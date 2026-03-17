// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_items_dao.dart';

// ignore_for_file: type=lint
mixin _$ListItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ListItemsTable get listItems => attachedDatabase.listItems;
  ListItemsDaoManager get managers => ListItemsDaoManager(this);
}

class ListItemsDaoManager {
  final _$ListItemsDaoMixin _db;
  ListItemsDaoManager(this._db);
  $$ListItemsTableTableManager get listItems =>
      $$ListItemsTableTableManager(_db.attachedDatabase, _db.listItems);
}
