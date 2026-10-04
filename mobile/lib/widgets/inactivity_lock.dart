// M1 FE-2: auto-lock after inactivity. Any touch restarts the timer; the app
// also locks when it comes back after being in the background for too long.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../auth/session.dart';

class InactivityLock extends StatefulWidget {
  const InactivityLock({super.key, required this.session, required this.child});

  final Session session;
  final Widget child;

  @override
  State<InactivityLock> createState() => _InactivityLockState();
}

class _InactivityLockState extends State<InactivityLock> {
  Timer? _timer;
  DateTime? _backgroundSince;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_restart);
    _lifecycle = AppLifecycleListener(onHide: _hidden, onShow: _shown);
    _restart();
  }

  @override
  void dispose() {
    widget.session.removeListener(_restart);
    _lifecycle.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    if (widget.session.isUnlocked) _timer = Timer(widget.session.autoLockAfter, widget.session.lock);
  }

  void _hidden() => _backgroundSince = DateTime.now();

  void _shown() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (since != null && DateTime.now().difference(since) >= widget.session.autoLockAfter) {
      widget.session.lock();
    } else {
      _restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => _restart(), child: widget.child);
  }
}
