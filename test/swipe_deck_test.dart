import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_shift/models/deck.dart';
import 'package:gallery_shift/theme/app_theme.dart';
import 'package:gallery_shift/ui/widgets/swipe_deck.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  final assets = [
    for (var i = 0; i < 3; i++)
      AssetEntity(id: 'a$i', typeInt: 1, width: 300, height: 400),
  ];

  Future<List<(String, Decision)>> pumpDeck(
    WidgetTester tester,
    SwipeDeckController ctrl,
  ) async {
    final decided = <(String, Decision)>[];
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: SizedBox(
              width: 360,
              height: 520,
              child: SwipeDeck(
                items: assets,
                index: index,
                controller: ctrl,
                cardBuilder: (_, a) =>
                    Container(key: Key('card-${a.id}'), color: Colors.blueGrey),
                onDecided: (a, d) {
                  decided.add((a.id, d));
                  setState(() => index++);
                },
              ),
            ),
          ),
        ),
      ),
    );
    return decided;
  }

  testWidgets('dragging right past the threshold keeps', (tester) async {
    final ctrl = SwipeDeckController();
    final decided = await pumpDeck(tester, ctrl);
    await tester.drag(find.byKey(const Key('card-a0')), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(decided, [('a0', Decision.keep)]);
    expect(find.byKey(const Key('card-a0')), findsNothing);
  });

  testWidgets('dragging left past the threshold deletes', (tester) async {
    final ctrl = SwipeDeckController();
    final decided = await pumpDeck(tester, ctrl);
    await tester.drag(find.byKey(const Key('card-a0')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(decided, [('a0', Decision.delete)]);
  });

  testWidgets('a short slow drag springs back without deciding', (
    tester,
  ) async {
    final ctrl = SwipeDeckController();
    final decided = await pumpDeck(tester, ctrl);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('card-a0'))),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(ctrl.progress.value, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(decided, isEmpty);
    expect(ctrl.progress.value, closeTo(0, 0.05));
  });

  testWidgets('button swipes decide in order', (tester) async {
    final ctrl = SwipeDeckController();
    final decided = await pumpDeck(tester, ctrl);
    ctrl.swipe(Decision.delete);
    await tester.pumpAndSettle();
    ctrl.swipe(Decision.keep);
    await tester.pumpAndSettle();
    expect(decided, [('a0', Decision.delete), ('a1', Decision.keep)]);
    expect(find.byKey(const Key('card-a2')), findsOneWidget);
  });
}
