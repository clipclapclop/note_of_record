import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class BackupService {
  static const _archiveEntry = 'note_of_record.db';
  static const _zipName = 'note_of_record.zip';

  /// Zips the database file in memory and writes it to [folderPath].
  /// [dbPath] must be resolved via PRAGMA database_list before the DB is closed.
  static Future<void> backup(String dbPath, String folderPath) async {
    final zipBytes = await _buildZip(dbPath);
    await File('$folderPath/$_zipName').writeAsBytes(zipBytes);
  }

  /// Extracts a zip (bytes from file_picker withData: true) and overwrites
  /// the database at [dbPath]. The DB must be closed before calling this.
  static Future<void> restore(Uint8List zipBytes, String dbPath) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    ArchiveFile? entry;
    for (final f in archive) {
      if (f.name == _archiveEntry) {
        entry = f;
        break;
      }
    }
    if (entry == null) throw Exception('Not a valid Note of Record backup');
    await File(dbPath).writeAsBytes(entry.content as List<int>);
  }

  static Future<Uint8List> _buildZip(String dbPath) async {
    final dbBytes = await File(dbPath).readAsBytes();
    final archive = Archive()
      ..addFile(ArchiveFile(_archiveEntry, dbBytes.length, dbBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }
}
