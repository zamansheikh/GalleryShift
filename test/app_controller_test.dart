import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_shift/data/decision_store.dart';
import 'package:gallery_shift/data/gallery_repository.dart';
import 'package:gallery_shift/models/deck.dart';
import 'package:gallery_shift/state/app_controller.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

AssetEntity _asset(String id) =>
    AssetEntity(id: id, typeInt: 1, width: 300, height: 400);

Deck _deck(String id, List<AssetEntity> assets) => Deck(
  id: id,
  kind: DeckKind.month,
  title: id,
  subtitle: '2026',
  icon: Icons.calendar_month_rounded,
  assets: assets,
);

void main() {
  late AppController app;
  final march = [_asset('m1'), _asset('m2'), _asset('m3')];
  final april = [_asset('a1'), _asset('a2')];
  final marchDeck = _deck('march', march);
  final aprilDeck = _deck('april', april);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app = AppController(
      repo: GalleryRepository(),
      store: await DecisionStore.open(),
    );
  });

  tearDown(() => app.dispose());

  test('reviewAgain brings back kept and binned items of one deck only', () {
    app.decide(march[0], Decision.keep);
    app.decide(march[1], Decision.delete);
    app.decide(april[0], Decision.keep);
    app.decide(april[1], Decision.delete);

    expect(app.decidedCount(marchDeck), 2);
    expect(app.binCountIn(marchDeck), 1);

    final back = app.reviewAgain(marchDeck);

    expect(back, 2);
    expect(app.decidedCount(marchDeck), 0);
    expect(app.remainingCount(marchDeck), 3);
    expect(app.binCountIn(marchDeck), 0);
    // April is untouched.
    expect(app.decidedCount(aprilDeck), 2);
    expect(app.binCountIn(aprilDeck), 1);
  });

  test('reviewAgain on an untouched deck changes nothing', () {
    var notified = 0;
    app.addListener(() => notified++);
    expect(app.reviewAgain(aprilDeck), 0);
    expect(notified, 0);
  });

  test('reviewAgain persists', () async {
    app.decide(march[0], Decision.keep);
    app.decide(march[1], Decision.delete);
    app.reviewAgain(marchDeck);
    await app.flush();

    final reopened = AppController(
      repo: GalleryRepository(),
      store: await DecisionStore.open(),
    );
    expect(reopened.decidedCount(marchDeck), 0);
    reopened.dispose();
  });

  test('an empty library loads to the ready state, not an error', () async {
    final empty = AppController(
      repo: _FakeRepo(const []),
      store: await DecisionStore.open(),
    );
    await empty.load();
    expect(empty.loadState, LoadState.ready);
    expect(empty.libraryCount, 0);
    empty.dispose();
  });

  test('load sorts the library newest first by capture date', () async {
    AssetEntity at(String id, int year) => AssetEntity(
      id: id,
      typeInt: 1,
      width: 1,
      height: 1,
      createDateSecond: DateTime(year).millisecondsSinceEpoch ~/ 1000,
    );
    final loaded = AppController(
      // Platform order (e.g. Android's date-added) is not capture order.
      repo: _FakeRepo([at('old', 2020), at('new', 2026), at('mid', 2023)]),
      store: await DecisionStore.open(),
    );
    await loaded.load();
    expect(loaded.quickDecks.first.assets.map((a) => a.id), [
      'new',
      'mid',
      'old',
    ]);
    loaded.dispose();
  });

  group('stats', () {
    test('recordFreed updates the total and tells listeners at once', () async {
      var notified = 0;
      app.addListener(() => notified++);
      await app.recordFreed(bytes: 5000);
      expect(app.freedBytes, 5000);
      expect(app.deletedCount, 0); // storage cleanup: not a photo
      expect(notified, 1);

      await app.recordFreed(bytes: 0);
      expect(notified, 1); // nothing changed, nothing to redraw
    });

    test('deleting from the bin counts bytes and items once', () async {
      final a = _photo('a', 2020), b = _photo('b', 2021);
      final repo = _FakeRepo([a, b], sizes: {'a': 1000, 'b': 3000});
      final c = AppController(repo: repo, store: await DecisionStore.open());
      await c.load();
      c.decide(a, Decision.delete);
      c.decide(b, Decision.delete);

      final outcome = await c.deleteForever([a, b]);

      expect(outcome.count, 2);
      expect(outcome.bytes, 4000);
      expect(c.freedBytes, 4000);
      expect(c.deletedCount, 2);
      expect(c.libraryCount, 0);
      expect(c.trashCount, 0);
      c.dispose();
    });

    test('a cancelled system prompt changes nothing', () async {
      final a = _photo('a', 2020);
      final repo = _FakeRepo([a], sizes: {'a': 1000})..declineDelete = true;
      final c = AppController(repo: repo, store: await DecisionStore.open());
      await c.load();
      c.decide(a, Decision.delete);

      final outcome = await c.deleteForever([a]);

      expect(outcome.cancelled, isTrue);
      expect(c.freedBytes, 0);
      expect(c.trashCount, 1);
      c.dispose();
    });

    test('files sent to the system trash are remembered, once each', () async {
      final a = _photo('a', 2020, title: 'IMG_1.jpg');
      final repo = _FakeRepo([a], sizes: {'a': 1000})..toTrash = true;
      final store = await DecisionStore.open();
      final c = AppController(repo: repo, store: store);
      await c.load();
      c.decide(a, Decision.delete);

      final outcome = await c.deleteForever([a]);
      expect(outcome.inTrash, isTrue);

      // Storage cleanup later finds the leftover: ours, so already counted.
      expect(await store.takeTrashed(['IMG_1.jpg', 'other.jpg']), [
        true,
        false,
      ]);
      // ...and only the once.
      expect(await store.takeTrashed(['IMG_1.jpg']), [false]);
      c.dispose();
    });
  });

  group('decisions never follow an ID onto another photo', () {
    test('a reassigned ID drops the old decision', () async {
      final store = await DecisionStore.open();
      final first = AppController(
        repo: _FakeRepo([_photo('7', 2020), _photo('8', 2021)]),
        store: store,
      );
      await first.load();
      first.decide(_photo('7', 2020), Decision.delete);
      first.decide(_photo('8', 2021), Decision.keep);
      await first.flush();
      first.dispose();

      // Same IDs, but the media database was rebuilt (new phone, restore):
      // 7 is now a different photo. 8 is still the same one.
      final second = AppController(
        repo: _FakeRepo([_photo('7', 2024), _photo('8', 2021)]),
        store: store,
      );
      await second.load();

      expect(second.trashCount, 0, reason: 'must not queue a stranger');
      expect(second.isReviewed('7'), isFalse);
      expect(second.isReviewed('8'), isTrue);
      second.dispose();
    });

    test('decisions saved by an older version are kept and adopted', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.kept_ids': ['7'],
        'flutter.trash_ids': ['8'],
      });
      final store = await DecisionStore.open();
      final c = AppController(
        repo: _FakeRepo([_photo('7', 2020), _photo('8', 2021)]),
        store: store,
      );
      await c.load();
      expect(c.isReviewed('7'), isTrue);
      expect(c.trashCount, 1);

      await c.flush();
      expect(store.loadKept().single, startsWith('7|'));
      expect(store.loadTrash().single, startsWith('8|'));
      c.dispose();
    });

    test('keeping then binning the same photo leaves one decision', () {
      app.decide(march[0], Decision.keep);
      app.decide(march[0], Decision.delete);
      expect(app.binCountIn(marchDeck), 1);
      app.decide(march[0], Decision.keep);
      expect(app.binCountIn(marchDeck), 0);
      expect(app.decidedCount(marchDeck), 1);
    });
  });

  group('reloading', () {
    test('a read that started before a delete is not put back', () async {
      final a = _photo('a', 2020), b = _photo('b', 2021);
      final repo = _FakeRepo([a, b], sizes: {'a': 10, 'b': 10});
      final c = AppController(repo: repo, store: await DecisionStore.open());
      await c.load();
      c.decide(a, Decision.delete);

      // A reload begins and is still reading the old library...
      final gate = Completer<void>();
      repo.gate = gate;
      final reload = c.load(quiet: true);
      await pumpEventQueue();
      // ...while the delete completes.
      await c.deleteForever([a]);
      expect(c.libraryCount, 1);

      gate.complete();
      await reload;
      expect(c.libraryCount, 1, reason: 'the deleted photo must stay gone');
      expect(repo.reads, greaterThanOrEqualTo(3), reason: 'it read again');
      c.dispose();
    });

    test('a finished delete after dispose does not throw', () async {
      final a = _photo('a', 2020);
      final c = AppController(
        repo: _FakeRepo([a], sizes: {'a': 10}),
        store: await DecisionStore.open(),
      );
      await c.load();
      c.dispose();
      await c.recordFreed(bytes: 10);
    });
  });
}

