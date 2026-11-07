import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runtime font fetching is disabled in main.dart, so every Poppins variant
/// must ship as an asset (google_fonts matches files named `Family-Variant`).
void main() {
  const variants = ['Regular', 'Medium', 'SemiBold', 'Bold'];

  for (final variant in variants) {
    test('Poppins-$variant.ttf is bundled and declared', () {
      final path = 'assets/google_fonts/Poppins-$variant.ttf';
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      final header = file.openSync().readSync(4);
      expect(header, [0x00, 0x01, 0x00, 0x00], reason: 'TrueType header');
      expect(File('pubspec.yaml').readAsStringSync(), contains('- $path'));
    });
  }

  test('font license is bundled', () {
    expect(File('assets/google_fonts/OFL.txt').existsSync(), isTrue);
  });
}
