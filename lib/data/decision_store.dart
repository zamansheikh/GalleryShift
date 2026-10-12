import 'package:shared_preferences/shared_preferences.dart';

/// Persists swipe decisions and lifetime stats on the device.
class DecisionStore {
  DecisionStore(this._prefs);

  static Future<DecisionStore> open() async =>
      DecisionStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _kKept = 'kept_ids';
  static const _kTrash = 'trash_ids';
  static const _kFreedBytes = 'freed_bytes';
  static const _kDeletedCount = 'deleted_count';
  static const _kOnboarded = 'onboarded';
  static const _kHintSeen = 'swipe_hint_seen';
  static const _kVideoMuted = 'video_muted';
  static const _kTrashedNames = 'trashed_by_app';

  // ------------------------------------------------------------- decisions

  /// A decision is saved as `id|captureSeconds`. The capture time is a
  /// fingerprint: platform IDs can be reassigned to different photos (a new
  /// phone restored from backup, a rebuilt media database), and a decision
  /// must never follow the ID onto another photo. Entries written by older
  /// versions are a bare `id`.
  static String encode(String id, int? stamp) =>
      stamp == null ? id : '$id|$stamp';

  static (String id, int? stamp) decode(String raw) {
    final bar = raw.lastIndexOf('|');
    if (bar <= 0) return (raw, null);
    final stamp = int.tryParse(raw.substring(bar + 1));
    return stamp == null ? (raw, null) : (raw.substring(0, bar), stamp);
  }

  List<String> loadKept() => _prefs.getStringList(_kKept) ?? const [];
  Future<void> saveKept(Iterable<String> encoded) =>
      _prefs.setStringList(_kKept, encoded.toList());

  /// Ordered: the review bin shows the most recent swipe first.
  List<String> loadTrash() => _prefs.getStringList(_kTrash) ?? const [];
  Future<void> saveTrash(Iterable<String> encoded) =>
      _prefs.setStringList(_kTrash, encoded.toList());

  Future<void> resetProgress() async {
    await _prefs.remove(_kKept);
    await _prefs.remove(_kTrash);
  }

  // ----------------------------------------------------------------- stats

  int get freedBytes => _prefs.getInt(_kFreedBytes) ?? 0;
  int get deletedCount => _prefs.getInt(_kDeletedCount) ?? 0;
  Future<void> addFreed({required int bytes, required int count}) async {
    await _prefs.setInt(_kFreedBytes, freedBytes + bytes);
    await _prefs.setInt(_kDeletedCount, deletedCount + count);
  }

  // ------------------------------------------- files this app sent to trash

  static const _trashKeptFor = Duration(days: 32);
  static const _maxRemembered = 5000;

  /// Remembers file names this app moved to the system trash. Their size is
  /// counted as freed at that moment, so when storage cleanup later removes
  /// the same files from the trash they must not be counted a second time.
  Future<void> rememberTrashed(Iterable<String> names) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = _freshTrashed(now)..addAll(names.map((n) => '$now|$n'));
    final overflow = entries.length - _maxRemembered;
    await _prefs.setStringList(
      _kTrashedNames,
      overflow > 0 ? entries.sublist(overflow) : entries,
    );
  }

  /// For each of [names], whether this app trashed a file of that name.
  /// Each remembered entry answers for one file only, then is forgotten.
  Future<List<bool>> takeTrashed(List<String> names) async {
    if (names.isEmpty) return const [];
    final entries = _freshTrashed(DateTime.now().millisecondsSinceEpoch);
    final remembered = [
      for (final e in entries) e.substring(e.indexOf('|') + 1),
    ];
    final result = <bool>[];
    for (final name in names) {
      final i = remembered.indexOf(name);
      result.add(i >= 0);
      if (i >= 0) {
        remembered.removeAt(i);
        entries.removeAt(i);
      }
    }
    await _prefs.setStringList(_kTrashedNames, entries);
    return result;
  }

  /// Entries still inside the trash retention window; the system has purged
  /// anything older.
  List<String> _freshTrashed(int nowMs) {
    final cutoff = nowMs - _trashKeptFor.inMilliseconds;
    return [
      for (final e in _prefs.getStringList(_kTrashedNames) ?? const <String>[])
        if (_trashedAt(e) >= cutoff) e,
    ];
  }

  /// Entries are `trashedAtMs|fileName`.
  static int _trashedAt(String entry) {
    final bar = entry.indexOf('|');
    return bar < 0 ? 0 : int.tryParse(entry.substring(0, bar)) ?? 0;
  }

  // ---------------------------------------------------------------- flags

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded() => _prefs.setBool(_kOnboarded, true);

  bool get swipeHintSeen => _prefs.getBool(_kHintSeen) ?? false;
  Future<void> setSwipeHintSeen() => _prefs.setBool(_kHintSeen, true);

  /// Card videos autoplay, so they start muted until the user unmutes.
  bool get videoMuted => _prefs.getBool(_kVideoMuted) ?? true;
  Future<void> setVideoMuted(bool v) => _prefs.setBool(_kVideoMuted, v);
}
