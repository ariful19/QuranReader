import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

abstract class ScreenAwakePlatform {
  Future<void> setEnabled(bool enabled);
}

class MethodChannelScreenAwakePlatform implements ScreenAwakePlatform {
  const MethodChannelScreenAwakePlatform();

  static const MethodChannel _channel = MethodChannel(
    'quran_reader/screen_awake',
  );

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // Tests and unsupported platforms can safely ignore this bridge.
    } on PlatformException {
      // If the platform bridge is unavailable, leave the system default.
    }
  }
}

class ScreenAwakeIdleGate extends StatefulWidget {
  const ScreenAwakeIdleGate({
    super.key,
    required this.child,
    this.inactivityTimeout = const Duration(minutes: 10),
    this.platform = const MethodChannelScreenAwakePlatform(),
  });

  final Widget child;
  final Duration inactivityTimeout;
  final ScreenAwakePlatform platform;

  @override
  State<ScreenAwakeIdleGate> createState() => _ScreenAwakeIdleGateState();
}

class _ScreenAwakeIdleGateState extends State<ScreenAwakeIdleGate>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  bool _isScreenAwake = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncWithLifecycle(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncWithLifecycle(state);
  }

  void _syncWithLifecycle(AppLifecycleState state) {
    final isForeground = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => false,
      AppLifecycleState.hidden => false,
      AppLifecycleState.paused => false,
      AppLifecycleState.detached => false,
    };

    _isForeground = isForeground;
    if (_isForeground) {
      _registerActivity();
      return;
    }
    _releaseWakeLock();
  }

  Future<void> _registerActivity() async {
    if (!_isForeground) {
      return;
    }

    _idleTimer?.cancel();
    _idleTimer = Timer(widget.inactivityTimeout, _releaseWakeLock);

    if (_isScreenAwake) {
      return;
    }

    _isScreenAwake = true;
    await widget.platform.setEnabled(true);
  }

  Future<void> _releaseWakeLock() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    if (!_isScreenAwake) {
      return;
    }

    _isScreenAwake = false;
    await widget.platform.setEnabled(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_releaseWakeLock());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => unawaited(_registerActivity()),
      onPointerMove: (_) => unawaited(_registerActivity()),
      onPointerSignal: (_) => unawaited(_registerActivity()),
      child: widget.child,
    );
  }
}
