import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/core/database/app_database.dart';
import 'package:note_of_record/providers/notes_provider.dart';

class NoteCard extends ConsumerWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  String _previewText() {
    if (note.title != null && note.title!.isNotEmpty) return note.title!;
    if (note.body != null && note.body!.isNotEmpty) {
      final text = note.body!.trimLeft();
      return text.length > 80 ? '${text.substring(0, 80)}…' : text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTextNote = note.type == 'text';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: isTextNote
              ? _TextNotePreview(note: note, previewText: _previewText())
              : _ListNotePreview(note: note),
        ),
      ),
    );
  }
}

class _TextNotePreview extends StatelessWidget {
  const _TextNotePreview({required this.note, required this.previewText});
  final Note note;
  final String previewText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (note.title != null && note.title!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(note.title!,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (note.body != null && note.body!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note.body!.trimLeft(),
              style: theme.textTheme.bodySmall,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }
    return Text(
      previewText.isEmpty ? '(empty note)' : previewText,
      style: previewText.isEmpty
          ? theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline)
          : theme.textTheme.bodyMedium,
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ListNotePreview extends ConsumerWidget {
  const _ListNotePreview({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(listItemsProvider(note.id));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note.title != null && note.title!.isNotEmpty) ...[
          Text(note.title!,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
        ],
        itemsAsync.when(
          data: (items) {
            final unchecked =
                items.where((i) => !i.isChecked).toList()
                  ..sort((a, b) => a.position.compareTo(b.position));
            final checked =
                items.where((i) => i.isChecked).toList()
                  ..sort((a, b) => a.position.compareTo(b.position));
            final preview = [...unchecked, ...checked].take(5).toList();

            if (preview.isEmpty) {
              return Text('(empty list)',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        Icon(
                          item.isChecked
                              ? Icons.check_box_outlined
                              : Icons.check_box_outline_blank,
                          size: 14,
                          color: item.isChecked
                              ? theme.colorScheme.outline
                              : theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.content,
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: item.isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.isChecked
                                  ? theme.colorScheme.outline
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (items.length > 5)
                  Text('+${items.length - 5} more',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
