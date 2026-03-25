import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/src/screen_awake_manager.dart';

void main() {
  testWidgets('keeps the screen awake for 10 idle minutes', (tester) async {
    final platform = _FakeScreenAwakePlatform();

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenAwakeIdleGate(
          platform: platform,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    expect(platform.calls, <bool>[true]);

    await tester.pump(const Duration(minutes: 9, seconds: 59));
    expect(platform.calls, <bool>[true]);

    await tester.pump(const Duration(seconds: 2));
    expect(platform.calls, <bool>[true, false]);
  });

  testWidgets('pointer activity extends the wake window', (tester) async {
    final platform = _FakeScreenAwakePlatform();

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenAwakeIdleGate(
          platform: platform,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    expect(platform.calls, <bool>[true]);

    await tester.pump(const Duration(minutes: 9));

    final gesture = await tester.startGesture(const Offset(10, 10));
    await gesture.moveBy(const Offset(0, 24));
    await gesture.up();
    await tester.pump();

    await tester.pump(const Duration(minutes: 1, seconds: 30));
    expect(platform.calls, <bool>[true]);

    await tester.pump(const Duration(minutes: 8, seconds: 31));
    expect(platform.calls, <bool>[true, false]);
  });

  testWidgets('releases the wake lock when the app pauses', (tester) async {
    final platform = _FakeScreenAwakePlatform();

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenAwakeIdleGate(
          platform: platform,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    expect(platform.calls, <bool>[true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(platform.calls, <bool>[true, false]);
  });
}

class _FakeScreenAwakePlatform implements ScreenAwakePlatform {
  final List<bool> calls = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
  }
}
