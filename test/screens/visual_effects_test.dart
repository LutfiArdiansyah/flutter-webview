import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webspace/screens/visual_effects.dart';
import 'package:webspace/services/device_performance_service.dart';

void main() {
  const color = Color(0x66000000);

  tearDown(() => DevicePerformanceService.debugSetLowEnd(isLowEnd: false));

  test('regular devices keep the original effects', () {
    DevicePerformanceService.debugSetLowEnd(isLowEnd: false);
    final backdrop = VisualEffects.dialogBackdrop(child: const SizedBox());
    expect(backdrop, isA<BackdropFilter>());
    expect(
      VisualEffects.shadow(color: color, blurRadius: 40, spreadRadius: 10),
      [const BoxShadow(color: color, blurRadius: 40, spreadRadius: 10)],
    );
    expect(VisualEffects.allowLoopingAnimations, isTrue);
  });

  test('low-end devices get the lightweight effects', () {
    DevicePerformanceService.debugSetLowEnd(isLowEnd: true);
    const child = SizedBox();
    expect(VisualEffects.dialogBackdrop(child: child), same(child));
    expect(
      VisualEffects.shadow(color: color, blurRadius: 40, spreadRadius: 10),
      [const BoxShadow(color: color, blurRadius: 8)],
    );
    expect(VisualEffects.shadow(color: color, blurRadius: 4), [
      const BoxShadow(color: color, blurRadius: 4),
    ]);
    expect(VisualEffects.allowLoopingAnimations, isFalse);
  });
}
