import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/config/app_frost.dart';
import '../../core/config/app_liquid_glass.dart';
import '../../core/config/glass_intensity.dart';
import '../../core/config/app_visual_style.dart';

class LiquidGlass {
  static const String _asset = 'shaders/liquid_glass.frag';

  static ui.FragmentProgram? _program;
  static bool _loadAttempted = false;

  static bool get isSupported => _program != null;

  static bool get active =>
      isSupported &&
      AppVisualStyle.current.value == VisualStyle.liquidGlass &&
      GlassIntensity.systemAllowsBlur.value;

  static Future<void> load() async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    if (!AppLiquidGlass.enabled) return;
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(_asset);
    } catch (_) {
      _program = null;
    }
  }
}

class GlassSurface extends StatelessWidget {
  final bool liquid;
  final BorderRadius borderRadius;
  final Color frostTint;
  final double frostSigma;
  final Color liquidTint;
  final BoxBorder? border;
  final BackdropKey? backdropKey;

  /// Fill for the plain fallback (Material You, high contrast, reduced
  /// animations). Defaults to a themed surface; pass a fixed colour where the
  /// surface sits on media instead of on the app background.
  final Color? fallbackColor;

  /// Tuning for the liquid path; controls and panels read differently.
  final GlassPreset preset;
  final Widget child;

  GlassSurface({
    super.key,
    this.liquid = false,
    this.borderRadius = BorderRadius.zero,
    required this.frostTint,
    double? frostSigma,
    this.liquidTint = Colors.transparent,
    this.border,
    this.backdropKey,
    this.fallbackColor,
    this.preset = GlassPreset.panel,
    required this.child,
  }) : frostSigma = frostSigma ?? AppFrost.sigma;

  static Listenable get _intensity => Listenable.merge([
    GlassIntensity.scale,
    GlassIntensity.systemAllowsBlur,
  ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _intensity,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    if (MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context) ||
        !GlassIntensity.systemAllowsBlur.value ||
        AppVisualStyle.current.value == VisualStyle.materialYou) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color:
              fallbackColor ??
              Theme.of(context).colorScheme.surfaceContainerHigh,
          child: child,
        ),
      );
    }
    final glass = liquid && LiquidGlass.isSupported;
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? null : frostTint,
        border: border,
      ),
      child: child,
    );
    if (glass) {
      return LiquidGlassSurface(
        borderRadius: borderRadius,
        tint: liquidTint,
        preset: preset,
        fallbackColor: fallbackColor,
        child: decorated,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: frostSigma, sigmaY: frostSigma),
        backdropGroupKey: backdropKey,
        child: decorated,
      ),
    );
  }
}

class LiquidGlassSurface extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color tint;
  final double blurSigma;
  final double spread;
  final double refraction;
  final double chroma;
  final double specular;
  final Offset light;
  final double tintFeather;
  final double rimWidth;
  final double band;
  final double ior;
  final double saturation;
  final double adaptive;
  final double rimAlpha;
  final double bounceAlpha;
  final double depthShade;
  final double interior;

  /// Surface tuning. When set, it supplies the values above; pass the
  /// individual knobs only to deviate from a preset.
  final GlassPreset? preset;
  final Color? fallbackColor;
  final Widget child;

  const LiquidGlassSurface({
    super.key,
    required this.borderRadius,
    required this.tint,
    this.blurSigma = AppLiquidGlass.blurSigma,
    this.spread = AppLiquidGlass.spread,
    this.refraction = AppLiquidGlass.refraction,
    this.chroma = AppLiquidGlass.chroma,
    this.specular = AppLiquidGlass.specular,
    this.light = AppLiquidGlass.light,
    this.tintFeather = AppLiquidGlass.tintFeather,
    this.rimWidth = AppLiquidGlass.rimWidth,
    this.band = AppLiquidGlass.band,
    this.ior = AppLiquidGlass.ior,
    this.saturation = AppLiquidGlass.saturation,
    this.adaptive = AppLiquidGlass.adaptive,
    this.rimAlpha = AppLiquidGlass.rimAlpha,
    this.bounceAlpha = AppLiquidGlass.bounceAlpha,
    this.depthShade = AppLiquidGlass.depthShade,
    this.interior = AppLiquidGlass.interior,
    this.preset,
    this.fallbackColor,
    this.child = const SizedBox.expand(),
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: GlassSurface._intensity,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    if (!LiquidGlass.active ||
        MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context)) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color:
              fallbackColor ??
              Theme.of(context).colorScheme.surfaceContainerHigh,
          child: child,
        ),
      );
    }
    final tuning = preset;
    final intensity = GlassIntensity.factor;
    return _LiquidGlassBackdrop(
      borderRadius: borderRadius,
      tint: tint,
      blurSigma: (tuning?.blurSigma ?? blurSigma) * intensity,
      spread: spread,
      refraction: tuning?.refraction ?? refraction,
      chroma: chroma,
      specular: specular,
      light: light,
      tintFeather: tintFeather,
      rimWidth: tuning?.rimWidth ?? rimWidth,
      band: tuning?.band ?? band,
      ior: ior,
      saturation: tuning?.saturation ?? saturation,
      adaptive: tuning?.adaptive ?? adaptive,
      rimAlpha: tuning?.rimAlpha ?? rimAlpha,
      bounceAlpha: tuning?.bounceAlpha ?? bounceAlpha,
      depthShade: depthShade,
      interior: (tuning?.interior ?? interior) * intensity,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      child: child,
    );
  }
}

