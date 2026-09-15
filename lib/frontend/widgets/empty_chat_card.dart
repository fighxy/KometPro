import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../backend/app_services.dart';
import '../../models/sticker.dart';
import 'lottie_image.dart';

class EmptyChatCard extends StatefulWidget {
  const EmptyChatCard({super.key, required this.title, this.onStickerTap});

  final String title;
  final void Function(StickerItem sticker)? onStickerTap;

  @override
  State<EmptyChatCard> createState() => _EmptyChatCardState();
}

class _EmptyChatCardState extends State<EmptyChatCard> {
  static final math.Random _random = math.Random();

  StickerItem? _sticker;

  @override
  void initState() {
    super.initState();
    _sticker = _pickSticker();
    if (_sticker == null) unawaited(_loadSticker());
  }

  Future<void> _loadSticker() async {
    try {
      await stickersModule.ensureLoaded();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final picked = _pickSticker();
    if (picked != null) setState(() => _sticker = picked);
  }

  StickerItem? _pickSticker() {
    final candidates = <StickerItem>[];
    for (final id in stickersModule.recentStickerIds) {
      final item = stickersModule.cachedSticker(id);
      if (item != null) candidates.add(item);
    }
    if (candidates.isEmpty) {
      for (final set in stickersModule.sets) {
        for (final id in set.stickerIds) {
          final item = stickersModule.cachedSticker(id);
          if (item != null) candidates.add(item);
        }
        if (candidates.length >= 40) break;
      }
    }
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sticker = _sticker;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Material(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sticker == null
                        ? 'Отправьте первое сообщение'
                        : 'Отправьте сообщение или нажмите на стикер',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (sticker != null) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onStickerTap == null
                          ? null
                          : () => widget.onStickerTap!(sticker),
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: LottieImage(
                          url: sticker.url,
                          lottieUrl: sticker.lottieUrl,
                          memCacheWidth: 280,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
