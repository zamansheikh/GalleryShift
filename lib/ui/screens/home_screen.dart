import 'package:flutter/material.dart';

import '../../models/deck.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../widgets/common.dart';
import 'review_screen.dart';
import 'swipe_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Deck deck) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SwipeScreen(deck: deck)));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final app = AppScope.of(context);

    if (app.loadState == LoadState.error && app.libraryCount == 0) {
      return _ErrorState(onRetry: app.load);
    }
    final loading = app.loadState != LoadState.ready;

    return Scaffold(
      backgroundColor: p.bg,
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        onRefresh: () => app.load(quiet: true),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(child: _Header(app: app)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList.list(
                children: [
                  _Greeting(),
                  const SizedBox(height: 20),
                  loading
                      ? const _Skeleton(height: 168, radius: 28)
                      : _HeroCard(app: app),
                  if (app.trashCount > 0) ...[
                    const SizedBox(height: 14),
                    _BinBanner(app: app),
                  ],
                  if (app.isLimited) ...[
                    const SizedBox(height: 14),
                    _LimitedBanner(onManage: app.repo.presentLimitedPicker),
                  ],
                  const SizedBox(height: 30),
                  _SectionTitle('Start swiping'),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 212,
                child: loading
                    ? ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, _) =>
                            const _Skeleton(width: 158, radius: 24),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: app.quickDecks.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final deck = app.quickDecks[i];
                          return _QuickDeckTile(
                            deck: deck,
                            app: app,
                            onTap: () => _open(context, deck),
                          );
                        },
                      ),
              ),
            ),
            if (loading || app.monthDecks.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(
                    'By month',
                    trailing: loading
                        ? null
                        : plural(app.monthDecks.length, 'month'),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                40 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemCount: loading ? 4 : app.monthDecks.length,
                itemBuilder: (context, i) {
                  if (loading) return const _Skeleton(radius: 24);
                  final deck = app.monthDecks[i];
                  return _MonthTile(
                    deck: deck,
                    app: app,
                    onTap: () => _open(context, deck),
                  );
                },
              ),
            ),
            if (!loading && app.libraryCount == 0)
              const SliverToBoxAdapter(child: _EmptyLibrary()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: p.accentGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.swipe_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Text('GalleryShift', style: AppText.headline(color: p.text)),
          const Spacer(),
          GlassIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Review bin',
            badge: app.trashCount,
            onTap: () => Navigator.of(context).push(ReviewScreen.route()),
          ),
          const SizedBox(width: 10),
          GlassIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'More',
            onTap: () => _showSettings(context, app),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context, AppController app) {
    final p = Palette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
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
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: p.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (app.isLimited)
                _SheetItem(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose more photos',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    app.repo.presentLimitedPicker();
                  },
                ),
              _SheetItem(
                icon: Icons.refresh_rounded,
                label: 'Rescan library',
                onTap: () {
                  Navigator.pop(sheetContext);
                  app.load();
                },
              ),
              _SheetItem(
                icon: Icons.restart_alt_rounded,
                label: 'Start over',
                detail: 'Forget every keep and delete decision',
                color: p.delete,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final ok = await _confirmReset(context);
                  if (ok == true) await app.resetProgress();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmReset(BuildContext context) {
    final p = Palette.of(context);
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Start over?', style: AppText.title(color: p.text)),
        content: Text(
          'Every photo comes back into your decks and the bin is emptied without deleting anything.',
          style: AppText.body(color: p.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel', style: AppText.label(color: p.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Start over', style: AppText.label(color: p.delete)),
          ),
        ],
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = color ?? p.text;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: c),
      title: Text(
        label,
        style: AppText.headline(color: c).copyWith(fontSize: 15),
      ),
      subtitle: detail == null
          ? null
          : Text(detail!, style: AppText.caption(color: p.textDim)),
      onTap: onTap,
    );
  }
}

class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final h = DateTime.now().hour;
    final part = h < 5
        ? 'Late night'
        : h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(part.toUpperCase(), style: AppText.overline(color: p.textFaint)),
        const SizedBox(height: 6),
        Text(
          'Let’s tidy up\nyour gallery.',
          style: AppText.display(color: p.text),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pct = (app.progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.stroke),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(p.accent.withValues(alpha: 0.10), p.surface),
            p.surface,
            Color.alphaBlend(p.accentAlt.withValues(alpha: 0.07), p.surface),
          ],
        ),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: app.progress,
            size: 112,
            stroke: 11,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pct%',
                  style: AppText.title(color: p.text).copyWith(fontSize: 26),
                ),
                Text('reviewed', style: AppText.caption(color: p.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatCount(app.reviewedCount)} of ${formatCount(app.libraryCount)}',
                  style: AppText.headline(color: p.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'photos & videos sorted',
                  style: AppText.caption(color: p.textDim),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.bolt_rounded,
                        value: formatBytes(app.freedBytes),
                        label: 'Freed',
                        color: p.keep,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.delete_rounded,
                        value: formatCount(app.deletedCount),
                        label: 'Deleted',
                        color: p.delete,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: p.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: AppText.caption(color: p.textDim)),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.headline(color: p.text)),
          ),
        ],
      ),
    );
  }
}

