import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../widgets/common.dart';
import 'viewer_screen.dart';

/// Everything swiped left, waiting for one confirmed delete.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ReviewScreen());

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  /// Items the user tapped to keep after all.
  final Set<String> _rescued = {};
  bool _deleting = false;
  Future<int>? _sizeFuture;
  int _sizeFor = -1;

  Future<int> _toDeleteSize(AppController app, List<AssetEntity> toDelete) {
    final key = Object.hashAll(toDelete.map((a) => a.id));
    if (key != _sizeFor || _sizeFuture == null) {
      _sizeFor = key;
      _sizeFuture = app.repo.totalSize(toDelete);
    }
    return _sizeFuture!;
  }

  void _toggle(AssetEntity a) {
    HapticFeedback.selectionClick();
    setState(
      () =>
          _rescued.contains(a.id) ? _rescued.remove(a.id) : _rescued.add(a.id),
    );
  }

  void _keepRescued(AppController app) {
    final n = _rescued.length;
    app.restore(_rescued.toList());
    setState(_rescued.clear);
    _snack('${plural(n, 'item')} moved back to your library');
  }

  Future<void> _delete(AppController app, List<AssetEntity> toDelete) async {
    setState(() => _deleting = true);
    try {
      final outcome = await app.deleteForever(toDelete);
      if (!mounted) return;
      if (outcome.cancelled) {
        _snack('Nothing was deleted');
        return;
      }
      if (_rescued.isNotEmpty) {
        app.restore(_rescued.toList());
        _rescued.clear();
      }
      HapticFeedback.heavyImpact();
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _SuccessSheet(outcome: outcome),
      );
    } catch (e) {
      if (mounted) _snack('Could not delete: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final app = AppScope.of(context);
    final items = app.trashAssets;
    final present = {for (final a in items) a.id};
    _rescued.removeWhere((id) => !present.contains(id));
    final toDelete = items.where((a) => !_rescued.contains(a.id)).toList();

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Review bin', style: AppText.title(color: p.text)),
                        const SizedBox(height: 2),
                        FutureBuilder<int>(
                          future: _toDeleteSize(app, items),
                          builder: (context, snap) => Text(
                            items.isEmpty
                                ? 'Empty'
                                : '${plural(items.length, 'item')}'
                                      '${snap.hasData ? ' · ${formatBytes(snap.data!)}' : ''}',
                            style: AppText.caption(color: p.textDim),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyBin()
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            child: _InfoNote(
                              text: Platform.isIOS
                                  ? 'Tap anything you want to keep. Deleted items stay in Recently Deleted for 30 days.'
                                  : 'Tap anything you want to keep. Deleted items go to your device\'s trash where supported.',
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 6,
                                  crossAxisSpacing: 6,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final a = items[i];
                              return _BinTile(
                                key: ValueKey(a.id),
                                asset: a,
                                rescued: _rescued.contains(a.id),
                                onTap: () => _toggle(a),
                                onLongPress: () =>
                                    Navigator.of(context)
                                        .push(ViewerScreen.route(a)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: items.isEmpty
          ? null
          : _BottomBar(
              rescuedCount: _rescued.length,
              deleteCount: toDelete.length,
              sizeFuture: _toDeleteSize(app, toDelete),
              busy: _deleting,
              onKeep: () => _keepRescued(app),
              onDelete: toDelete.isEmpty ? null : () => _delete(app, toDelete),
            ),
    );
  }
}

class _BinTile extends StatelessWidget {
  const _BinTile({
    super.key,
    required this.asset,
    required this.rescued,
    required this.onTap,
    required this.onLongPress,
  });

  final AssetEntity asset;
  final bool rescued;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: rescued ? 0.9 : 1,
        duration: Motion.medium,
        curve: Motion.emphasized,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetThumb(asset: asset, size: 320),
              AnimatedContainer(
                duration: Motion.medium,
                decoration: BoxDecoration(
                  color: rescued
                      ? Colors.black.withValues(alpha: 0.45)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: rescued ? p.keep : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              if (asset.type == AssetType.video)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Text(
                    formatDuration(asset.videoDuration),
                    style: AppText.caption(color: Colors.white).copyWith(
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: rescued
                      ? Container(
                          key: const ValueKey('kept'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: p.keep,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Keep',
                                style: AppText.w(
                                  10,
                                  FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('del'),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: p.delete,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: p.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.label(color: p.textDim).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.rescuedCount,
    required this.deleteCount,
    required this.sizeFuture,
    required this.busy,
    required this.onKeep,
    required this.onDelete,
  });

  final int rescuedCount;
  final int deleteCount;
  final Future<int> sizeFuture;
  final bool busy;
  final VoidCallback onKeep;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bg.withValues(alpha: 0), p.bg, p.bg],
          stops: const [0, 0.3, 1],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        30,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.emphasized,
            child: rescuedCount == 0
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 120,
                      child: SecondaryButton(
                        label: 'Keep $rescuedCount',
                        icon: Icons.undo_rounded,
                        onTap: busy ? null : onKeep,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: FutureBuilder<int>(
              future: sizeFuture,
              builder: (context, snap) => PrimaryButton(
                label: deleteCount == 0
                    ? 'Nothing to delete'
                    : 'Delete $deleteCount${snap.hasData && snap.data! > 0 ? ' · ${formatBytes(snap.data!)}' : ''}',
                icon: Icons.delete_rounded,
                color: p.delete,
                busy: busy,
                onTap: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBin extends StatelessWidget {
  const _EmptyBin();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: p.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 42,
                color: p.textFaint,
              ),
            ),
            const SizedBox(height: 22),
            Text('The bin is empty', style: AppText.title(color: p.text)),
            const SizedBox(height: 8),
            Text(
              'Swipe left on anything you don\'t need. It waits here until you delete it.',
              textAlign: TextAlign.center,
              style: AppText.body(color: p.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.outcome});
  final DeleteOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        20 + MediaQuery.paddingOf(context).bottom * 0.5,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.keep.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.check_rounded, size: 44, color: p.keep),
            ),
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: outcome.bytes.toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              formatBytes(v.round()),
              style: AppText.display(color: p.text),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'freed from ${plural(outcome.count, 'item')}',
            style: AppText.body(color: p.textDim),
          ),
          const SizedBox(height: 26),
          PrimaryButton(
            label: 'Done',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
