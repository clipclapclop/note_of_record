import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/core/database/app_database.dart';
import 'package:note_of_record/providers/database_provider.dart';
import 'package:note_of_record/providers/notes_provider.dart';
import 'package:uuid/uuid.dart';

import 'widgets/list_item_tile.dart';

class ListNoteScreen extends ConsumerStatefulWidget {
  const ListNoteScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<ListNoteScreen> createState() => _ListNoteScreenState();
}

class _ListNoteScreenState extends ConsumerState<ListNoteScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _addItemCtrl;
  final FocusNode _addItemFocus = FocusNode();
  String? _lastAddedItemId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _addItemCtrl = TextEditingController();
    _loadTitle();
  }

  Future<void> _loadTitle() async {
    final db = ref.read(databaseProvider);
    final note = await db.notesDao.getNoteById(widget.noteId);
    if (note != null && mounted) {
      _titleCtrl.text = note.title ?? '';
    }
  }

  Future<void> _saveTitle() async {
    final db = ref.read(databaseProvider);
    final title = _titleCtrl.text.trim();
    await db.notesDao.updateNote(NotesCompanion(
      id: Value(widget.noteId),
      title: Value(title.isEmpty ? null : title),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<void> _touchNote() async {
    final db = ref.read(databaseProvider);
    await db.notesDao.updateNote(NotesCompanion(
      id: Value(widget.noteId),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<void> _addItem() async {
    final content = _addItemCtrl.text;
    _addItemCtrl.clear();
    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final maxPos =
        await db.listItemsDao.getMaxPositionInGroup(widget.noteId, false);
    await db.listItemsDao.insertItem(ListItemsCompanion.insert(
      id: id,
      noteId: widget.noteId,
      content: content,
      position: Value(maxPos + 1),
    ));
    await _touchNote();
    setState(() => _lastAddedItemId = id);
  }

  Future<void> _checkItem(ListItem item) async {
    final db = ref.read(databaseProvider);
    // Shift all existing checked items' positions down (make room at top)
    await db.listItemsDao.shiftPositions(widget.noteId, true, 0, 1);
    // Move item to top of checked group
    await db.listItemsDao.updateItem(ListItemsCompanion(
      id: Value(item.id),
      isChecked: const Value(true),
      position: const Value(0),
    ));
    await _touchNote();
  }

  Future<void> _uncheckItem(ListItem item) async {
    final db = ref.read(databaseProvider);
    // Compact checked group after removing this item
    await db.listItemsDao
        .shiftPositions(widget.noteId, true, item.position + 1, -1);
    // Append to bottom of unchecked group
    final maxPos =
        await db.listItemsDao.getMaxPositionInGroup(widget.noteId, false);
    await db.listItemsDao.updateItem(ListItemsCompanion(
      id: Value(item.id),
      isChecked: const Value(false),
      position: Value(maxPos + 1),
    ));
    await _touchNote();
  }

  Future<void> _updateContent(String itemId, String content) async {
    final db = ref.read(databaseProvider);
    await db.listItemsDao.updateItem(ListItemsCompanion(
      id: Value(itemId),
      content: Value(content),
    ));
  }

  Future<void> _deleteItem(String itemId) async {
    final db = ref.read(databaseProvider);
    await db.listItemsDao.deleteItem(itemId);
    await _touchNote();
  }

  Future<void> _reorderGroup(
      List<ListItem> group, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = [...group];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final db = ref.read(databaseProvider);
    await db.listItemsDao.updatePositions([
      for (var i = 0; i < reordered.length; i++)
        (id: reordered[i].id, position: i),
    ]);
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final db = ref.read(databaseProvider);
    await db.listItemsDao.deleteItemsForNote(widget.noteId);
    await db.notesDao.deleteNote(widget.noteId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _saveTitle();
    _titleCtrl.dispose();
    _addItemCtrl.dispose();
    _addItemFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(listItemsProvider(widget.noteId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete note',
            onPressed: _deleteNote,
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (allItems) {
          final unchecked = allItems.where((i) => !i.isChecked).toList()
            ..sort((a, b) => a.position.compareTo(b.position));
          final checked = allItems.where((i) => i.isChecked).toList()
            ..sort((a, b) => a.position.compareTo(b.position));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: TextField(
                    controller: _titleCtrl,
                    style: Theme.of(context).textTheme.titleLarge,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _saveTitle(),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),

                // Unchecked items
                if (unchecked.isNotEmpty)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (o, n) => _reorderGroup(unchecked, o, n),
                    children: [
                      for (var i = 0; i < unchecked.length; i++)
                        ListItemTile(
                          key: ValueKey(unchecked[i].id),
                          item: unchecked[i],
                          dragIndex: i,
                          autofocus: unchecked[i].id == _lastAddedItemId,
                          onCheckedChanged: (v) => v
                              ? _checkItem(unchecked[i])
                              : _uncheckItem(unchecked[i]),
                          onContentChanged: (s) =>
                              _updateContent(unchecked[i].id, s),
                          onDelete: () => _deleteItem(unchecked[i].id),
                        ),
                    ],
                  ),

                // Add item row
                ListTile(
                  leading: const Icon(Icons.add),
                  title: TextField(
                    controller: _addItemCtrl,
                    focusNode: _addItemFocus,
                    decoration: const InputDecoration(
                      hintText: 'Add item',
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) async {
                      if (_addItemCtrl.text.isNotEmpty) {
                        await _addItem();
                      }
                      _addItemFocus.requestFocus();
                    },
                  ),
                  onTap: () => _addItemFocus.requestFocus(),
                ),

                // Checked items section
                if (checked.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      '${checked.length} checked',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (o, n) => _reorderGroup(checked, o, n),
                    children: [
                      for (var i = 0; i < checked.length; i++)
                        ListItemTile(
                          key: ValueKey(checked[i].id),
                          item: checked[i],
                          dragIndex: i,
                          onCheckedChanged: (v) => v
                              ? _checkItem(checked[i])
                              : _uncheckItem(checked[i]),
                          onContentChanged: (s) =>
                              _updateContent(checked[i].id, s),
                          onDelete: () => _deleteItem(checked[i].id),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
