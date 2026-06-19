import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

    if (_orientationInitialized) {
      return;
    }

    _isLandscapeMode =
        MediaQuery.of(context).orientation == Orientation.landscape;
    _orientationInitialized = true;
  }

  /// Initialize WebViewController with proper settings
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

            if (!isMainFrame) {
              return;
            }

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
  }

  /// Load website list from remote JSON configuration
  Future<void> _loadWebsites() async {
    try {
      final websites = await _urlLoaderService.fetchWebsites();
      if (!mounted) {
        return;
      }

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

  /// Show popup selection for website choice
  Future<void> _showWebsiteSelectionDialog() async {
    if (!mounted || _selectionDialogVisible || _websites.isEmpty) {
      return;
    }

    _selectionDialogVisible = true;

    WebsiteConfig? tempSelected =
        _selectedWebsite ?? (_websites.isNotEmpty ? _websites.first : null);

    final selectedWebsite = await showDialog<WebsiteConfig>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(AppConstants.appSelectionTitle),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _websites.length; i++)
                        _DialogWebsiteItem(
                          website: _websites[i],
                          tempSelected: tempSelected,
                          autofocus: i == 0,
                          onSelected: (value) {
                            setDialogState(() {
                              tempSelected = value;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: tempSelected == null
                      ? null
                      : () => Navigator.pop(dialogContext, tempSelected),
                  child: const Text(AppConstants.openButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );

    _selectionDialogVisible = false;

    if (!mounted || selectedWebsite == null) {
      if (mounted && _websites.isNotEmpty) {
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

  /// Handle WebView loading errors
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

    _errorLogger.logError(
      'WebView Loading Error',
      errorMsg,
      stackTrace: error.description,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingWebView = false;
    });
  }

  /// Handle URL loading errors
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

    _errorLogger.logError(
      errorTitle,
      errorMsg,
      stackTrace: error.toString(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = errorMsg;
      _isLoadingUrl = false;
    });
  }

  /// Retry loading website list
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
            DeviceOrientation.landscapeRight,
          ]
        : const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ];

    await SystemChrome.setPreferredOrientations(orientations);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLandscapeMode = targetLandscape;
    });
  }

  Widget _buildOrientationToggleButton() {
    final nextIsLandscape = !_isLandscapeMode;
    final icon = nextIsLandscape
        ? Icons.screen_lock_landscape
        : Icons.screen_lock_portrait;
    final tooltip = nextIsLandscape ? 'Ubah ke landscape' : 'Ubah ke portrait';

    return FloatingActionButton(
      heroTag: 'orientation-toggle',
      onPressed: _toggleOrientation,
      tooltip: tooltip,
      child: Icon(icon),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appTitle),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _websites.isEmpty
                  ? 'Memuat daftar website...'
                  : 'Memuat website terpilih...',
            ),
          ],
        ),
      ),
      floatingActionButton: _buildOrientationToggleButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appTitle),
        elevation: 0,
        backgroundColor: Colors.red.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ErrorLogsScreen(),
                ),
              ).then((_) {
                if (mounted) {
                  setState(() {});
                }
              });
            },
            tooltip: 'View error logs',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ErrorLogsScreen(),
                        ),
                      ).then((_) {
                        if (mounted) {
                          setState(() {});
                        }
                      });
                    },
                    icon: const Icon(Icons.bug_report),
                    label: const Text('View Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildOrientationToggleButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    if (_isLoadingUrl || _selectedWebsite == null) {
      return _buildLoadingScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
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
                const SnackBar(
                  content: Text('Tekan sekali lagi untuk keluar'),
                  duration: Duration(seconds: 2),
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
                                builder: (context) => const ErrorLogsScreen(),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() {});
                              }
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '${_errorLogger.getErrorCount()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
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
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
              
              Positioned(
                left: 16,
                bottom: 80, // posisi tombol
                child: _buildOrientationToggleButton(),
              ),
            ],
          ),
        ),
        /* floatingActionButton: _buildOrientationToggleButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, */
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
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final website = widget.website;
    final tempSelected = widget.tempSelected;
    final isFocused = _isFocused;

    return InkWell(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onTap: () {
        _focusNode.requestFocus();
        widget.onSelected(website);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isFocused
              ? Theme.of(context).colorScheme.primaryContainer
              : (tempSelected == website
                  ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused
                ? Theme.of(context).colorScheme.primary
                : (tempSelected == website
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey.shade300),
            width: isFocused ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<WebsiteConfig>(
              value: website,
              groupValue: tempSelected,
              onChanged: (value) {
                _focusNode.requestFocus();
                widget.onSelected(value);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    website.websiteName,
                    style: TextStyle(
                      fontWeight: isFocused || tempSelected == website
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    website.webviewUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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

