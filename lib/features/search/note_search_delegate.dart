import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_of_record/core/database/app_database.dart';
import 'package:note_of_record/features/list_note/list_note_screen.dart';
import 'package:note_of_record/features/text_note/text_note_screen.dart';
import 'package:note_of_record/providers/database_provider.dart';

class NoteSearchDelegate extends SearchDelegate<void> {
  NoteSearchDelegate(this.ref);
  final WidgetRef ref;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _SearchResults(
        query: query,
        ref: ref,
        onTap: (note) => _openNote(context, note),
      );

  @override
  Widget buildSuggestions(BuildContext context) => _SearchResults(
        query: query,
        ref: ref,
        onTap: (note) => _openNote(context, note),
      );

  void _openNote(BuildContext context, Note note) {
    close(context, null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => note.type == 'text'
            ? TextNoteScreen(noteId: note.id)
            : ListNoteScreen(noteId: note.id),
      ),
    );
  }
}

class _SearchResults extends StatefulWidget {
  const _SearchResults({
    required this.query,
    required this.ref,
    required this.onTap,
  });
  final String query;
  final WidgetRef ref;
  final void Function(Note) onTap;

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  List<Note> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(_SearchResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _search();
  }

  Future<void> _search() async {
    if (widget.query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final db = widget.ref.read(databaseProvider);

    // Search notes (title + body)
    final noteResults = await db.notesDao.searchNotes(widget.query.trim());

    // Search list item content and get their parent notes
    final itemResults =
        await db.listItemsDao.searchItemsByContent(widget.query.trim());
    final itemNoteIds = itemResults.map((i) => i.noteId).toSet();

    // Fetch parent notes for matching list items (not already in noteResults)
    final existingIds = noteResults.map((n) => n.id).toSet();
    final extraNotes = <Note>[];
    for (final noteId in itemNoteIds) {
      if (!existingIds.contains(noteId)) {
        final note = await db.notesDao.getNoteById(noteId);
        if (note != null) extraNotes.add(note);
      }
    }

    setState(() {
      _results = [...noteResults, ...extraNotes];
      _loading = false;
    });
  }

  String _subtitle(Note note) {
    if (note.type == 'text') {
      final body = note.body ?? '';
      return body.length > 60 ? '${body.substring(0, 60)}…' : body;
    }
    return 'Checklist';
  }

  String _title(Note note) {
    if (note.title != null && note.title!.isNotEmpty) return note.title!;
    if (note.type == 'text' && note.body != null) {
      final first = note.body!.trimLeft();
      return first.length > 50 ? '${first.substring(0, 50)}…' : first;
    }
    return '(untitled)';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return const Center(child: Text('Start typing to search'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return Center(child: Text('No results for "${widget.query}"'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final note = _results[i];
        return ListTile(
          leading: Icon(
            note.type == 'text' ? Icons.text_snippet_outlined : Icons.checklist,
          ),
          title: Text(_title(note)),
          subtitle: Text(_subtitle(note), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => widget.onTap(note),
        );
      },
    );
  }
}
