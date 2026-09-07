class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 900;
  static const double large = 1200;

  static bool isCompact(double width) => width < compact;

  static bool isMedium(double width) => width >= compact && width < expanded;

  static bool useSplitView(double width) => width >= expanded;
}
