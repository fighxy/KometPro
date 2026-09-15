import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show RTCVideoRenderer, RTCVideoView, RTCVideoViewObjectFit;

class CallVideoView extends StatefulWidget {
  const CallVideoView({
    super.key,
    required this.renderer,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    this.mirror = false,
    this.placeholder,
    this.backdrop = false,
  });

  final RTCVideoRenderer renderer;
  final RTCVideoViewObjectFit objectFit;
  final bool mirror;
  final Widget? placeholder;

  /// When true, fills the widget's bounds with a blurred, dimmed `Cover`-fit
  /// copy of the same stream behind the foreground `objectFit` video, so a
  /// mismatched-aspect-ratio source (portrait mobile camera in a wide tile,
  /// or a wide screen-share in a narrow tile) letterboxes/pillarboxes onto
  /// its own blurred content instead of a flat color.
  final bool backdrop;

  @override
  State<CallVideoView> createState() => _CallVideoViewState();
}

class _CallVideoViewState extends State<CallVideoView> {
  static const Duration _switchCooldown = Duration(milliseconds: 200);

  bool _armed = false;
  String? _sourceId;
  Timer? _cooldown;

  @override
  void initState() {
    super.initState();
    _bind(widget.renderer);
  }

  @override
  void didUpdateWidget(CallVideoView old) {
    super.didUpdateWidget(old);
    if (identical(old.renderer, widget.renderer)) return;
    old.renderer.removeListener(_onRenderer);
    _cooldown?.cancel();
    _cooldown = null;
    _bind(widget.renderer);
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    widget.renderer.removeListener(_onRenderer);
    super.dispose();
  }

  void _bind(RTCVideoRenderer renderer) {
    _sourceId = renderer.srcObject?.id;
    _armed = _hasFrames;
    renderer.addListener(_onRenderer);
  }

  bool get _hasFrames {
    final renderer = widget.renderer;
    return renderer.textureId != null &&
        renderer.srcObject != null &&
        renderer.renderVideo &&
        renderer.value.width > 0 &&
        renderer.value.height > 0;
  }

  void _onRenderer() {
    final id = widget.renderer.srcObject?.id;
    if (id != _sourceId) {
      _sourceId = id;
      _cooldown?.cancel();
      _cooldown = Timer(_switchCooldown, () {
        _cooldown = null;
        _sync();
      });
      if (_armed && mounted) setState(() => _armed = false);
      return;
    }
    if (_cooldown != null) return;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final next = _hasFrames;
    if (next != _armed) setState(() => _armed = next);
  }

  @override
  Widget build(BuildContext context) {
    final attached =
        widget.renderer.textureId != null && widget.renderer.srcObject != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (attached && widget.backdrop)
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.35),
                  BlendMode.darken,
                ),
                child: RTCVideoView(
                  widget.renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: widget.mirror,
                ),
              ),
            ),
          ),
        if (attached)
          RTCVideoView(
            widget.renderer,
            objectFit: widget.objectFit,
            mirror: widget.mirror,
          ),
        if (!_armed) widget.placeholder ?? const SizedBox.expand(),
      ],
    );
  }
}
