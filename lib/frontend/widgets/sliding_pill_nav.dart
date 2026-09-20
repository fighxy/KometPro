import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/config/app_frost.dart';
import '../../core/config/app_liquid_glass.dart';
import '../../core/config/app_nav_pill_style.dart';
import '../../core/config/app_pill_gradient.dart';
import '../../core/config/app_visual_style.dart';
import '../../core/design/ios_chrome.dart';
import 'animated_lottie_icon.dart';
import 'glossy_pill.dart';
import 'liquid_glass.dart';

class PillNavItem {
  final IconData icon;
  final String label;
  final bool longPressable;
  final String? animationAsset;

  const PillNavItem({
    required this.icon,
    required this.label,
    this.longPressable = false,
    this.animationAsset,
  });
}

class PillNavGeometry {
  final double navInnerW;
  final double activeWidth;
  final double inactiveWidth;

  const PillNavGeometry(this.navInnerW, this.activeWidth, this.inactiveWidth);

  factory PillNavGeometry.fromInnerWidth(double navInnerW, int itemCount) {
    final totalWeight = (itemCount - 1) + _activeWeight;
    final unit = navInnerW / totalWeight;
    return PillNavGeometry(navInnerW, unit * _activeWeight, unit);
  }

  factory PillNavGeometry.equal(double itemWidth, int itemCount) =>
      PillNavGeometry(itemWidth * itemCount, itemWidth, itemWidth);

  static const double _activeWeight = 1.55;
}

class SlidingPillNav extends StatelessWidget {
  final List<PillNavItem> items;
  final double position;
  final Duration animationDuration;
  final PillNavGeometry geometry;
  final ValueChanged<int> onTap;
  final void Function(int index, Offset globalPosition)? onItemLongPress;
  final double iconSize;
  final double labelGap;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool iconsOnly;
  final double collapse;
  final BackdropKey? backdropKey;

  const SlidingPillNav({
    super.key,
    required this.items,
    required this.position,
    required this.geometry,
    required this.onTap,
    this.animationDuration = Duration.zero,
    this.onItemLongPress,
    this.iconSize = 24,
    this.labelGap = 6,
    this.backgroundColor,
    this.borderColor,
    this.iconsOnly = false,
    this.collapse = 0,
    this.backdropKey,
  });

  static const double height = 68;
  static const double compactHeight = 52;

  static double heightAt(double collapse) => IosChrome.heightAt(collapse);

