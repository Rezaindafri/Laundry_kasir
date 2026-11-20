import 'dart:async';

import 'package:flutter/material.dart';

/// Keep field-level errors and add a short, visible summary at the top.
bool validateFormWithNotice(BuildContext context, GlobalKey<FormState> key) {
  final valid = key.currentState?.validate() ?? false;
  if (!valid) {
    TopNotice.maybeOf(context)?.showTopNotice(const SnackBar(
      content: Text('Periksa isian yang ditandai.'),
    ));
  }
  return valid;
}

class TopNotice {
  const TopNotice(this._overlay);

  static final _active = Expando<OverlayEntry>();
  final OverlayState _overlay;

  static TopNotice of(BuildContext context) =>
      TopNotice(Overlay.of(context, rootOverlay: true));

  static TopNotice? maybeOf(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    return overlay == null ? null : TopNotice(overlay);
  }

  void showTopNotice(SnackBar notice) {
    if (!_overlay.mounted) return;
    _active[_overlay]?.remove();
    late final OverlayEntry entry;
    void close() {
      if (!_overlay.mounted || !identical(_active[_overlay], entry)) return;
      _active[_overlay] = null;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Material(
                elevation: 5,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(12),
                child: MaterialBanner(
                  content: _TimedNotice(
                    duration: notice.duration,
                    onTimeout: close,
                    child: notice.content,
                  ),
                  leading: const Icon(Icons.info_outline),
                  backgroundColor: notice.backgroundColor,
                  actions: [
                    IconButton(
                      tooltip: 'Tutup notifikasi',
                      icon: const Icon(Icons.close),
                      onPressed: close,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _active[_overlay] = entry;
    _overlay.insert(entry);
  }
}

class _TimedNotice extends StatefulWidget {
  const _TimedNotice({
    required this.duration,
    required this.onTimeout,
    required this.child,
  });

  final Duration duration;
  final VoidCallback onTimeout;
  final Widget child;

  @override
  State<_TimedNotice> createState() => _TimedNoticeState();
}

class _TimedNoticeState extends State<_TimedNotice> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onTimeout);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Semantics(liveRegion: true, child: widget.child);
}
