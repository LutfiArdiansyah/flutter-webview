import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webspace/constants/app_constants.dart';
import 'package:webspace/screens/allowed_hosts_field.dart';

void main() {
  group('AllowedHostsField helpers', () {
    test('validate accepts empty and valid input', () {
      expect(AllowedHostsField.validate(null), isNull);
      expect(AllowedHostsField.validate(''), isNull);
      expect(
        AllowedHostsField.validate('*.a.com\r\n\n  https://b.com  \nb.com'),
        isNull,
      );
    });

    test('validate reports the first invalid line', () {
      expect(
        AllowedHostsField.validate('ok.com\n*\nbad:1'),
        'Format host tidak valid: *',
      );
    });

    test('validate rejects more than the limit', () {
      final text = [
        for (var i = 0; i <= AppConstants.maxAllowedHosts; i++) 'h$i.com',
      ].join('\n');
      expect(AllowedHostsField.validate(text), contains('Maksimal'));
    });

    test('parse normalizes and de-duplicates', () {
      expect(AllowedHostsField.parse(' B.com\n\nhttps://b.com\n*.A.com '), [
        'b.com',
        '*.a.com',
      ]);
    });

    test('format and parse round-trip', () {
      const patterns = ['*.a.com', 'www.google.com/recaptcha/'];
      expect(
        AllowedHostsField.parse(AllowedHostsField.format(patterns)),
        patterns,
      );
    });

    test('withGoogleAndCaptcha appends without duplicates', () {
      final once = AllowedHostsField.withGoogleAndCaptcha(
        '*.site.com\nAccounts.Google.com\n',
      );
      final lines = once.split('\n');
      expect(lines.first, '*.site.com');
      expect(lines[1], 'Accounts.Google.com');
      expect(
        lines.where((l) => l.toLowerCase() == 'accounts.google.com'),
        hasLength(1),
      );
      expect(AllowedHostsField.withGoogleAndCaptcha(once), once);
      expect(AllowedHostsField.validate(once), isNull);
    });

    test('withGoogleAndCaptcha on empty text adds the full list', () {
      expect(
        AllowedHostsField.withGoogleAndCaptcha('').split('\n'),
        AppConstants.googleAndCaptchaHosts,
      );
    });
  });

  testWidgets('fill button and validation in a form', (tester) async {
    final controller = TextEditingController(text: 'bad host');
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AllowedHostsField(controller: controller),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Format host tidak valid: bad host'), findsOneWidget);

    controller.text = '*.site.com';
    await tester.tap(find.text(AppConstants.fillGoogleAndCaptchaLabel));
    await tester.pump();
    expect(controller.text.split('\n').first, '*.site.com');
    expect(controller.text, contains('accounts.google.com'));

    await tester.tap(find.text(AppConstants.fillGoogleAndCaptchaLabel));
    await tester.pump();
    expect('accounts.google.com'.allMatches(controller.text).length, 1);
    expect(formKey.currentState!.validate(), isTrue);
    controller.dispose();
  });
}
