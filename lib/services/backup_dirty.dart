/// Process-scoped flag indicating notes have been modified since the last
/// successful auto-backup. A fresh process starts clean because the on-disk
/// backup already reflects what the DB held at launch.
class BackupDirty {
  static bool _dirty = false;

  static bool get isDirty => _dirty;
  static void markDirty() => _dirty = true;
  static void markClean() => _dirty = false;
}
