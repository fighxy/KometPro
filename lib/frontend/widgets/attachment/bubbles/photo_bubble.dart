import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/media/preview_image.dart';
import '../../../../core/utils/media_frame_size.dart';
import '../../../../core/utils/telegram_album_layout.dart' as telegram;
import '../../../../core/utils/format.dart';
import '../../../../models/attachment.dart';
import '../../photo_viewer.dart';
import '../photo_hero.dart';
import '../../text_with_meta.dart';
import 'bubble_context.dart';
import 'video_bubble.dart';

class PhotoBubble extends StatelessWidget {
  static const Radius _bigRadius = Radius.circular(
    BubbleContext.bubbleBorderRadius,
  );
  static const Radius _smallRadius = Radius.circular(4);
  static const Radius _photoRadius = Radius.circular(
    BubbleContext.photoBorderRadius,
  );

  final BubbleContext ctx;
  final List<MessageAttachment> media;
  final bool hasContentAbove;

  const PhotoBubble({
    super.key,
    required this.ctx,
    required this.media,
    this.hasContentAbove = false,
  });

  // #***! альбом собирает фото и обычные видео, кружки живут отдельно
  static bool isAlbumMedia(MessageAttachment item) =>
      item is PhotoAttachment || (item is VideoAttachment && !item.isNote);

  static int? _intrinsicWidth(MessageAttachment item) => switch (item) {
    PhotoAttachment(:final width) => width,
    VideoAttachment(:final width) => width,
    _ => null,
  };

  static int? _intrinsicHeight(MessageAttachment item) => switch (item) {
    PhotoAttachment(:final height) => height,
    VideoAttachment(:final height) => height,
    _ => null,
  };

  static String? _localPathOf(MessageAttachment item) => switch (item) {
    PhotoAttachment(:final localPath) => localPath,
    VideoAttachment(:final localPath) => localPath,
    _ => null,
  };

  // #***! у видео обложка отдельным полем, baseUrl это уже сам файл
  static String _previewUrlOf(MessageAttachment item) {
    if (item is VideoAttachment) {
      final thumb = item.thumbnail;
      if (thumb != null && thumb.isNotEmpty) return thumb;
      return item.baseUrl ?? '';
    }
    if (item is PhotoAttachment) return item.baseUrl ?? '';
    return '';
  }

  static double layoutWidth(
    List<MessageAttachment> media, {
    bool hasCaption = false,
  }) {
    if (media.length != 1) return BubbleContext.photoMaxSize;
    return _displaySize(media.single, hasCaption: hasCaption).width;
  }

