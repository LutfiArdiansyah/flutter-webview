import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'services/device_performance_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Poppins ships in assets/google_fonts: never download fonts at runtime
  // (slow first launch on set-top boxes, font swap flicker, fails offline).
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

  // Bounded by a short timeout; falls back to the ABI check on failure.
  await DevicePerformanceService.initialize();

  runApp(const WebSpaceApp());
}
