import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/decision_store.dart';
import '../data/gallery_repository.dart';
import '../models/deck.dart';
import '../util/format.dart';

enum LoadState { idle, loading, ready, error }

class DeleteOutcome {
  const DeleteOutcome({
    required this.count,
    required this.bytes,
    this.inTrash = false,
  });
  final int count;
  final int bytes;

  /// The items went to a system trash that still takes up space until it is
  /// emptied (Android 11+).
  final bool inTrash;
  bool get cancelled => count == 0;
}

/// App-wide state: permission, library, decisions and stats.
class AppController extends ChangeNotifier {
  AppController({required this.repo, required this.store}) {
    for (final raw in store.loadKept()) {
      final (id, stamp) = DecisionStore.decode(raw);
      _kept.add(id);
      if (stamp != null) _stamps[id] = stamp;
    }
    for (final raw in store.loadTrash()) {
      final (id, stamp) = DecisionStore.decode(raw);
      if (_trashSet.add(id)) _trash.add(id);
      if (stamp != null) _stamps[id] = stamp;
    }
  }

  final GalleryRepository repo;
  final DecisionStore store;

  PermissionState? permission;

  /// Android reports "denied" before the first prompt too, so only treat
  /// access as refused once we have actually asked.
  bool askedForAccess = false;
  LoadState loadState = LoadState.idle;
  Object? loadError;

  List<AssetEntity> _library = const [];
  Map<String, AssetEntity> _byId = const {};
  Set<String> _screenshotIds = const {};
  final Set<String> _kept = {};
  final List<String> _trash = [];
  final Set<String> _trashSet = {};

  /// Capture time of each decided asset, recorded when it was decided. See
  /// [DecisionStore.encode] for why.
  final Map<String, int> _stamps = {};

  List<Deck> quickDecks = const [];
  List<Deck> monthDecks = const [];

  Timer? _saveTimer;
  Future<void>? _loading;
  bool _reloadWanted = false;

  /// Bumped whenever the library is changed here (a delete), so a read that
  /// started earlier is known to be stale.
  int _epoch = 0;
  bool _disposed = false;

  // ---------------------------------------------------------------- getters

  bool get hasAccess =>
      permission != null && GalleryRepository.hasAccess(permission!);
  bool get isLimited => permission == PermissionState.limited;
  int get libraryCount => _library.length;
  int get reviewedCount => _library
      .where((a) => _kept.contains(a.id) || _trashSet.contains(a.id))
      .length;
  double get progress => libraryCount == 0 ? 0 : reviewedCount / libraryCount;
  int get freedBytes => store.freedBytes;
  int get deletedCount => store.deletedCount;
  int get trashCount => trashAssets.length;

  List<AssetEntity> get trashAssets => [
    for (final id in _trash.reversed)
      if (_byId[id] != null) _byId[id]!,
  ];

  /// False once an asset has been deleted, here or elsewhere.
  bool exists(String id) => _byId.containsKey(id);

  bool isReviewed(String id) => _kept.contains(id) || _trashSet.contains(id);

  List<AssetEntity> remaining(Deck deck) =>
      deck.assets.where((a) => !isReviewed(a.id)).toList();

  int remainingCount(Deck deck) =>
      deck.assets.where((a) => !isReviewed(a.id)).length;

  /// Items in [deck] that already have a decision (kept, or in the bin).
  int decidedCount(Deck deck) => deck.assets.length - remainingCount(deck);

  /// Items in [deck] waiting in the bin.
  int binCountIn(Deck deck) =>
      deck.assets.where((a) => _trashSet.contains(a.id)).length;

  AssetEntity? coverFor(Deck deck) {
    for (final a in deck.assets) {
      if (!isReviewed(a.id)) return a;
    }
    return deck.assets.isEmpty ? null : deck.assets.first;
  }

  // ------------------------------------------------------------- lifecycle

  Future<void> bootstrap() async {
    permission = await repo.permissionState();
    _notify();
    if (hasAccess) await load();
  }

  Future<PermissionState> requestAccess() async {
    permission = await repo.requestPermission();
    askedForAccess = true;
    _notify();
    if (hasAccess) {
      await store.setOnboarded();
      await load();
    }
    return permission!;
  }

  /// Called when the app returns to the foreground: permission may have
  /// changed in Settings, and photos may have been added or removed.
  Future<void> onResume() async {
    final before = permission;
    permission = await repo.permissionState();
    if (permission != before) _notify();
    if (hasAccess) await load(quiet: true);
  }