  static Size _displaySize(MessageAttachment item, {bool hasCaption = false}) {
    final minWidth = hasCaption
        ? BubbleContext.captionedMediaMinWidth
        : BubbleContext.photoMinSize;
    final width = _intrinsicWidth(item)?.toDouble() ?? 200;
    final height = _intrinsicHeight(item)?.toDouble() ?? 200;
    return fitMediaFrame(
      width,
      height,
      maxWidth: BubbleContext.photoMaxSize,
      maxHeight: BubbleContext.photoMaxSize,
      minSize: BubbleContext.photoMinSize,
      minFrameWidth: minWidth,
      minPreviewHeight: BubbleContext.photoMinSize,
      widenPortrait: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMessageCaption = ctx.contentText?.isNotEmpty ?? false;
    final resolvedCaption = hasMessageCaption ? ctx.caption() : null;
    final hasCaption = resolvedCaption != null;
    final count = media.length;

    Widget photosWidget;
    if (count == 1) {
      photosWidget = _buildSinglePhoto(
        ctx,
        media[0],
        hasCaption: hasCaption,
        hasContentAbove: hasContentAbove,
      );
    } else {
      photosWidget = _buildAlbum(ctx, media);
    }

    if (!hasCaption) {
      return Stack(
        children: [
          photosWidget,
          Positioned(
            bottom: BubbleContext.compactTimePadding,
            right: BubbleContext.compactTimePadding,
            child: ctx.compactTime(),
          ),
        ],
      );
    }

    if (count == 1) {
      return SizedBox(
        width: layoutWidth(media, hasCaption: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            photosWidget,
            Padding(
              padding: const EdgeInsets.only(
                left: BubbleContext.captionPaddingHorizontal,
                right: BubbleContext.captionPaddingRight,
                top: BubbleContext.captionPaddingTop,
                bottom: 6,
              ),
              child: TextWithMeta(
                text: resolvedCaption,
                meta: ctx.meta(),
                fillWidth: true,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        photosWidget,
        Padding(
          padding: const EdgeInsets.only(
            left: BubbleContext.captionPaddingHorizontal,
            right: BubbleContext.captionPaddingRight,
            top: BubbleContext.captionPaddingTop,
            bottom: 6,
          ),
          child: TextWithMeta(
            text: resolvedCaption,
            meta: ctx.meta(),
            fillWidth: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePhoto(
    BubbleContext ctx,
    MessageAttachment photo, {
    required bool hasCaption,
    required bool hasContentAbove,
  }) {
    final size = _displaySize(photo, hasCaption: hasCaption);
    final constrainedWidth = size.width;
    final constrainedHeight = size.height;
    final dpr = MediaQuery.of(ctx.context).devicePixelRatio;

    final matchTop = hasCaption && !hasContentAbove;
    final matchBottom = !hasCaption;

    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL = matchBottom
        ? (ctx.isMe ? _bigRadius : _smallRadius)
        : _smallRadius;
    final bottomR = matchBottom
        ? (ctx.isMe ? _smallRadius : _bigRadius)
        : _smallRadius;

    final radius = BorderRadius.only(
      topLeft: topR,
      topRight: topR,
      bottomLeft: bottomL,
      bottomRight: bottomR,
    );
    final memWidth = (constrainedWidth * dpr).round();
    final memHeight = (constrainedHeight * dpr).round();
    final sourceWidth = _intrinsicWidth(photo)?.toDouble() ?? 0;
    final sourceHeight = _intrinsicHeight(photo)?.toDouble() ?? 0;
    final needsFill = sourceWidth > 0 &&
        sourceHeight > 0 &&
        sourceWidth / sourceHeight < constrainedWidth / constrainedHeight * 0.92;
    Widget image(BoxFit fit) => _buildPhotoImage(
      ctx,
      photo,
      constrainedWidth,
      constrainedHeight,
      memWidth: memWidth,
      memHeight: memHeight,
      fit: fit,
    );

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          if (needsFill) ...[
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Transform.scale(scale: 1.16, child: image(BoxFit.cover)),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0x3A000000))),
          ],
          image(needsFill ? BoxFit.contain : BoxFit.cover),
          ..._videoBadges(photo, compact: false),
          if (ctx.uploadProgress != null)
            _buildUploadOverlay(ctx.uploadProgress!, 0),
          if (ctx.uploadProgress == null)
            Positioned.fill(
              child: Builder(
                builder: (tileContext) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openMedia(
                    ctx.context,
                    0,
                    tileContext: tileContext,
                    radius: radius,
                    memWidth: memWidth,
                    memHeight: memHeight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoImage(
    BubbleContext ctx,
    MessageAttachment photo,
    double width,
    double height, {
    required int memWidth,
    required int memHeight,
    BoxFit fit = BoxFit.cover,
  }) {
    final localPath = _localPathOf(photo);
    if (localPath != null) {
      return Image.file(
        File(localPath),
        width: width,
        height: height,
        fit: fit,
        cacheWidth: memWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            _buildPhotoPlaceholder(ctx.cs, width, height),
      );
    }
    final embedded = dataUriImage(photo, photo.previewData);
    final imageUrl = _previewUrlOf(photo);
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('data:')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memWidth,
        memCacheHeight: memHeight,
        fadeInDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        errorWidget: (_, _, _) => embedded == null
            ? _buildPhotoPlaceholder(ctx.cs, width, height)
            : Image(
                image: embedded,
                width: width,
                height: height,
                fit: fit,
              ),
      );
    }
    if (embedded != null) {
      return Image(
        image: embedded,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            _buildPhotoPlaceholder(ctx.cs, width, height),
      );
    }
    return _buildPhotoPlaceholder(ctx.cs, width, height);
  }

  // #***! плитка видео отличается от фото только кружком плеера и длительностью
  List<Widget> _videoBadges(MessageAttachment item, {required bool compact}) {
    if (item is! VideoAttachment) return const [];
    final side = compact ? 36.0 : 48.0;
    final durationMs = item.duration;
    return [
      Positioned.fill(
        child: Center(
          child: Container(
            width: side,
            height: side,
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.play_arrow,
              color: Colors.white,
              size: side * 0.625,
            ),
          ),
        ),
      ),
      if (durationMs != null && durationMs > 0)
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              formatSecondsMmSs((durationMs / 1000).round()),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
    ];
  }

  Widget _buildUploadOverlay(
    ValueListenable<List<double>> progress,
    int index,
  ) {
    return Positioned.fill(
      child: ValueListenableBuilder<List<double>>(
        valueListenable: progress,
        builder: (context, values, _) {
          final value = index < values.length ? values[index] : 1.0;
          final indeterminate = value <= 0 || value >= 1.0;
          return Container(
            color: Colors.black.withValues(alpha: 0.4),
            alignment: Alignment.center,
            child: SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: indeterminate ? null : value,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  BorderRadius _multiPhotoCornerRadius({
    required bool matchTop,
    required bool matchBottom,
    required bool isMe,
  }) {
    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL = matchBottom ? _smallRadius : _photoRadius;
    final bottomR = matchBottom
        ? (isMe ? _smallRadius : _bigRadius)
        : _photoRadius;
    return BorderRadius.only(
      topLeft: topR,
      topRight: topR,
      bottomLeft: bottomL,
      bottomRight: bottomR,
    );
  }

  Widget _buildAlbum(BubbleContext ctx, List<MessageAttachment> photos) {
    final visible = math.min(photos.length, 10);
    final remaining = photos.length - visible;
    final layout = telegram.layoutTelegramAlbum(
      [
        for (var i = 0; i < visible; i++)
          telegram.AlbumMediaSize(
            _intrinsicWidth(photos[i])?.toDouble() ?? 0,
            _intrinsicHeight(photos[i])?.toDouble() ?? 0,
          ),
      ],
      maxWidth: BubbleContext.photoMaxSize,
    );
    final matchTop =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleTop;
    final matchBottom =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleBottom;

    return ClipRRect(
      borderRadius: _multiPhotoCornerRadius(
        matchTop: matchTop,
        matchBottom: matchBottom,
        isMe: ctx.isMe,
      ),
      child: SizedBox(
        width: layout.width,
        height: layout.height,
        child: Stack(
          children: [
            for (final tile in layout.tiles)
              Positioned(
                left: tile.left,
                top: tile.top,
                width: tile.width,
                height: tile.height,
                child: remaining > 0 && tile.index == visible - 1
                    ? _buildPhotoTileWithOverlay(
                        ctx,
                        photos[tile.index],
                        '+$remaining',
                        tile.index,
                      )
                    : _buildPhotoTile(ctx, photos[tile.index], tile.index),
              ),
          ],
        ),
      ),
    );
  }

  // #***! форму плитки задаёт AspectRatio ряда-родителя, тут просто контент
  Widget _buildPhotoTile(
    BubbleContext ctx,
    MessageAttachment photo,
    int index,
  ) => _buildFillTile(ctx, photo, index);

  // #***! кэш декода считаем по реальному размеру плитки, а не по прикидке
  // "photoMaxSize/2" — с адаптивной шириной ряда плитка может быть заметно
  // больше половины бабла, и фиксированная прикидка даёт мыло на растяжении
  Widget _buildFillTile(BubbleContext ctx, MessageAttachment photo, int index) {
    final dpr = MediaQuery.of(ctx.context).devicePixelRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cachePx =
            (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : BubbleContext.photoMaxSize / 2) *
            dpr;
        final cachePxInt = cachePx.round().clamp(1, 2048);
        return Stack(
          children: [
            _buildPhotoImage(
              ctx,
              photo,
              double.infinity,
              double.infinity,
              memWidth: cachePxInt,
              memHeight: cachePxInt,
            ),
            ..._videoBadges(photo, compact: true),
            if (ctx.uploadProgress != null)
              _buildUploadOverlay(ctx.uploadProgress!, index),
            if (ctx.uploadProgress == null)
              _buildTileTapTarget(ctx, index, cachePxInt),
          ],
        );
      },
    );
  }

  Widget _buildTileTapTarget(BubbleContext ctx, int index, int cachePx) {
    return Positioned.fill(
      child: Builder(
        builder: (tileContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openMedia(
            ctx.context,
            index,
            tileContext: tileContext,
            radius: BorderRadius.zero,
            memWidth: cachePx,
            memHeight: cachePx,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTileWithOverlay(
    BubbleContext ctx,
    MessageAttachment photo,
    String overlay,
    int index,
  ) {
    final dpr = MediaQuery.of(ctx.context).devicePixelRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cachePx =
            (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : BubbleContext.photoMaxSize / 2) *
            dpr;
        final cachePxInt = cachePx.round().clamp(1, 2048);
        return Stack(
          children: [
            _buildPhotoImage(
              ctx,
              photo,
              double.infinity,
              double.infinity,
              memWidth: cachePxInt,
              memHeight: cachePxInt,
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: Text(
                    overlay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            if (ctx.uploadProgress != null)
              _buildUploadOverlay(ctx.uploadProgress!, index),
            if (ctx.uploadProgress == null)
              _buildTileTapTarget(ctx, index, cachePxInt),
          ],
        );
      },
    );
  }

  Widget _buildPhotoPlaceholder(ColorScheme cs, double w, double h) {
    return Container(
      width: w,
      height: h,
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Symbols.image, size: 48, color: cs.onSurfaceVariant),
      ),
    );
  }

  static ImageProvider? _photoProvider(
    MessageAttachment photo, {
    required int memWidth,
    required int memHeight,
  }) {
    final localPath = _localPathOf(photo);
    if (localPath != null) {
      return ResizeImage.resizeIfNeeded(
        memWidth,
        null,
        FileImage(File(localPath)),
      );
    }
    final url = _previewUrlOf(photo);
    if (url.isEmpty || url.startsWith('data:')) {
      return dataUriImage(photo, photo.previewData);
    }
    return ResizeImage.resizeIfNeeded(
      memWidth,
      memHeight,
      CachedNetworkImageProvider(url),
    );
  }

  static Size? _photoSize(MessageAttachment photo) {
    final width = _intrinsicWidth(photo) ?? 0;
    final height = _intrinsicHeight(photo) ?? 0;
    if (width <= 0 || height <= 0) return null;
    return Size(width.toDouble(), height.toDouble());
  }

  // #***! просмотрщик листает только фото, видео из альбома уходит в плеер
  void _openMedia(
    BuildContext context,
    int index, {
    required BuildContext tileContext,
    required BorderRadius radius,
    required int memWidth,
    required int memHeight,
  }) {
    final photo = media[index];
    if (photo is VideoAttachment) {
      openVideoPlayer(ctx, photo);
      return;
    }
    final photos = media.whereType<PhotoAttachment>().toList();
    final photoIndex = photos.indexOf(photo as PhotoAttachment);
    final hero = PhotoHeroController(
      origin: () => photoHeroRectOf(tileContext),
      image: _photoProvider(photo, memWidth: memWidth, memHeight: memHeight),
      size: _photoSize(photo),
      radius: radius,
    );
    Navigator.of(context).push(
      PhotoHeroRoute<void>(
        hero: hero,
        builder: (_) => PhotoViewerScreen(
          photos: photos,
          initialIndex: photoIndex < 0 ? 0 : photoIndex,
          chatId: ctx.chatId,
          message: ctx.message,
          actions: ctx.photoActions,
          hero: hero,
          sourceName: ctx.chatName,
          videoUserAgentProvider: () => api.session?.userAgent(),
        ),
      ),
    );
  }
}