  double _interpWidthFor(PillNavGeometry geo, int tab) {
    final maxIndex = items.length - 1;
    final rt = position.clamp(0.0, maxIndex.toDouble());
    final i0 = rt.floor();
    final i1 = rt.ceil();
    final frac = i0 == i1 ? 0.0 : rt - i0;
    double at(int sel) => tab == sel ? geo.activeWidth : geo.inactiveWidth;
    return at(i0) + (at(i1) - at(i0)) * frac;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisualStyle>(
      valueListenable: AppVisualStyle.current,
      builder: (context, style, _) {
        if (style == VisualStyle.materialYou) {
          return _buildNav(
            context,
            glossy: false,
            gradient: false,
            frost: false,
            liquid: false,
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: AppPillGradient.current,
          builder: (context, gradient, _) =>
              ValueListenableBuilder<NavPillStyle>(
                valueListenable: AppNavPillStyle.current,
                builder: (context, navStyle, _) => _buildNav(
                  context,
                  glossy: true,
                  gradient: gradient,
                  frost: NavPillMaterial.isFrost(navStyle),
                  liquid: NavPillMaterial.isLiquid(navStyle),
                ),
              ),
        );
      },
    );
  }

  Widget _buildNav(
    BuildContext context, {
    required bool glossy,
    required bool gradient,
    required bool frost,
    required bool liquid,
  }) {
    final cs = Theme.of(context).colorScheme;
    final visualSel = position.round().clamp(0, items.length - 1);
    final translucent = backgroundColor != null && backgroundColor!.a < 1;
    final hideLabels = iconsOnly || IosChrome.iconsOnly(collapse);
    final barHeight = heightAt(collapse);
    final outer = IosChrome.outerRadius * (barHeight / height);
    final inner = IosChrome.innerRadius * (barHeight / height);
    final base = liquid
        ? (translucent ? backgroundColor! : IosChrome.navTint(cs))
        : (backgroundColor ??
              (frost ? AppFrost.glassTint(cs) : cs.surfaceContainerHigh));
    final useGradient = glossy && gradient && !liquid;
    final frosted = frost && !liquid && base.a < 1;

    final nav = Container(
      height: barHeight,
      padding: const EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: useGradient || liquid ? null : base,
        gradient: useGradient ? GlossyDecor.fillGradient(base) : null,
        borderRadius: BorderRadius.circular(outer),
        border: glossy
            ? GlossyDecor.rimBorder(base)
            : (borderColor != null
                  ? Border.all(color: borderColor!, width: 0.5)
                  : null),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geo = PillNavGeometry.fromInnerWidth(
            constraints.maxWidth,
            items.length,
          );
          final maxIndex = items.length - 1;
          final t = position.clamp(0.0, maxIndex.toDouble());
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (frosted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(inner),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: AppFrost.sigma,
                          sigmaY: AppFrost.sigma,
                        ),
                        backdropGroupKey: backdropKey,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              if (useGradient)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(inner),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: GlossyDecor.topSheen(base),
                        ),
                      ),
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: animationDuration,
                curve: Curves.easeOutCubic,
                left: t * geo.inactiveWidth,
                top: 0,
                bottom: 0,
                width: geo.activeWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.brightness == Brightness.light
                        ? cs.primary.withValues(alpha: 0.14)
                        : cs.onSurface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(inner),
                  ),
                ),
              ),
              Row(
                children: List.generate(items.length, (i) {
                  return SizedBox(
                    width: _interpWidthFor(geo, i),
                    child: _PillNavCell(
                      item: items[i],
                      selected: i == visualSel,
                      cs: cs,
                      animationDuration: animationDuration,
                      iconSize: iconSize,
                      labelGap: labelGap,
                      iconsOnly: hideLabels,
                      onTap: () => onTap(i),
                      onLongPress:
                          (onItemLongPress == null || !items[i].longPressable)
                          ? null
                          : (pos) => onItemLongPress!(i, pos),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );

    if (!liquid) return nav;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outer),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(outer),
        tint: base,
        preset: GlassPreset.resolvedControl,
        child: nav,
      ),
    );
  }
}

class _PillNavCell extends StatelessWidget {
  final PillNavItem item;
  final bool selected;
  final ColorScheme cs;
  final Duration animationDuration;
  final double iconSize;
  final double labelGap;
  final bool iconsOnly;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onLongPress;

  const _PillNavCell({
    required this.item,
    required this.selected,
    required this.cs,
    required this.animationDuration,
    required this.iconSize,
    required this.labelGap,
    required this.iconsOnly,
    required this.onTap,
    required this.onLongPress,
  });

  static const double _iconWeight = 400;
  static const double _iconGrade = 0;
  static const double _labelSize = 11.5;
  static const FontWeight _labelWeight = FontWeight.w600;

  Widget _buildIcon() {
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    final asset = item.animationAsset;
    if (asset != null) {
      return AnimatedLottieIcon(
        asset: asset,
        color: color,
        size: iconSize,
        active: selected,
      );
    }
    return Icon(
      item.icon,
      color: color,
      size: iconSize,
      fill: selected ? 1 : 0,
      weight: _iconWeight,
      grade: _iconGrade,
      opticalSize: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPress == null
          ? null
          : (d) => onLongPress!(d.globalPosition),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: iconsOnly
            ? _buildIcon()
            : selected
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIcon(),
                    SizedBox(width: labelGap),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: _labelSize,
                        fontWeight: _labelWeight,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: _labelSize,
                      fontWeight: _labelWeight,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
