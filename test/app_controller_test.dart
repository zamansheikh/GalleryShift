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
}

/// Serves a fixed library, the way the plugin can: possibly unmodifiable.
class _FakeRepo extends GalleryRepository {
  _FakeRepo(this.assets);
  final List<AssetEntity> assets;

  @override
  Future<List<AssetEntity>> loadLibrary() async => List.unmodifiable(assets);

  @override
  Future<Set<String>> loadScreenshotIds() async => const {};
}
