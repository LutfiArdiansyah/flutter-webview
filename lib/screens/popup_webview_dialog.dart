import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/app_constants.dart';
import '../services/navigation_policy.dart';
import '../services/webview_user_agent_switcher.dart';

/// Shows a popup window opened by the page (e.g. "Sign in with Google").
///
/// The popup is backed by the native window [windowId], so it shares cookies
/// with the main WebView and `window.opener.postMessage` reaches the page.
/// It follows the same [policy] as the main WebView and never opens further
/// popups.
class PopupWebViewDialog extends StatefulWidget {
  const PopupWebViewDialog({
    required this.windowId,
    required this.policy,
    required this.initialUserAgent,
    super.key,
  });

  final int windowId;
  final NavigationPolicy policy;
  final String? initialUserAgent;

  @override
  State<PopupWebViewDialog> createState() => _PopupWebViewDialogState();
}

class _PopupWebViewDialogState extends State<PopupWebViewDialog> {
  late final WebViewUserAgentSwitcher _userAgentSwitcher =
      WebViewUserAgentSwitcher(initialUserAgent: widget.initialUserAgent);
  InAppWebViewController? _controller;
  bool _isLoading = true;

  void _close() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  autofocus: true,
                  icon: const Icon(Icons.close),
                  tooltip: AppConstants.closePopupTooltip,
                  onPressed: _close,
                ),
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: InAppWebView(
                  windowId: widget.windowId,
                  initialSettings: buildWebViewSettings(
                    userAgent: widget.initialUserAgent,
                  ),
                  onWebViewCreated: (controller) => _controller = controller,
                  onLoadStart: (controller, url) {
                    _userAgentSwitcher.applyFor(controller, url?.toString());
                    if (mounted) {
                      setState(() => _isLoading = true);
                    }
                  },
                  onLoadStop: (controller, url) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  },
                  shouldOverrideUrlLoading: (controller, action) async {
                    final url = action.request.url?.toString();
                    if (!widget.policy.isAllowed(url)) {
                      debugPrint('Blocked: ${blockedHostForLog(url)}');
                      return NavigationActionPolicy.CANCEL;
                    }
                    if (action.isForMainFrame) {
                      await _userAgentSwitcher.applyFor(controller, url);
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  // Only one popup level: nested popups are refused.
                  onCreateWindow: (controller, action) => false,
                  onCloseWindow: (controller) => _close(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
