import 'package:flutter/widgets.dart';

class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 900;
  static const double large = 1200;

  static bool isCompact(double width) => width < compact;

  static bool isMedium(double width) => width >= compact && width < expanded;

  static bool useSplitView(double width, {DisplayFeature? hinge}) {
    if (hinge != null) return width >= compact;
    return width >= expanded;
  }

  static DisplayFeature? hingeOf(MediaQueryData mq) {
    for (final feature in mq.displayFeatures) {
      if (feature.type == DisplayFeatureType.hinge) return feature;
    }
    return null;
  }

  static double? hingeListWidth(DisplayFeature hinge, double totalWidth) {
    final left = hinge.bounds.left;
    if (left < compact / 2) return null;
    return left.clamp(0, totalWidth);
  }
}
