import 'package:flutter/widgets.dart';

import 'app_controller.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Subscribes the caller to changes.
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// For callbacks: reads without subscribing.
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
