import 'dart:math' as math;

class KometLayout {
  static const double rail = 60;
  static const double list = 360;
  static const double minChat = 360;
  static const double inspector = 320;
  static const double inspectorBreakpoint = 1280;
  static const double toolbar = 56;
  static const double textWidth = 640;
  static const double mediaWidth = 720;
  static const double threadWidth = 800;

  static bool dockInspector(double width, double listWidth, double scale) =>
      width >= inspectorBreakpoint &&
      width - rail * scale - listWidth - 10 - inspector * scale >=
          minChat * scale;

  static double listLimit(double width, double scale, bool inspectorOpen) =>
      math.max(
        280,
        math.min(
          560,
          width -
              rail * scale -
              minChat * scale -
              10 -
              (inspectorOpen ? inspector * scale : 0),
        ),
      );
}
