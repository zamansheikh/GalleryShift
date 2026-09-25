import 'package:flutter/material.dart';

import '../../models/deck.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import 'common.dart';

/// "September 2026" for a month deck, the title otherwise.
String deckName(Deck deck) =>
    deck.kind == DeckKind.month ? '${deck.title} ${deck.subtitle}' : deck.title;

/// Asks, then forgets every decision in [deck] so it can be swiped again.
/// Returns true if the user went ahead.
Future<bool> confirmReviewAgain(BuildContext context, Deck deck) async {
  final app = AppScope.read(context);
  final p = Palette.of(context);
  final decided = app.decidedCount(deck);
  if (decided == 0) return false;
  final inBin = app.binCountIn(deck);
  final name = deckName(deck);

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Review $name again?', style: AppText.title(color: p.text)),
      content: Text(
        '${plural(decided, 'item')} come back into the deck so you can decide '
        'again.${inBin > 0 ? ' ${formatCount(inBin)} waiting in the bin will be taken out of it.' : ''} '
        'Nothing is deleted.',
        style: AppText.body(color: p.textDim),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text('Cancel', style: AppText.label(color: p.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text('Review again', style: AppText.label(color: p.accent)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  // No snackbar: the deck refilling is the feedback, and a snackbar would
  // cover the swipe buttons.
  app.reviewAgain(deck);
  return true;
}

/// Long-press menu for a deck tile: progress, start, review again.
Future<void> showDeckSheet(
  BuildContext context,
  Deck deck, {
  required VoidCallback onOpen,
}) {
  final p = Palette.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheet) {
      final app = AppScope.of(sheet);
      final total = deck.assets.length;
      final left = app.remainingCount(deck);
      final decided = total - left;
      final cover = app.coverFor(deck);
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: p.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox.square(
                      dimension: 64,
                      child: cover == null
                          ? ColoredBox(color: p.surfaceHigh)
                          : AssetThumb(asset: cover, size: 200),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deckName(deck),
                          style: AppText.title(color: p.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          left == 0
                              ? 'All ${formatCount(total)} sorted'
                              : '${formatCount(decided)} of ${formatCount(total)} sorted',
                          style: AppText.label(color: p.textDim),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 1 : decided / total,
                            minHeight: 4,
                            backgroundColor: p.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation(
                              left == 0 ? p.keep : p.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (left > 0) ...[
                PrimaryButton(
                  label: decided == 0
                      ? 'Start swiping'
                      : 'Continue · ${formatCount(left)} left',
                  icon: Icons.swipe_rounded,
                  onTap: () {
                    Navigator.pop(sheet);
                    onOpen();
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (decided > 0)
                SecondaryButton(
                  label: 'Review again',
                  icon: Icons.restart_alt_rounded,
                  onTap: () async {
                    Navigator.pop(sheet);
                    final reset = await confirmReviewAgain(context, deck);
                    if (reset && context.mounted) onOpen();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
