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

  Set<String> loadKept() => (_prefs.getStringList(_kKept) ?? const []).toSet();
  Future<void> saveKept(Set<String> ids) =>
      _prefs.setStringList(_kKept, ids.toList());

  /// Ordered: the review bin shows the most recent swipe first.
  List<String> loadTrash() => _prefs.getStringList(_kTrash) ?? const [];
  Future<void> saveTrash(List<String> ids) =>
      _prefs.setStringList(_kTrash, ids);

  int get freedBytes => _prefs.getInt(_kFreedBytes) ?? 0;
  int get deletedCount => _prefs.getInt(_kDeletedCount) ?? 0;
  Future<void> addFreed({required int bytes, required int count}) async {
    await _prefs.setInt(_kFreedBytes, freedBytes + bytes);
    await _prefs.setInt(_kDeletedCount, deletedCount + count);
  }

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded() => _prefs.setBool(_kOnboarded, true);

  bool get swipeHintSeen => _prefs.getBool(_kHintSeen) ?? false;
  Future<void> setSwipeHintSeen() => _prefs.setBool(_kHintSeen, true);

  Future<void> resetProgress() async {
    await _prefs.remove(_kKept);
    await _prefs.remove(_kTrash);
  }
}
