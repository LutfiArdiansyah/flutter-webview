import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../services/device_performance_service.dart';

/// GPU-heavy effects that fall back to cheaper equivalents on low-end
/// devices ([DevicePerformanceService.isLowEnd]); other devices render them
/// exactly as before.
class VisualEffects {
  const VisualEffects._();

  /// Backdrop blur used behind dialogs.
  static const double dialogBlurSigma = 10;

  /// Largest shadow blur used on low-end devices.
  static const double lowEndMaxShadowBlur = 8;

  /// Wraps a dialog in a backdrop blur. Low-end devices skip the blur (the
  /// modal barrier still dims the page): a full-screen blur over the WebView
  /// re-samples every frame and is the main source of dialog jank on
  /// ARMv7 set-top boxes.
  static Widget dialogBackdrop({required Widget child}) {
    if (DevicePerformanceService.isLowEnd) {
      return child;
    }
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: dialogBlurSigma,
        sigmaY: dialogBlurSigma,
      ),
      child: child,
    );
  }

  /// A soft glow/drop shadow. Low-end devices get a smaller blur without
  /// spread, which keeps the depth cue at a fraction of the fill cost.
  static List<BoxShadow> shadow({
    required Color color,
    required double blurRadius,
    double spreadRadius = 0,
  }) {
    if (DevicePerformanceService.isLowEnd) {
      return [
        BoxShadow(
          color: color,
          blurRadius: math.min(blurRadius, lowEndMaxShadowBlur),
        ),
      ];
    }
    return [
      BoxShadow(
        color: color,
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ];
  }

  /// Whether decorative animations may loop forever. Low-end devices play
  /// them once to avoid repainting every frame while idle.
  static bool get allowLoopingAnimations => !DevicePerformanceService.isLowEnd;
}
