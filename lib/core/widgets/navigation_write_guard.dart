import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationWritesProvider = StateProvider<int>((ref) => 0);

const savingNavigationMessage =
    'Sedang menyimpan data. Tunggu hingga proses selesai.';

/// Run only writes, never catalogue loads. A counter also covers overlapping
/// writes. Capture the controller before awaiting, rather than a disposed ref.
Future<T> withNavigationWriteLock<T>(
  WidgetRef ref,
  Future<T> Function() operation,
) async {
  final counter = ref.read(navigationWritesProvider.notifier);
  counter.state++;
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    return await operation();
  } finally {
    if (counter.mounted) counter.state--;
  }
}

void showSavingNavigationNotice(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text(savingNavigationMessage)));
}

/// Popup/search routes above this page still receive Back first. Once a write
/// starts, temporarily disable editing and page Back; never imply that leaving
/// a page cancels a payment already being processed by Laravel.
class NavigationWriteGuard extends ConsumerWidget {
  final Widget child;

  const NavigationWriteGuard({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(navigationWritesProvider) > 0;
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy) showSavingNavigationNotice(context);
      },
      child: AbsorbPointer(absorbing: busy, child: child),
    );
  }
}