class _BinBanner extends StatelessWidget {
  const _BinBanner({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final items = app.trashAssets;
    final shown = items.length < 3 ? items.length : 3;
    return Pressable(
      onTap: () => Navigator.of(context).push(ReviewScreen.route()),
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          color: p.delete.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.delete.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 44,
              child: Stack(
                children: [
                  // The newest item is painted last, on top.
                  for (var i = 0; i < shown; i++)
                    Positioned(
                      left: i * 10.0,
                      child: Container(
                        width: 40,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.bg, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AssetThumb(
                            asset: items[shown - 1 - i],
                            size: 120,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plural(items.length, 'item')} in the bin',
                    style: AppText.headline(color: p.text)
                        .copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<int>(
                    future: app.repo.totalSize(items),
                    builder: (context, snap) => Text(
                      snap.hasData
                          ? 'Delete to free ${formatBytes(snap.data!)}'
                          : 'Review and delete',
                      style: AppText.caption(color: p.delete),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textDim),
          ],
        ),
      ),
    );
  }
}

class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.onManage});
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 20, color: p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You shared only some photos with GalleryShift.',
              style: AppText.label(color: p.textDim),
            ),
          ),
          TextButton(
            onPressed: onManage,
            child: Text('Add more', style: AppText.label(color: p.accent)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(text, style: AppText.title(color: p.text).copyWith(fontSize: 20)),
        const Spacer(),
        if (trailing != null)
          Text(trailing!, style: AppText.caption(color: p.textFaint)),
      ],
    );
  }
}

class _QuickDeckTile extends StatelessWidget {
  const _QuickDeckTile({
    required this.deck,
    required this.app,
    required this.onTap,
  });
  final Deck deck;
  final AppController app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final left = app.remainingCount(deck);
    final cover = app.coverFor(deck);
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 158,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: p.surfaceHigh),
              if (cover != null) AssetThumb(asset: cover, size: 420),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0, 0.35, 1],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(deck.icon, size: 18, color: Colors.white),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.title,
                      style: AppText.headline(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      left == 0 ? 'All done' : '${formatCount(left)} to go',
                      style: AppText.caption(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.deck,
    required this.app,
    required this.onTap,
  });
  final Deck deck;
  final AppController app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final total = deck.assets.length;
    final left = app.remainingCount(deck);
    final done = left == 0;
    final cover = app.coverFor(deck);
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.stroke),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: p.surfaceHigh),
                    if (cover != null)
                      AnimatedOpacity(
                        opacity: done ? 0.45 : 1,
                        duration: Motion.medium,
                        child: AssetThumb(asset: cover, size: 360),
                      ),
                    if (done)
                      Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: p.keep,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          deck.title,
                          style: AppText.headline(color: p.text)
                              .copyWith(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        deck.subtitle,
                        style: AppText.caption(color: p.textFaint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 1 : 1 - left / total,
                      minHeight: 4,
                      backgroundColor: p.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(
                        done ? p.keep : p.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    done
                        ? '${formatCount(total)} sorted'
                        : '${formatCount(left)} of ${formatCount(total)} left',
                    style: AppText.caption(color: p.textDim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton({this.width, this.height, this.radius = 20});
  final double? width;
  final double? height;
  final double radius;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            p.surface,
            p.surfaceHigh,
            Curves.easeInOut.transform(_c.value),
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
      child: Column(
        children: [
          Icon(Icons.photo_outlined, size: 44, color: p.textFaint),
          const SizedBox(height: 14),
          Text('No photos yet', style: AppText.title(color: p.text)),
          const SizedBox(height: 6),
          Text(
            'Photos and videos on this device will show up here.',
            textAlign: TextAlign.center,
            style: AppText.body(color: p.textDim),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 44, color: p.textFaint),
              const SizedBox(height: 16),
              Text(
                'Couldn’t read your library',
                style: AppText.title(color: p.text),
              ),
              const SizedBox(height: 8),
              Text(
                'Something went wrong while loading your photos.',
                textAlign: TextAlign.center,
                style: AppText.body(color: p.textDim),
              ),
              const SizedBox(height: 24),
              SecondaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onTap: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