  /// Reads the library. Calls made while a read is in flight share it, and
  /// make it read once more before finishing, so nobody is answered with
  /// data from before their request.
  Future<void> load({bool quiet = false}) {
    final running = _loading;
    if (running != null) {
      _reloadWanted = true;
      return running;
    }
    return _loading = _load(quiet).whenComplete(() => _loading = null);
  }

  Future<void> _load(bool quiet) async {
    if (!quiet || loadState != LoadState.ready) {
      loadState = LoadState.loading;
      _notify();
    }
    try {
      while (true) {
        _reloadWanted = false;
        final epoch = _epoch;
        final results = await Future.wait([
          repo.loadLibrary(),
          repo.loadScreenshotIds(),
        ]);
        // Something was deleted, or a newer reload was asked for, while this
        // read was under way: its answer may be out of date. Read again
        // rather than put deleted items back on screen.
        if (epoch != _epoch || _reloadWanted) continue;

        // Sort here rather than trusting the platform order: on Android it
        // follows when files were added to the device (copied or restored
        // galleries all share one date), not when they were taken.
        // Sort a copy: the repository may hand back an unmodifiable list.
        _library = List.of(results[0] as List<AssetEntity>)
          ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        _screenshotIds = results[1] as Set<String>;
        _byId = {for (final a in _library) a.id: a};
        _pruneStale();
        _buildDecks();
        loadState = LoadState.ready;
        loadError = null;
        break;
      }
    } catch (e, st) {
      debugPrint('Library load failed: $e\n$st');
      loadError = e;
      if (loadState != LoadState.ready) loadState = LoadState.error;
    } finally {
      _notify();
    }
  }

  static int _stampOf(AssetEntity a) => a.createDateSecond ?? 0;

  /// Drops decisions that no longer apply: the asset was deleted elsewhere,
  /// or its ID now belongs to a different photo.
  void _pruneStale() {
    var changed = false;
    bool stale(String id) {
      final asset = _byId[id];
      if (asset == null) return true;
      final stamp = _stamps[id];
      if (stamp == null) {
        // Saved by a version that stored no fingerprint: adopt this one.
        _stamps[id] = _stampOf(asset);
        changed = true;
        return false;
      }
      return stamp != _stampOf(asset);
    }

    final gone = {..._kept.where(stale), ..._trash.where(stale)};
    if (gone.isNotEmpty) {
      _kept.removeAll(gone);
      _trash.removeWhere(gone.contains);
      _trashSet.removeAll(gone);
      gone.forEach(_stamps.remove);
      changed = true;
    }
    if (changed) _scheduleSave();
  }

