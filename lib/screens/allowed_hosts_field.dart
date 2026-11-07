import 'package:material_ui/material_ui.dart';

import '../constants/app_constants.dart';
import '../services/navigation_policy.dart';

/// Multiline input for a custom website's allowlist (one pattern per line),
/// with a button that adds the standard Google sign-in and captcha hosts.
///
/// Uses the same pattern rules as the remote `allowed` field, but rejects
/// invalid input instead of silently dropping it so the user can fix it.
class AllowedHostsField extends StatelessWidget {
  const AllowedHostsField({required this.controller, super.key});

  final TextEditingController controller;

  /// Text for the field from stored patterns.
  static String format(List<String> patterns) => patterns.join('\n');

  /// Valid, normalized patterns from the field text. Call after [validate].
  static List<String> parse(String? text) =>
      NavigationPolicy.parseAllowedHosts(_lines(text)).patterns;

  /// Form validator: null when every non-blank line is a valid pattern and
  /// the limit is respected.
  static String? validate(String? text) {
    final result = NavigationPolicy.parseAllowedHosts(_lines(text));
    if (result.invalidEntries.isNotEmpty) {
      return 'Format host tidak valid: ${result.invalidEntries.first}';
    }
    if (result.truncated) {
      return 'Maksimal ${AppConstants.maxAllowedHosts} host';
    }
    return null;
  }

  /// Appends [AppConstants.googleAndCaptchaHosts] to [text], skipping
  /// patterns already present and keeping the user's lines as typed.
  static String withGoogleAndCaptcha(String text) {
    final existing = <String>{
      for (final line in _lines(text)) ?NavigationPolicy.normalizePattern(line),
    };
    final additions = AppConstants.googleAndCaptchaHosts
        .where((h) => !existing.contains(h))
        .toList();
    if (additions.isEmpty) {
      return text;
    }
    final base = text.trimRight();
    return [if (base.isNotEmpty) base, ...additions].join('\n');
  }

  static List<String> _lines(String? text) =>
      (text ?? '').split(RegExp(r'\r?\n'));

  void _fillGoogleAndCaptcha() {
    final updated = withGoogleAndCaptcha(controller.text);
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: AppConstants.allowedHostsLabel,
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: AppConstants.allowedHostsHint,
            hintStyle: const TextStyle(color: Colors.white30),
            helperText: AppConstants.allowedHostsHelper,
            helperStyle: const TextStyle(color: Colors.white54),
            helperMaxLines: 2,
            errorMaxLines: 2,
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
          validator: validate,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _fillGoogleAndCaptcha,
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: const Text(AppConstants.fillGoogleAndCaptchaLabel),
          ),
        ),
      ],
    );
  }
}
