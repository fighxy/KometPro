import 'package:flutter/widgets.dart';

import '../../backend/app_deps.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.deps, required super.child});

  final AppDeps deps;

  static AppDeps of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope != null) return scope.deps;
    return AppDeps.shared;
  }

  static AppDeps read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    if (scope != null) return scope.deps;
    return AppDeps.shared;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.deps != deps;
}
