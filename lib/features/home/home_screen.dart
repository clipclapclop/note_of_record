import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:note_of_record/core/database/app_database.dart';
import 'package:note_of_record/features/list_note/list_note_screen.dart';
import 'package:note_of_record/features/search/note_search_delegate.dart';
import 'package:note_of_record/features/text_note/text_note_screen.dart';
import 'package:note_of_record/models/sort_mode.dart';
import 'package:note_of_record/providers/database_provider.dart';
import 'package:note_of_record/providers/notes_provider.dart';
import 'package:note_of_record/providers/sort_mode_provider.dart';
import 'package:note_of_record/providers/view_mode_provider.dart';
import 'package:uuid/uuid.dart';

import 'widgets/notes_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openNote(BuildContext context, Note note) {
    if (note.type == 'text') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TextNoteScreen(noteId: note.id)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ListNoteScreen(noteId: note.id)),
      );
    }
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _NewNoteSheet(),
    );
    if (type == null || !context.mounted) return;

    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxOrder = await db.notesDao.getMaxSortOrder();

    await db.notesDao.insertNote(NotesCompanion.insert(
      id: id,
      type: type,
      sortOrder: Value(maxOrder + 1),
      createdAt: now,
      updatedAt: now,
    ));

    if (!context.mounted) return;
    if (type == 'text') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TextNoteScreen(noteId: id)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ListNoteScreen(noteId: id)),
      );
    }
  }

  Future<void> _deleteNote(
      BuildContext context, WidgetRef ref, Note note) async {
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
    if (confirmed != true) return;
    final db = ref.read(databaseProvider);
    await db.listItemsDao.deleteItemsForNote(note.id);
    await db.notesDao.deleteNote(note.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final viewMode = ref.watch(viewModeProvider);
    final sortMode = ref.watch(sortModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => showSearch(
              context: context,
              delegate: NoteSearchDelegate(ref),
            ),
          ),
          IconButton(
            icon: Icon(
              viewMode == ViewMode.grid ? Icons.view_list : Icons.grid_view,
            ),
            tooltip: viewMode == ViewMode.grid ? 'List view' : 'Grid view',
            onPressed: () => ref.read(viewModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: () => _showSortSheet(context, ref, sortMode),
          ),
        ],
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No notes yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }
          return NotesView(
            notes: notes,
            onNoteTap: (note) => _openNote(context, note),
            onNoteLongPress: (note) => _deleteNote(context, ref, note),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNote(context, ref),
        tooltip: 'New note',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSortSheet(
      BuildContext context, WidgetRef ref, SortMode current) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _SortSheet(current: current, ref: ref),
    );
  }
}

class _NewNoteSheet extends StatelessWidget {
  const _NewNoteSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: const Text('Text note'),
            onTap: () => Navigator.pop(context, 'text'),
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Checklist'),
            onTap: () => Navigator.pop(context, 'list'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current, required this.ref});
  final SortMode current;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          for (final mode in SortMode.values)
            ListTile(
              leading: Icon(
                mode == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(_label(mode)),
              onTap: () {
                ref.read(sortModeProvider.notifier).set(mode);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _label(SortMode mode) => switch (mode) {
        SortMode.lastModified => 'Last modified',
        SortMode.alphabetical => 'Alphabetical',
        SortMode.custom => 'Custom order',
      };
}