AssetEntity _photo(String id, int year, {String? title}) => AssetEntity(
  id: id,
  typeInt: 1,
  width: 1,
  height: 1,
  title: title,
  createDateSecond: DateTime(year).millisecondsSinceEpoch ~/ 1000,
);

/// Serves a fixed library, the way the plugin can: possibly unmodifiable.
class _FakeRepo extends GalleryRepository {
  _FakeRepo(this.assets, {this.sizes = const {}});
  List<AssetEntity> assets;
  final Map<String, int> sizes;
  bool declineDelete = false;
  bool toTrash = false;
  int reads = 0;

  /// When set, a read captures the library, then waits here before
  /// answering: a slow read that can go stale.
  Completer<void>? gate;

  @override
  Future<List<AssetEntity>> loadLibrary() async {
    reads++;
    final snapshot = List<AssetEntity>.unmodifiable(assets);
    final wait = gate;
    if (wait != null) {
      gate = null;
      await wait.future;
    }
    return snapshot;
  }

  @override
  Future<Set<String>> loadScreenshotIds() async => const {};

  @override
  Future<int> fileSize(AssetEntity asset) async => sizes[asset.id] ?? 0;

  @override
  Future<bool> get deletesGoToTrash async => toTrash;

  @override
  Future<List<String>> delete(List<AssetEntity> assets) async {
    if (declineDelete) return const [];
    final ids = [for (final a in assets) a.id];
    this.assets = [
      for (final a in this.assets)
        if (!ids.contains(a.id)) a,
    ];
    return ids;
  }
}
