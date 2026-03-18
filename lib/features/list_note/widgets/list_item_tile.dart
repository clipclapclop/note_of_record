import 'package:flutter/material.dart';
import 'package:note_of_record/core/database/app_database.dart';

class ListItemTile extends StatefulWidget {
  const ListItemTile({
    super.key,
    required this.item,
    required this.onCheckedChanged,
    required this.onContentChanged,
    required this.onDelete,
    required this.dragIndex,
    this.autofocus = false,
    this.onSubmitted,
  });

  final ListItem item;
  final ValueChanged<bool> onCheckedChanged;
  final ValueChanged<String> onContentChanged;
  final VoidCallback onDelete;
  final int dragIndex;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  State<ListItemTile> createState() => _ListItemTileState();
}

class _ListItemTileState extends State<ListItemTile> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.content);
  }

  @override
  void didUpdateWidget(ListItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id) {
      _ctrl.text = widget.item.content;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = widget.item.isChecked;
    final theme = Theme.of(context);

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: ReorderableDragStartListener(
            index: widget.dragIndex,
            child: Icon(
              Icons.drag_handle,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
        ),
        Checkbox(
          value: isChecked,
          onChanged: (v) => widget.onCheckedChanged(v ?? false),
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: widget.autofocus,
            decoration: const InputDecoration(border: InputBorder.none),
            style: theme.textTheme.bodyMedium?.copyWith(
              decoration: isChecked ? TextDecoration.lineThrough : null,
              color: isChecked ? theme.colorScheme.outline : null,
            ),
            onChanged: widget.onContentChanged,
            onSubmitted: (_) => widget.onSubmitted?.call(),
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
      ],
    );
  }
}
