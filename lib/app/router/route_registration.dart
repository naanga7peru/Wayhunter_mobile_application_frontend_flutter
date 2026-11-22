import 'package:flutter/widgets.dart';

class RouteRegistration<T> {
  const RouteRegistration(this.builder, {this.validate});

  final Widget Function(BuildContext, T) builder;
  final bool Function(T)? validate;

  Widget? build(BuildContext context, Object? arguments) {
    if (arguments is! T || validate?.call(arguments) == false) return null;
    return builder(context, arguments);
  }
}
