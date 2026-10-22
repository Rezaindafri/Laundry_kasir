import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation_write_guard.dart';

/// Wait for the dialog overlay to leave before closing or replacing its parent.
Future<bool> showActionConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Ya, lanjutkan',
  String cancelLabel = 'Kembali',
}) async {
  ModalRoute<bool>? route;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      route = ModalRoute.of<bool>(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  if (route != null) await route!.completed;
  return confirmed == true;
}

/// Confirms leaving a changed draft, without owning/disposal of its controllers.
///
/// Save actions should pop their result directly; cancellation buttons should
/// call maybePop. For bottom sheets disable drag, because BottomSheet.onClosing
/// uses pop directly and would otherwise bypass a PopScope's veto.
class UnsavedChangesGuard extends ConsumerStatefulWidget {
  const UnsavedChangesGuard({
    required this.hasUnsavedChanges,
    required this.child,
    this.listenables = const [],
    super.key,
  });

  final bool Function() hasUnsavedChanges;
  final List<Listenable> listenables;
  final Widget child;

  @override
  ConsumerState<UnsavedChangesGuard> createState() =>
      _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends ConsumerState<UnsavedChangesGuard> {
  bool _confirming = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    for (final listenable in widget.listenables) {
      listenable.addListener(_changed);
    }
  }

  @override
  void didUpdateWidget(covariant UnsavedChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final listenable in oldWidget.listenables) {
      listenable.removeListener(_changed);
    }
    for (final listenable in widget.listenables) {
      listenable.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final listenable in widget.listenables) {
      listenable.removeListener(_changed);
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _confirmLeave(Object? result) async {
    if (_confirming ||
        _leaving ||
        ref.read(navigationWritesProvider) > 0 ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    // Evaluate at the actual Back attempt too: dropdowns may update a local
    // draft without rebuilding the wrapper around their StatefulBuilder.
    if (!widget.hasUnsavedChanges()) {
      _leaving = true;
      Navigator.of(context).pop(result);
      return;
    }
    _confirming = true;
    final discard = await showActionConfirmation(
      context: context,
      title: 'Batalkan perubahan?',
      message: 'Data yang belum disimpan akan hilang. Apakah Anda yakin?',
      confirmLabel: 'Ya, batalkan',
      cancelLabel: 'Lanjut mengisi',
    );
    if (!mounted) return;
    _confirming = false;
    if (discard &&
        ref.read(navigationWritesProvider) == 0 &&
        ModalRoute.of(context)?.isCurrent == true) {
      _leaving = true;
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: ref.watch(navigationWritesProvider) == 0 && _leaving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _confirmLeave(result);
        },
        child: widget.child,
      );
}
