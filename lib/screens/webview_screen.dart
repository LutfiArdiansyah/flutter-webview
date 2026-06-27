import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_constants.dart';
import '../models/webview_config.dart';
import '../screens/error_logs_screen.dart';
import '../services/error_logger_service.dart';
import '../services/url_loader_service.dart';

/// Main screen displaying WebView content
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _webViewController;
  final UrlLoaderService _urlLoaderService = UrlLoaderService();
  final ErrorLoggerService _errorLogger = ErrorLoggerService();
  final FocusNode _webViewFocusNode = FocusNode();

  List<WebsiteConfig> _websites = [];
  WebsiteConfig? _selectedWebsite;
  String? _errorMessage;
  DateTime? _lastBackPressed;
  bool _isLoadingUrl = true;
  bool _isLoadingWebView = false;
  bool _selectionDialogVisible = false;
  bool _isLandscapeMode = false;
  bool _orientationInitialized = false;

  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _loadWebsites();
  }

  @override
  void dispose() {
    _webViewFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orientationInitialized) return;
    _isLandscapeMode =
        MediaQuery.of(context).orientation == Orientation.landscape;
    _orientationInitialized = true;
  }

  /// Initialize WebViewController with proper settings and performance tweaks
  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() => _isLoadingWebView = true);
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() => _isLoadingWebView = false);
            _webViewFocusNode.requestFocus();
          },
          onWebResourceError: (WebResourceError error) {
            final bool isMainFrame = error.isForMainFrame ?? false;
            if (!isMainFrame) return;

            if (error.description.contains('ERR_CONNECTION_REFUSED') ||
                error.description.contains('ERR_ABORTED')) {
              debugPrint('Ignoring WebView error: ${error.description}');
              return;
            }
            _handleWebViewError(error);
          },
          onNavigationRequest: (NavigationRequest request) {
            final currentHost = Uri.parse(_selectedWebsite!.webviewUrl).host;
            final nextHost = Uri.parse(request.url).host;

            if (nextHost != currentHost) {
              debugPrint('Blocked: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Performance tweaks specifically for Android TV (e.g. Media playback)
    if (_webViewController.platform is AndroidWebViewController) {
      final androidController =
          _webViewController.platform as AndroidWebViewController;
      // Allow media to auto-play without requiring user interaction (vital for Anime streaming)
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _loadWebsites() async {
    try {
      final websites = await _urlLoaderService.fetchWebsites();
      if (!mounted) return;

      setState(() {
        _websites = websites;
        _errorMessage = null;
        _isLoadingUrl = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWebsiteSelectionDialog();
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _showWebsiteSelectionDialog() async {
    if (!mounted || _selectionDialogVisible || _websites.isEmpty) return;

    _selectionDialogVisible = true;

    WebsiteConfig? tempSelected =
        _selectedWebsite ?? (_websites.isNotEmpty ? _websites.first : null);

    final selectedWebsite = await showDialog<WebsiteConfig>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: 500, maxHeight: 600),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 10),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.movie_filter,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              AppConstants.appSelectionTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _websites.length,
                          itemBuilder: (context, i) {
                            return _DialogWebsiteItem(
                              website: _websites[i],
                              tempSelected: tempSelected,
                              autofocus: i == 0,
                              onSelected: (value) {
                                setDialogState(() => tempSelected = value);
                              },
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => SystemNavigator.pop(),
                              child: const Text('Keluar',
                                  style: TextStyle(color: Colors.redAccent)),
                            ),
                            const Spacer(),
                            if (_selectedWebsite != null)
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Batal',
                                    style: TextStyle(color: Colors.white70)),
                              ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: tempSelected == null
                                  ? null
                                  : () => Navigator.pop(
                                      dialogContext, tempSelected),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                elevation: 8,
                                shadowColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.5),
                              ),
                              child: const Text(AppConstants.openButtonLabel,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .scale(curve: Curves.easeOutBack, duration: 400.ms)
                    .fadeIn(),
              );
            },
          ),
        );
      },
    );

    _selectionDialogVisible = false;

    if (!mounted || selectedWebsite == null) {
      if (mounted && _websites.isNotEmpty && _selectedWebsite == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWebsiteSelectionDialog();
        });
      }
      return;
    }

    setState(() {
      _selectedWebsite = selectedWebsite;
      _isLoadingUrl = false;
    });

    await _webViewController.loadRequest(Uri.parse(selectedWebsite.webviewUrl));
    _webViewFocusNode.requestFocus();
  }

  void _handleWebViewError(WebResourceError error) {
    String errorMsg = 'Failed to load page';
    if (error.description.contains('net::ERR_NAME_NOT_RESOLVED')) {
      errorMsg = 'DNS resolution failed. Check your connection.';
    } else if (error.description.contains('net::ERR_CONNECTION_REFUSED')) {
      errorMsg = 'Server refused connection.';
    } else if (error.description.contains('net::ERR_CONNECTION_RESET')) {
      errorMsg = 'Connection was reset.';
    } else if (error.description.contains('net::ERR_TIMED_OUT')) {
      errorMsg = 'Connection timed out.';
    } else {
      errorMsg = 'Error: ${error.description}';
    }

    _errorLogger.logError('WebView Loading Error', errorMsg,
        stackTrace: error.description);
    if (!mounted) return;
    setState(() => _isLoadingWebView = false);
  }

  void _handleError(Object error) {
    String errorMsg = AppConstants.genericErrorMessage;
    String errorTitle = 'Unknown Error';

    if (error is TimeoutException) {
      errorMsg = AppConstants.timeoutErrorMessage;
      errorTitle = 'Network Timeout';
    } else if (error is SocketException) {
      errorTitle = 'Network Error';
      if (error.message.contains('Network is unreachable')) {
        errorMsg = AppConstants.noInternetErrorMessage;
      } else {
        errorMsg = AppConstants.networkErrorMessage;
      }
    } else if (error is FormatException) {
      errorMsg = AppConstants.invalidJsonErrorMessage;
      errorTitle = 'JSON Parse Error';
    } else if (error is ArgumentError) {
      errorMsg = AppConstants.invalidUrlErrorMessage;
      errorTitle = 'Invalid URL Error';
    }

    _errorLogger.logError(errorTitle, errorMsg, stackTrace: error.toString());
    if (!mounted) return;
    setState(() {
      _errorMessage = errorMsg;
      _isLoadingUrl = false;
    });
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _isLoadingUrl = true;
      _websites = [];
      _selectedWebsite = null;
    });
    _loadWebsites();
  }

  Future<void> _toggleOrientation() async {
    final targetLandscape = !_isLandscapeMode;
    final orientations = targetLandscape
        ? const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight
          ]
        : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

    await SystemChrome.setPreferredOrientations(orientations);
    if (!mounted) return;
    setState(() => _isLandscapeMode = targetLandscape);
  }

  Widget _buildFloatingButtons() {
    return Padding(
        padding: const EdgeInsets.only(bottom: 30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isFabExpanded) ...[
              FloatingActionButton.extended(
                heroTag: 'switch-website',
                onPressed: () {
                  setState(() => _isFabExpanded = false);
                  _showWebsiteSelectionDialog();
                },
                icon: const Icon(Icons.public),
                label: const Text('Ganti Website',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              )
                  .animate()
                  .slideY(
                      begin: 1,
                      end: 0,
                      duration: 250.ms,
                      curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                heroTag: 'orientation-toggle',
                onPressed: () {
                  setState(() => _isFabExpanded = false);
                  _toggleOrientation();
                },
                icon: Icon(_isLandscapeMode
                    ? Icons.screen_lock_landscape
                    : Icons.screen_lock_portrait),
                label: Text(
                    _isLandscapeMode ? 'Mode Landscape' : 'Mode Portrait',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              )
                  .animate()
                  .slideY(
                      begin: 1,
                      end: 0,
                      duration: 250.ms,
                      curve: Curves.easeOutBack,
                      delay: 50.ms)
                  .fadeIn(),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                heroTag: 'exit-app',
                onPressed: () {
                  setState(() => _isFabExpanded = false);
                  SystemNavigator.pop();
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Keluar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              )
                  .animate()
                  .slideY(
                      begin: 1,
                      end: 0,
                      duration: 250.ms,
                      curve: Curves.easeOutBack,
                      delay: 100.ms)
                  .fadeIn(),
              const SizedBox(height: 16),
            ],
            FloatingActionButton(
              heroTag: 'menu-toggle',
              onPressed: () {
                setState(() {
                  _isFabExpanded = !_isFabExpanded;
                });
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(
                    turns: child.key == const ValueKey('icon1')
                        ? Tween<double>(begin: 0.5, end: 1).animate(anim)
                        : Tween<double>(begin: 0.5, end: 1).animate(anim),
                    child: FadeTransition(opacity: anim, child: child)),
                child: _isFabExpanded
                    ? const Icon(Icons.close, key: ValueKey('icon1'), size: 28)
                    : const Icon(Icons.menu, key: ValueKey('icon2'), size: 28),
              ),
            ),
          ],
        ));
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 50,
                        spreadRadius: 10),
                  ],
                ),
                child: const Icon(Icons.movie_filter,
                        size: 72, color: Colors.white)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.05, 1.05),
                        duration: 1.seconds),
              ),
              const SizedBox(height: 40),
              Text(
                _websites.isEmpty
                    ? 'Mempersiapkan WebSpace...'
                    : 'Memuat website terpilih...',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade900.withOpacity(0.4),
              Theme.of(context).colorScheme.background
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 120, color: Colors.red.shade400)
                    .animate()
                    .shake(hz: 4, curve: Curves.easeInOut)
                    .fadeIn(),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _errorMessage ?? 'Terjadi kesalahan tidak terduga',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ).animate().fadeIn(delay: 200.ms),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 8,
                      ),
                    ).animate().scale(delay: 400.ms),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ErrorLogsScreen()),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Lihat Log',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 8,
                      ),
                    ).animate().scale(delay: 500.ms),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) return _buildErrorScreen();
    if (_isLoadingUrl || _selectedWebsite == null) return _buildLoadingScreen();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (await _webViewController.canGoBack()) {
          await _webViewController.goBack();
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Tekan sekali lagi untuk keluar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  duration: const Duration(seconds: 2),
                ),
              );
          }
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: _errorLogger.getErrorCount() > 0
            ? AppBar(
                title: const Text(AppConstants.appTitle),
                elevation: 0,
                backgroundColor: Colors.black54,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bug_report_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ErrorLogsScreen()),
                            ).then((_) {
                              if (mounted) setState(() {});
                            });
                          },
                          tooltip: 'View error logs',
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10)),
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            child: Text(
                              '${_errorLogger.getErrorCount()}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          top: true,
          bottom: true,
          child: Stack(
            children: [
              Focus(
                focusNode: _webViewFocusNode,
                autofocus: true,
                child: WebViewWidget(controller: _webViewController),
              ),
              if (_isLoadingWebView)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    color: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: _buildFloatingButtons(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

class _DialogWebsiteItem extends StatefulWidget {
  final WebsiteConfig website;
  final WebsiteConfig? tempSelected;
  final bool autofocus;
  final ValueChanged<WebsiteConfig?> onSelected;

  const _DialogWebsiteItem({
    Key? key,
    required this.website,
    required this.tempSelected,
    required this.autofocus,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<_DialogWebsiteItem> createState() => _DialogWebsiteItemState();
}

class _DialogWebsiteItemState extends State<_DialogWebsiteItem> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final website = widget.website;
    final isSelected = widget.tempSelected == website;
    final isFocused = _isFocused;

    return InkWell(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onTap: () {
        _focusNode.requestFocus();
        widget.onSelected(website);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : (isFocused ? Colors.white.withOpacity(0.1) : Colors.black26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isFocused ? Colors.white54 : Colors.white12),
            width: isSelected || isFocused ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.public,
                color: isSelected ? Colors.white : Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    website.websiteName,
                    style: TextStyle(
                      fontWeight: isSelected || isFocused
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    website.webviewUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
