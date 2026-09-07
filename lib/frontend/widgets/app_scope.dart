import 'package:flutter/widgets.dart';

import '../../backend/app_deps.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.deps, required super.child});

  final AppDeps deps;

  static AppDeps of(BuildContext context) => _resolve(context, listen: true);

  static AppDeps read(BuildContext context) => _resolve(context, listen: false);

  static AppDeps _resolve(BuildContext context, {required bool listen}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AppScope>()
        : context.getInheritedWidgetOfExactType<AppScope>();
    assert(
      scope != null,
      'AppScope missing. Wrap the app with AppScope and do not '
      'read AppDeps.shared from widgets.',
    );
    return scope?.deps ?? AppDeps.shared;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.deps != deps;
}
