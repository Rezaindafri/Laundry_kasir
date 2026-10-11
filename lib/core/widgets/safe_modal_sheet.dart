import 'package:flutter/material.dart';

/// A route can still be mounted while it is closing or covered by another one.
/// Never submit a form (or open its next popup) from that stale page.
bool isCurrentPage(BuildContext context) =>
    context.mounted && ModalRoute.of(context)?.isCurrent == true;

/// Unlike showModalBottomSheet's result, this future also waits for the exit
/// animation and overlay disposal. Callers can then safely open another route.
/// Controllers passed here are owned by the sheet, not its calling page.
Future<T?> showSafeModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  bool? showDragHandle,
  List<TextEditingController> controllers = const [],
}) async {
  ModalRoute<T>? route;
  try {
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      builder: (sheetContext) {
        route = ModalRoute.of<T>(sheetContext);
        return builder(sheetContext);
      },
    );
    // A pop result arrives while TextFields are still mounted during reverse.
    if (route != null) await route!.completed;
    return result;
  } finally {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}