  void _buildDecks() {
    final now = DateTime.now();
    final videos = _library.where((a) => a.type == AssetType.video).toList();
    final shots = _library.where((a) => _screenshotIds.contains(a.id)).toList();
    final onThisDay = _library.where((a) {
      final d = a.createDateTime;
      return d.month == now.month && d.day == now.day && d.year < now.year;
    }).toList();

    quickDecks = [
      Deck(
        id: 'everything',
        kind: DeckKind.everything,
        title: 'All photos',
        subtitle: 'Newest first',
        icon: Icons.photo_library_rounded,
        assets: _library,
      ),
      Deck(
        id: 'shuffle',
        kind: DeckKind.shuffle,
        title: 'Shuffle',
        subtitle: 'Random picks',
        icon: Icons.shuffle_rounded,
        assets: _library,
      ),
      if (onThisDay.isNotEmpty)
        Deck(
          id: 'on-this-day',
          kind: DeckKind.onThisDay,
          title: 'On this day',
          subtitle: formatDayMonth(now),
          icon: Icons.history_rounded,
          assets: onThisDay,
        ),
      if (shots.isNotEmpty)
        Deck(
          id: 'screenshots',
          kind: DeckKind.screenshots,
          title: 'Screenshots',
          subtitle: 'Usually safe to clear',
          icon: Icons.screenshot_rounded,
          assets: shots,
        ),
      if (videos.isNotEmpty)
        Deck(
          id: 'videos',
          kind: DeckKind.videos,
          title: 'Videos',
          subtitle: 'The space hogs',
          icon: Icons.videocam_rounded,
          assets: videos,
        ),
    ];

    final byMonth = <DateTime, List<AssetEntity>>{};
    for (final a in _library) {
      final d = a.createDateTime;
      (byMonth[DateTime(d.year, d.month)] ??= []).add(a);
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    monthDecks = [
      for (final m in months)
        Deck(
          id: 'month-${m.year}-${m.month}',
          kind: DeckKind.month,
          title: monthName(m.month),
          subtitle: '${m.year}',
          icon: Icons.calendar_month_rounded,
          assets: byMonth[m]!,
          month: m,
        ),
    ];
  }

  /// The ordered list a swipe session works through.
  List<AssetEntity> sessionQueue(Deck deck) {
    final left = remaining(deck);
    if (deck.kind == DeckKind.shuffle) {
      left.shuffle(Random());
      return left.take(60).toList();
    }
    return left;
  }

  // ------------------------------------------------------------- decisions

  void decide(AssetEntity asset, Decision decision) {
    _stamps[asset.id] = _stampOf(asset);
    if (decision == Decision.keep) {
      // One decision per asset: keeping takes it out of the bin.
      if (_trashSet.remove(asset.id)) _trash.remove(asset.id);
      _kept.add(asset.id);
    } else {
      _kept.remove(asset.id);
      _trash.remove(asset.id);
      _trash.add(asset.id);
      _trashSet.add(asset.id);
    }
    _scheduleSave();
    _notify();
  }

  void undo(AssetEntity asset) {
    _kept.remove(asset.id);
    if (_trashSet.remove(asset.id)) _trash.remove(asset.id);
    _stamps.remove(asset.id);
    _scheduleSave();
    _notify();
  }

  /// Take items out of the bin without deciding on them again: they count as
  /// kept, so they don't come back into the decks.
  void restore(Iterable<String> ids) {
    for (final id in ids) {
      if (_trashSet.remove(id)) _trash.remove(id);
      _kept.add(id);
      final asset = _byId[id];
      if (asset != null) _stamps[id] ??= _stampOf(asset);
    }
    _scheduleSave();
    _notify();
  }

  Future<DeleteOutcome> deleteForever(List<AssetEntity> assets) async {
    final sizes = await Future.wait(assets.map(repo.fileSize));
    final bytes = {
      for (var i = 0; i < assets.length; i++) assets[i].id: sizes[i],
    };
    final inTrash = await repo.deletesGoToTrash;
    final deleted = (await repo.delete(assets)).toSet();
    if (deleted.isEmpty) return const DeleteOutcome(count: 0, bytes: 0);

    final freed = deleted.fold<int>(0, (sum, id) => sum + (bytes[id] ?? 0));
    _epoch++;
    _trash.removeWhere(deleted.contains);
    _trashSet.removeAll(deleted);
    _kept.removeAll(deleted);
    deleted.forEach(_stamps.remove);
    _library = _library.where((a) => !deleted.contains(a.id)).toList();
    _byId = {for (final a in _library) a.id: a};
    _buildDecks();
    _scheduleSave();
    if (inTrash) {
      // These files sit in the system trash until it is emptied. Their size
      // is counted as freed now; remember them so that emptying the trash
      // from storage cleanup doesn't count them again.
      await store.rememberTrashed([
        for (final a in assets)
          if (deleted.contains(a.id) && a.title != null) a.title!,
      ]);
    }
    await recordFreed(bytes: freed, items: deleted.length);
    return DeleteOutcome(count: deleted.length, bytes: freed, inTrash: inTrash);
  }

  /// Adds to the lifetime stats and refreshes whatever is showing them.
  Future<void> recordFreed({required int bytes, int items = 0}) async {
    if (bytes <= 0 && items <= 0) return;
    await store.addFreed(bytes: bytes < 0 ? 0 : bytes, count: items);
    _notify();
  }

  /// Files were removed behind the photo library's back (storage cleanup):
  /// re-read it so deleted photos and videos leave the decks.
  Future<void> refreshAfterFileChanges() {
    _epoch++;
    return load(quiet: true);
  }

  /// Forgets every decision in [deck] so its items come back to be swiped
  /// again (in every deck they belong to). Items waiting in the bin are taken
  /// out of it; items already deleted are gone and unaffected.
  /// Returns how many items came back.
  int reviewAgain(Deck deck) {
    var count = 0;
    for (final a in deck.assets) {
      final wasKept = _kept.remove(a.id);
      final wasBinned = _trashSet.remove(a.id);
      if (wasBinned) _trash.remove(a.id);
      if (wasKept || wasBinned) {
        _stamps.remove(a.id);
        count++;
      }
    }
    if (count > 0) {
      _scheduleSave();
      _notify();
    }
    return count;
  }

  Future<void> resetProgress() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    _kept.clear();
    _trash.clear();
    _trashSet.clear();
    _stamps.clear();
    await store.resetProgress();
    _notify();
  }

  // ----------------------------------------------------------- persistence

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    String encode(String id) => DecisionStore.encode(id, _stamps[id]);
    await Future.wait([
      store.saveKept(_kept.map(encode)),
      store.saveTrash(_trash.map(encode)),
    ]);
  }

  /// Async work can finish after the controller is gone.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }
}
