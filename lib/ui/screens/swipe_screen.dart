import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/deck.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../widgets/asset_card.dart';
import '../widgets/common.dart';
import '../widgets/deck_actions.dart';
import '../widgets/swipe_deck.dart';
import 'review_screen.dart';
import 'viewer_screen.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key, required this.deck});
  final Deck deck;

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final _deckCtrl = SwipeDeckController();
  late final AppController _app = AppScope.read(context);
  late List<AssetEntity> _queue = _app.sessionQueue(widget.deck);
  late final Set<String> _screenshots = {
    for (final d in _app.quickDecks)
      if (d.kind == DeckKind.screenshots) ...d.assets.map((a) => a.id),
  };

  /// Card videos play only while nothing covers this screen.
  final _videoFocus = ValueNotifier<bool>(true);
  late final _muted = ValueNotifier<bool>(_app.store.videoMuted);

  final List<(AssetEntity, Decision)> _history = [];
  int _index = 0;
  bool _showHint = false;

  int get _keptInSession => _history.where((h) => h.$2 == Decision.keep).length;
  int get _deletedInSession => _history.length - _keptInSession;
  bool get _done => _index >= _queue.length;

  @override
  void initState() {
    super.initState();
    _showHint = !_app.store.swipeHintSeen && _queue.isNotEmpty;
    _muted.addListener(() => _app.store.setVideoMuted(_muted.value));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precache();
      if (_showHint) _deckCtrl.demo();
    });
  }

  @override
  void dispose() {
    _deckCtrl.dispose();
    _videoFocus.dispose();
    _muted.dispose();
    _app.flush();
    super.dispose();
  }

  void _precache() {
    for (var i = _index + 1; i <= _index + 4 && i < _queue.length; i++) {
      precacheImage(cardImageFor(_queue[i]), context);
      precacheImage(backdropImageFor(_queue[i]), context);
      _app.repo.fileSize(_queue[i]);
    }
  }

  void _onDecided(AssetEntity asset, Decision d) {
    _app.decide(asset, d);
    setState(() {
      _history.add((asset, d));
      _index++;
      if (_showHint) {
        _showHint = false;
        _app.store.setSwipeHintSeen();
      }
    });
    if (_done) HapticFeedback.heavyImpact();
    _precache();
  }

  void _undo() {
    if (_deckCtrl.isAnimating) return;
    // Anything emptied from the bin since can't come back.
    // History entry k is the decision on _queue[k], so drop both together.
    while (_history.isNotEmpty && !_app.exists(_history.last.$1.id)) {
      _history.removeLast();
      _queue.removeAt(--_index);
    }
    if (_history.isEmpty) {
      setState(() {});
      return;
    }
    HapticFeedback.lightImpact();
    final (asset, decision) = _history.removeLast();
    _app.undo(asset);
    setState(() => _index--);
    _deckCtrl.returnCard(decision);
  }

  /// Pauses card videos while [route] is open.
  Future<T?> _cover<T>(Route<T> route) async {
    _videoFocus.value = false;
    final result = await Navigator.of(context).push(route);
    if (mounted) _videoFocus.value = true;
    return result;
  }

  Future<void> _openViewer(
    AssetEntity asset, [
    Duration startAt = Duration.zero,
  ]) async {
    final decision = await _cover(
      ViewerScreen.route(asset, showActions: true, startAt: startAt),
    );
    if (decision != null && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _deckCtrl.swipe(decision);
    }
  }

  void _openBin() => _cover(ReviewScreen.route());

  Future<void> _reviewAgain() async {
    if (!await confirmReviewAgain(context, widget.deck) || !mounted) return;
    setState(() {
      _queue = _app.sessionQueue(widget.deck);
      _index = 0;
      _history.clear();
    });
    _precache();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final app = AppScope.of(context);
    final total = _queue.length;
    final position = (_index + 1).clamp(0, total);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.deck.title,
                          style: AppText.headline(color: p.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: Motion.fast,
                          child: Text(
                            _done
                                ? 'Finished'
                                : '${formatCount(position)} of ${formatCount(total)}',
                            key: ValueKey(_done ? -1 : position),
                            style: AppText.caption(color: p.textDim),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Review bin',
                    badge: app.trashCount,
                    onTap: _openBin,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: _ProgressBar(value: total == 0 ? 1 : _index / total),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
                child: AnimatedSwitcher(
                  duration: Motion.slow,
                  switchInCurve: Motion.emphasized,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.94, end: 1.0).animate(a),
                      child: child,
                    ),
                  ),
                  child: _done
                      ? _Finished(
                          key: const ValueKey('done'),
                          kept: _keptInSession,
                          deleted: _deletedInSession,
                          wasEmpty: total == 0,
                          binCount: app.trashCount,
                          onReview: _openBin,
                          onUndo: _history.isEmpty ? null : _undo,
                          deckName: deckName(widget.deck),
                          onReviewAgain: _app.decidedCount(widget.deck) > 0
                              ? _reviewAgain
                              : null,
                        )
                      : SwipeDeck(
                          key: const ValueKey('deck'),
                          items: _queue,
                          index: _index,
                          controller: _deckCtrl,
                          onDecided: _onDecided,
                          onTap: _openViewer,
                          cardBuilder: (context, asset, depth) => AssetCard(
                            asset: asset,
                            repo: _app.repo,
                            isScreenshot: _screenshots.contains(asset.id),
                            depth: depth,
                            videoFocus: _videoFocus,
                            muted: _muted,
                            onFullscreen: (at) => _openViewer(asset, at),
                          ),
                        ),
                ),
              ),
            ),
            AnimatedSize(
              duration: Motion.medium,
              curve: Motion.ease,
              child: _done
                  ? const SizedBox(width: double.infinity, height: 8)
                  : _ActionBar(
                      progress: _deckCtrl.progress,
                      showHint: _showHint,
                      canUndo: _history.isNotEmpty,
                      onDelete: () => _deckCtrl.swipe(Decision.delete),
                      onKeep: () => _deckCtrl.swipe(Decision.keep),
                      onUndo: _undo,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: Motion.medium,
        curve: Motion.emphasized,
        builder: (context, v, _) => FractionallySizedBox(
          widthFactor: v,
          // The parent's alignment loosens constraints; without this the
          // fill collapses to zero height.
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: p.accentGradient,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.progress,
    required this.showHint,
    required this.canUndo,
    required this.onDelete,
    required this.onKeep,
    required this.onUndo,
  });

  final ValueListenable<double> progress;
  final bool showHint;
  final bool canUndo;
  final VoidCallback onDelete;
  final VoidCallback onKeep;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: showHint ? 1 : 0,
            duration: Motion.medium,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 16, color: p.delete),
                  const SizedBox(width: 6),
                  Text(
                    'Swipe to delete',
                    style: AppText.caption(color: p.textDim),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: p.textFaint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    'Swipe to keep',
                    style: AppText.caption(color: p.textDim),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: p.keep),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, v, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RoundAction(
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  color: p.delete,
                  size: 74,
                  engaged: v < 0 ? -v : 0,
                  onTap: onDelete,
                ),
                _RoundAction(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  color: p.textDim,
                  size: 54,
                  engaged: 0,
                  onTap: canUndo ? onUndo : null,
                ),
                _RoundAction(
                  icon: Icons.check_rounded,
                  label: 'Keep',
                  color: p.keep,
                  size: 74,
                  engaged: v > 0 ? v : 0,
                  onTap: onKeep,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  static const double _slot = 74;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    required this.engaged,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double size;

  /// 0..1 — how far the current drag leans toward this action.
  final double engaged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final e = Curves.easeOut.transform(engaged.clamp(0.0, 1.0));
    final fill = Color.lerp(p.surface, color, e)!;
    final iconColor = Color.lerp(color, Colors.white, e)!;

    return Pressable(
      onTap: onTap,
      haptic: false,
      semanticLabel: label,
      scale: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Every button gets the same slot so the labels line up.
          SizedBox(
            height: _slot,
            child: Center(
              child: Transform.scale(
                scale: 1 + 0.12 * e,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: Border.all(
                      color: Color.lerp(p.stroke, color, 0.35 + 0.65 * e)!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.12 + 0.35 * e),
                        blurRadius: 18 + 14 * e,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: size * 0.42),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppText.caption(color: p.textDim)),
        ],
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({
    super.key,
    required this.kept,
    required this.deleted,
    required this.wasEmpty,
    required this.binCount,
    required this.onReview,
    required this.onUndo,
    required this.deckName,
    required this.onReviewAgain,
  });

  final int kept;
  final int deleted;
  final bool wasEmpty;
  final int binCount;
  final VoidCallback onReview;
  final VoidCallback? onUndo;
  final String deckName;
  final VoidCallback? onReviewAgain;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: p.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Icon(
                  wasEmpty ? Icons.done_all_rounded : Icons.celebration_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              wasEmpty ? 'Nothing left here' : 'Deck complete',
              style: AppText.display(color: p.text).copyWith(fontSize: 30),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              wasEmpty
                  ? 'You\u2019ve already sorted everything in $deckName.'
                  : 'You kept ${plural(kept, 'item')} and set aside ${formatCount(deleted)} to delete.',
              style: AppText.body(color: p.textDim),
              textAlign: TextAlign.center,
            ),
            if (!wasEmpty) ...[
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _Tally(value: kept, label: 'Kept', color: p.keep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Tally(
                      value: deleted,
                      label: 'To delete',
                      color: p.delete,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 30),
            // A finished deck opened again: reviewing it is the main action.
            if (wasEmpty && onReviewAgain != null) ...[
              PrimaryButton(
                label: 'Review again',
                icon: Icons.restart_alt_rounded,
                onTap: onReviewAgain,
              ),
              const SizedBox(height: 12),
            ],
            if (binCount > 0) ...[
              PrimaryButton(
                label: 'Review & delete $binCount',
                icon: Icons.delete_sweep_rounded,
                onTap: onReview,
              ),
              const SizedBox(height: 12),
            ],
            SecondaryButton(
              label: 'Back to decks',
              onTap: () => Navigator.of(context).pop(),
            ),
            if (!wasEmpty && onReviewAgain != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onReviewAgain,
                icon: Icon(
                  Icons.restart_alt_rounded,
                  color: p.textDim,
                  size: 18,
                ),
                label: Text(
                  'Review this deck again',
                  style: AppText.label(color: p.textDim),
                ),
              ),
            ],
            if (onUndo != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onUndo,
                icon: Icon(Icons.undo_rounded, color: p.textDim, size: 18),
                label: Text(
                  'Undo last swipe',
                  style: AppText.label(color: p.textDim),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.value, required this.label, required this.color});
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            formatCount(value),
            style: AppText.title(color: color).copyWith(fontSize: 26),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption(color: p.textDim)),
        ],
      ),
    );
  }
}
