import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/core/database/app_database.dart';
import 'package:note_of_record/providers/database_provider.dart';

class TextNoteScreen extends ConsumerStatefulWidget {
  const TextNoteScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<TextNoteScreen> createState() => _TextNoteScreenState();
}

class _TextNoteScreenState extends ConsumerState<TextNoteScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  Timer? _debounce;
  Note? _note;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final db = ref.read(databaseProvider);
    final note = await db.notesDao.getNoteById(widget.noteId);
    if (note != null && mounted) {
      setState(() {
        _note = note;
        _titleCtrl.text = note.title ?? '';
        _bodyCtrl.text = note.body ?? '';
        _loaded = true;
      });
    }
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await db.notesDao.updateNote(NotesCompanion(
      id: Value(widget.noteId),
      title: Value(_titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim()),
      body: Value(_bodyCtrl.text.isEmpty ? null : _bodyCtrl.text),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<void> _delete() async {
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
    await db.notesDao.deleteNote(widget.noteId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty && body.isEmpty) {
      ref.read(databaseProvider).notesDao.deleteNote(widget.noteId);
    } else {
      _save();
    }
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete note',
            onPressed: _delete,
          ),
        ],
      ),
      body: _loaded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: Theme.of(context).textTheme.titleLarge,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _onChanged(),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _bodyCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Note',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      expands: true,
                      autofocus: _note?.body == null,
                      onChanged: (_) => _onChanged(),
                      textCapitalization: TextCapitalization.sentences,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
