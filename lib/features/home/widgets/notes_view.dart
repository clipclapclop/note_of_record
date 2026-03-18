import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/core/database/app_database.dart';
import 'package:note_of_record/models/sort_mode.dart';
import 'package:note_of_record/providers/database_provider.dart';
import 'package:note_of_record/providers/sort_mode_provider.dart';
import 'package:note_of_record/providers/view_mode_provider.dart';

import 'note_card.dart';

class NotesView extends ConsumerWidget {
  const NotesView({
    super.key,
    required this.notes,
    required this.onNoteTap,
    required this.onNoteLongPress,
  });

  final List<Note> notes;
  final void Function(Note) onNoteTap;
  final void Function(Note) onNoteLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(viewModeProvider);
    final sortMode = ref.watch(sortModeProvider);
    final isCustom = sortMode == SortMode.custom;

    if (isCustom) {
      return _ReorderableNotesView(
        notes: notes,
        viewMode: viewMode,
        onNoteTap: onNoteTap,
        onNoteLongPress: onNoteLongPress,
        onReorder: (oldIndex, newIndex) async {
          final db = ref.read(databaseProvider);
          final reordered = [...notes];
          if (newIndex > oldIndex) newIndex--;
          final moved = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, moved);
          await db.notesDao.updateSortOrders([
            for (var i = 0; i < reordered.length; i++)
              (id: reordered[i].id, order: i),
          ]);
        },
      );
    }

    if (viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: notes.length,
        itemBuilder: (_, i) => NoteCard(
          note: notes[i],
          onTap: () => onNoteTap(notes[i]),
          onLongPress: () => onNoteLongPress(notes[i]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => NoteCard(
        note: notes[i],
        onTap: () => onNoteTap(notes[i]),
        onLongPress: () => onNoteLongPress(notes[i]),
      ),
    );
  }
}

class _ReorderableNotesView extends StatelessWidget {
  const _ReorderableNotesView({
    required this.notes,
    required this.viewMode,
    required this.onNoteTap,
    required this.onNoteLongPress,
    required this.onReorder,
  });

  final List<Note> notes;
  final ViewMode viewMode;
  final void Function(Note) onNoteTap;
  final void Function(Note) onNoteLongPress;
  final void Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      buildDefaultDragHandles: false,
      onReorder: onReorder,
      itemCount: notes.length,
      itemBuilder: (_, i) => ReorderableDragStartListener(
        key: ValueKey(notes[i].id),
        index: i,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NoteCard(
            note: notes[i],
            onTap: () => onNoteTap(notes[i]),
            onLongPress: () => onNoteLongPress(notes[i]),
          ),
        ),
      ),
    );
  }
}
