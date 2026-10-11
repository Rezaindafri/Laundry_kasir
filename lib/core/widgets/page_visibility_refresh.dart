import 'package:flutter/material.dart';

// Observe actual pages only: closing a sheet/dialog must not reload its parent
// form and dispose controllers while an overlay is still animating out.
final pageRefreshObserver = RouteObserver<PageRoute<dynamic>>();

class PageVisibilityRefresh extends StatefulWidget {
  const PageVisibilityRefresh(
      {required this.child,
      required this.onVisible,
      this.onCovered,
      this.refreshOnMount = false,
      super.key});
  final Widget child;
  final Future<void> Function() onVisible;
  final VoidCallback? onCovered;
  final bool refreshOnMount;
  @override
  State<PageVisibilityRefresh> createState() => _PageVisibilityRefreshState();
}

class _PageVisibilityRefreshState extends State<PageVisibilityRefresh>
    with RouteAware {
  PageRoute<dynamic>? _route;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    if (widget.refreshOnMount) _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      pageRefreshObserver.unsubscribe(this);
      _route = route is PageRoute<dynamic> ? route : null;
      if (_route != null) pageRefreshObserver.subscribe(this, _route!);
    }
  }

  @override
  void didPushNext() => widget.onCovered?.call();
  @override
  void didPopNext() => _schedule();

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      if (!mounted || _route?.isCurrent == false) return;
      // Refresh callbacks retain previous usable data on network errors.
      try {
        await widget.onVisible();
      } catch (_) {/* Screen owns its error UI. */}
    });
  }

  @override
  void dispose() {
    pageRefreshObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
