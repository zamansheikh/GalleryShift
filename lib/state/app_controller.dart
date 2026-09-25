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
  const DeleteOutcome({required this.count, required this.bytes});
  final int count;
  final int bytes;
  bool get cancelled => count == 0;
}

/// App-wide state: permission, library, decisions and stats.
class AppController extends ChangeNotifier {
  AppController({required this.repo, required this.store}) {
    _kept = store.loadKept();
    _trash = List.of(store.loadTrash());
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
  late Set<String> _kept;
  late List<String> _trash;
  Set<String> _trashSet = {};

  List<Deck> quickDecks = const [];
  List<Deck> monthDecks = const [];

  Timer? _saveTimer;
  bool _refreshing = false;

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

  AssetEntity? coverFor(Deck deck) {
    for (final a in deck.assets) {
      if (!isReviewed(a.id)) return a;
    }
    return deck.assets.isEmpty ? null : deck.assets.first;
  }

  // ------------------------------------------------------------- lifecycle

  Future<void> bootstrap() async {
    permission = await repo.permissionState();
    notifyListeners();
    if (hasAccess) await load();
  }

  Future<PermissionState> requestAccess() async {
    permission = await repo.requestPermission();
    askedForAccess = true;
    notifyListeners();
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
    if (permission != before) notifyListeners();
    if (hasAccess) await load(quiet: true);
  }

  Future<void> load({bool quiet = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!quiet || loadState != LoadState.ready) {
      loadState = LoadState.loading;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        repo.loadLibrary(),
        repo.loadScreenshotIds(),
      ]);
      _library = results[0] as List<AssetEntity>;
      _screenshotIds = results[1] as Set<String>;
      _byId = {for (final a in _library) a.id: a};
      _pruneMissing();
      _buildDecks();
      loadState = LoadState.ready;
      loadError = null;
    } catch (e, st) {
      debugPrint('Library load failed: $e\n$st');
      loadError = e;
      if (loadState != LoadState.ready) loadState = LoadState.error;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Drop decisions for assets that no longer exist (deleted elsewhere).
  void _pruneMissing() {
    final trashBefore = _trash.length;
    _trash.removeWhere((id) => !_byId.containsKey(id));
    _trashSet = _trash.toSet();
    final keptBefore = _kept.length;
    _kept.removeWhere((id) => !_byId.containsKey(id));
    if (_trash.length != trashBefore || _kept.length != keptBefore) {
      _scheduleSave();
    }
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
    if (decision == Decision.keep) {
      _kept.add(asset.id);
    } else {
      _trash.remove(asset.id);
      _trash.add(asset.id);
      _trashSet.add(asset.id);
    }
    _scheduleSave();
    notifyListeners();
  }

  void undo(AssetEntity asset) {
    _kept.remove(asset.id);
    if (_trashSet.remove(asset.id)) _trash.remove(asset.id);
    _scheduleSave();
    notifyListeners();
  }

  /// Take items out of the bin without deciding on them again: they count as
  /// kept, so they don't come back into the decks.
  void restore(Iterable<String> ids) {
    for (final id in ids) {
      if (_trashSet.remove(id)) _trash.remove(id);
      _kept.add(id);
    }
    _scheduleSave();
    notifyListeners();
  }

  Future<DeleteOutcome> deleteForever(List<AssetEntity> assets) async {
    final bytes = {for (final a in assets) a.id: await repo.fileSize(a)};
    final deleted = (await repo.delete(assets)).toSet();
    if (deleted.isEmpty) return const DeleteOutcome(count: 0, bytes: 0);

    final freed = deleted.fold<int>(0, (sum, id) => sum + (bytes[id] ?? 0));
    _trash.removeWhere(deleted.contains);
    _trashSet.removeAll(deleted);
    _library = _library.where((a) => !deleted.contains(a.id)).toList();
    _byId = {for (final a in _library) a.id: a};
    _buildDecks();
    await store.addFreed(bytes: freed, count: deleted.length);
    _scheduleSave();
    notifyListeners();
    return DeleteOutcome(count: deleted.length, bytes: freed);
  }

  Future<void> resetProgress() async {
    _kept.clear();
    _trash.clear();
    _trashSet.clear();
    await store.resetProgress();
    notifyListeners();
  }

  // ----------------------------------------------------------- persistence

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await Future.wait([store.saveKept(_kept), store.saveTrash(_trash)]);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
