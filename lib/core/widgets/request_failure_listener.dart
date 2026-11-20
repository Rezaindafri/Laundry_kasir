import 'top_notice.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../network/request_failure_notice.dart';

/// A single, bounded notification for a burst of failed parallel requests.
class RequestFailureListener extends StatefulWidget {
  const RequestFailureListener({
    required this.events,
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final Stream<RequestFailureNotice> events;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<RequestFailureListener> createState() => _RequestFailureListenerState();
}

class _RequestFailureListenerState extends State<RequestFailureListener> {
  StreamSubscription<RequestFailureNotice>? _subscription;
  DateTime? _lastNotice;
  bool _lastWasWrite = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _subscription = widget.events.listen((event) {
      final now = DateTime.now();
      if (_lastNotice != null &&
          now.difference(_lastNotice!) < const Duration(seconds: 4) &&
          (!event.isWrite || _lastWasWrite)) return;
      final overlay = widget.navigatorKey.currentState?.overlay;
      if (!mounted || overlay == null) return;
      _lastNotice = now;
      _lastWasWrite = event.isWrite;
      TopNotice(overlay).showTopNotice(SnackBar(content: Text(event.message)));
    });
  }

  @override
  void didUpdateWidget(covariant RequestFailureListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