class _LiquidGlassBackdrop extends SingleChildRenderObjectWidget {
  final BorderRadius borderRadius;
  final Color tint;
  final double blurSigma;
  final double spread;
  final double refraction;
  final double chroma;
  final double specular;
  final Offset light;
  final double tintFeather;
  final double rimWidth;
  final double band;
  final double ior;
  final double saturation;
  final double adaptive;
  final double rimAlpha;
  final double bounceAlpha;
  final double depthShade;
  final double interior;
  final double devicePixelRatio;

  const _LiquidGlassBackdrop({
    required this.borderRadius,
    required this.tint,
    required this.blurSigma,
    required this.spread,
    required this.refraction,
    required this.chroma,
    required this.specular,
    required this.light,
    required this.tintFeather,
    required this.rimWidth,
    required this.band,
    required this.ior,
    required this.saturation,
    required this.adaptive,
    required this.rimAlpha,
    required this.bounceAlpha,
    required this.depthShade,
    required this.interior,
    required this.devicePixelRatio,
    required super.child,
  });

  @override
  _RenderLiquidGlass createRenderObject(BuildContext context) {
    return _RenderLiquidGlass(
      borderRadius: borderRadius,
      tint: tint,
      blurSigma: blurSigma,
      spread: spread,
      refraction: refraction,
      chroma: chroma,
      specular: specular,
      light: light,
      tintFeather: tintFeather,
      rimWidth: rimWidth,
      band: band,
      ior: ior,
      saturation: saturation,
      adaptive: adaptive,
      rimAlpha: rimAlpha,
      bounceAlpha: bounceAlpha,
      depthShade: depthShade,
      interior: interior,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLiquidGlass renderObject,
  ) {
    renderObject
      ..borderRadius = borderRadius
      ..tint = tint
      ..blurSigma = blurSigma
      ..spread = spread
      ..refraction = refraction
      ..chroma = chroma
      ..specular = specular
      ..light = light
      ..tintFeather = tintFeather
      ..rimWidth = rimWidth
      ..band = band
      ..ior = ior
      ..saturation = saturation
      ..adaptive = adaptive
      ..rimAlpha = rimAlpha
      ..bounceAlpha = bounceAlpha
      ..depthShade = depthShade
      ..interior = interior
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderLiquidGlass extends RenderProxyBox {
  _RenderLiquidGlass({
    required BorderRadius borderRadius,
    required Color tint,
    required double blurSigma,
    required double spread,
    required double refraction,
    required double chroma,
    required double specular,
    required Offset light,
    required double tintFeather,
    required double rimWidth,
    required double band,
    required double ior,
    required double saturation,
    required double adaptive,
    required double rimAlpha,
    required double bounceAlpha,
    required double depthShade,
    required double interior,
    required double devicePixelRatio,
  }) : _borderRadius = borderRadius,
       _tint = tint,
       _blurSigma = blurSigma,
       _spread = spread,
       _refraction = refraction,
       _chroma = chroma,
       _specular = specular,
       _light = light,
       _tintFeather = tintFeather,
       _rimWidth = rimWidth,
       _band = band,
       _ior = ior,
       _saturation = saturation,
       _adaptive = adaptive,
       _rimAlpha = rimAlpha,
       _bounceAlpha = bounceAlpha,
       _depthShade = depthShade,
       _interior = interior,
       _devicePixelRatio = devicePixelRatio;

  final LayerHandle<ClipRRectLayer> _blurClipHandle =
      LayerHandle<ClipRRectLayer>();
  final LayerHandle<BackdropFilterLayer> _blurHandle =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<ClipRRectLayer> _clipHandle = LayerHandle<ClipRRectLayer>();
  final LayerHandle<BackdropFilterLayer> _backdropHandle =
      LayerHandle<BackdropFilterLayer>();

  ui.FragmentShader? _shader;

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (_borderRadius == value) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  Color _tint;
  set tint(Color value) {
    if (_tint == value) return;
    _tint = value;
    markNeedsPaint();
  }

  double _blurSigma;
  set blurSigma(double value) {
    if (_blurSigma == value) return;
    _blurSigma = value;
    markNeedsPaint();
  }

  double _spread;
  set spread(double value) {
    if (_spread == value) return;
    _spread = value;
    markNeedsPaint();
  }

  double _refraction;
  set refraction(double value) {
    if (_refraction == value) return;
    _refraction = value;
    markNeedsPaint();
  }

  double _chroma;
  set chroma(double value) {
    if (_chroma == value) return;
    _chroma = value;
    markNeedsPaint();
  }

  double _specular;
  set specular(double value) {
    if (_specular == value) return;
    _specular = value;
    markNeedsPaint();
  }

  Offset _light;
  set light(Offset value) {
    if (_light == value) return;
    _light = value;
    markNeedsPaint();
  }

  double _tintFeather;
  set tintFeather(double value) {
    if (_tintFeather == value) return;
    _tintFeather = value;
    markNeedsPaint();
  }

  double _rimWidth;
  set rimWidth(double value) {
    if (_rimWidth == value) return;
    _rimWidth = value;
    markNeedsPaint();
  }

  double _band;
  set band(double value) {
    if (_band == value) return;
    _band = value;
    markNeedsPaint();
  }

  double _ior;
  set ior(double value) {
    if (_ior == value) return;
    _ior = value;
    markNeedsPaint();
  }

  double _saturation;
  set saturation(double value) {
    if (_saturation == value) return;
    _saturation = value;
    markNeedsPaint();
  }

  double _adaptive;
  set adaptive(double value) {
    if (_adaptive == value) return;
    _adaptive = value;
    markNeedsPaint();
  }

  double _rimAlpha;
  set rimAlpha(double value) {
    if (_rimAlpha == value) return;
    _rimAlpha = value;
    markNeedsPaint();
  }

  double _bounceAlpha;
  set bounceAlpha(double value) {
    if (_bounceAlpha == value) return;
    _bounceAlpha = value;
    markNeedsPaint();
  }

  double _depthShade;
  set depthShade(double value) {
    if (_depthShade == value) return;
    _depthShade = value;
    markNeedsPaint();
  }

  double _interior;
  set interior(double value) {
    if (_interior == value) return;
    _interior = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void dispose() {
    _blurClipHandle.layer = null;
    _blurHandle.layer = null;
    _clipHandle.layer = null;
    _backdropHandle.layer = null;
    _shader?.dispose();
    _shader = null;
    super.dispose();
  }

  ui.ImageFilter? _buildFilter() {
    final program = LiquidGlass._program;
    if (program == null) return null;

    final shader = _shader ??= program.fragmentShader();
    final dpr = _devicePixelRatio;
    final topLeft = localToGlobal(Offset.zero);
    final left = (topLeft.dx * dpr).roundToDouble();
    final top = (topLeft.dy * dpr).roundToDouble();
    final width = (size.width * dpr).roundToDouble();
    final height = (size.height * dpr).roundToDouble();
    final radius = _borderRadius.topLeft.x * dpr;

    shader
      ..setFloat(2, left)
      ..setFloat(3, top)
      ..setFloat(4, width)
      ..setFloat(5, height)
      ..setFloat(6, radius)
      ..setFloat(7, _spread)
      ..setFloat(8, _refraction * dpr)
      ..setFloat(9, _chroma)
      ..setFloat(10, _specular)
      ..setFloat(11, _tint.r)
      ..setFloat(12, _tint.g)
      ..setFloat(13, _tint.b)
      ..setFloat(14, _tint.a)
      ..setFloat(15, _light.dx)
      ..setFloat(16, _light.dy)
      ..setFloat(17, _tintFeather * dpr)
      ..setFloat(18, _rimWidth * dpr)
      ..setFloat(19, _band * dpr)
      ..setFloat(20, _ior)
      ..setFloat(21, _saturation)
      ..setFloat(22, _adaptive)
      ..setFloat(23, _rimAlpha)
      ..setFloat(24, _bounceAlpha)
      ..setFloat(25, _depthShade)
      ..setFloat(26, _interior * dpr);

    return ui.ImageFilter.shader(shader);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final filter = size.isEmpty ? null : _buildFilter();
    if (filter == null) {
      _blurClipHandle.layer = null;
      _blurHandle.layer = null;
      _clipHandle.layer = null;
      _backdropHandle.layer = null;
      super.paint(context, offset);
      return;
    }

    final bounds = Offset.zero & size;
    final shape = _borderRadius.toRRect(bounds);

    if (_blurSigma > 0) {
      _blurClipHandle.layer = context.pushClipRRect(
        needsCompositing,
        offset,
        bounds,
        shape,
        (PaintingContext innerContext, Offset innerOffset) {
          final blur = _blurHandle.layer ??= BackdropFilterLayer();
          blur.filter = ui.ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
            tileMode: TileMode.mirror,
          );
          innerContext.pushLayer(blur, (_, _) {}, innerOffset);
        },
        oldLayer: _blurClipHandle.layer,
      );
    } else {
      _blurClipHandle.layer = null;
      _blurHandle.layer = null;
    }

    _clipHandle.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      bounds,
      shape,
      (PaintingContext innerContext, Offset innerOffset) {
        final backdrop = _backdropHandle.layer ??= BackdropFilterLayer();
        backdrop.filter = filter;
        innerContext.pushLayer(backdrop, super.paint, innerOffset);
      },
      oldLayer: _clipHandle.layer,
    );
  }
}
