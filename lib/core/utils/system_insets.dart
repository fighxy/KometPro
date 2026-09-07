import 'package:flutter/widgets.dart';

/// System gesture / 3-button inset. Use on screens without a composer SafeArea.
class SystemInsets {
  static double bottom(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  static EdgeInsets scroll(BuildContext context, {double extra = 24}) =>
      EdgeInsets.only(bottom: bottom(context) + extra);

  static Widget sliverGap(BuildContext context, {double extra = 24}) {
    return SliverToBoxAdapter(
      child: SizedBox(height: bottom(context) + extra),
    );
  }
}
