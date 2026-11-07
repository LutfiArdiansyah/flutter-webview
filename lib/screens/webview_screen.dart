import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/app_constants.dart';
import '../models/webview_config.dart';
import '../screens/error_logs_screen.dart';
import '../services/database_service.dart';
import '../services/error_logger_service.dart';
import '../services/navigation_policy.dart';
import '../services/screen_orientation_service.dart';
import '../services/url_loader_service.dart';
import '../services/website_search_index.dart';
import '../services/webview_user_agent_switcher.dart';
import 'allowed_hosts_field.dart';
import 'popup_webview_dialog.dart';
import 'visual_effects.dart';

/// Main screen displaying WebView content
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  /// Available once the main [InAppWebView] has been created; null while it
  /// is not in the tree.
  InAppWebViewController? _webViewController;
  Completer<InAppWebViewController> _webViewReady = Completer();
  WebViewUserAgentSwitcher? _userAgentSwitcher;

  /// Navigation rules for the selected website. Null blocks everything.
  NavigationPolicy? _navigationPolicy;

  /// Context of the open popup dialog, if any (at most one at a time).
  BuildContext? _popupContext;
  bool _isPopupOpen = false;

  final UrlLoaderService _urlLoaderService = UrlLoaderService();
  final ErrorLoggerService _errorLogger = ErrorLoggerService();
  final DatabaseService _databaseService = DatabaseService();
  final ScreenOrientationService _screenOrientationService =
      ScreenOrientationService();
  final FocusNode _webViewFocusNode = FocusNode();

  /// Completes once WebView data left over from a previous session has been
  /// cleared. Never throws; awaited before the first page load so stale
  /// cookies/storage can never leak into a fresh session.
  late final Future<void> _startupCleanup;

  List<WebsiteConfig> _websites = [];
  WebsiteSearchIndex? _searchIndexCache;

  /// Search index for [_websites], rebuilt only when the list is replaced.
  WebsiteSearchIndex get _websiteSearchIndex {
    final cached = _searchIndexCache;
    if (cached != null && identical(cached.websites, _websites)) {
      return cached;
    }
    return _searchIndexCache = WebsiteSearchIndex(_websites);
  }
  WebsiteConfig? _selectedWebsite;
  String? _errorMessage;
  DateTime? _lastBackPressed;
  bool _isLoadingUrl = true;
  /// Page-load progress. A notifier (not setState) so load events only
  /// repaint the progress bar instead of rebuilding the whole screen.
  final ValueNotifier<bool> _isLoadingWebView = ValueNotifier(false);
  bool _selectionDialogVisible = false;
  bool _isLandscapeMode = false;
  bool _orientationInitialized = false;

  /// FAB menu state; only the FAB column listens to it.
  final ValueNotifier<bool> _isFabExpanded = ValueNotifier(false);

  /// Error count shown in the app bar at the last build; see
  /// [_syncErrorBadge].
  int _renderedErrorCount = 0;

  @override
  void initState() {
    super.initState();
    // Runs concurrently with loading the website list so startup isn't slowed.
    _startupCleanup = _clearWebViewDataOnStartup();
    _loadWebsites();
  }

  @override
  void dispose() {
    _webViewFocusNode.dispose();
    _isLoadingWebView.dispose();
    _isFabExpanded.dispose();
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

  /// Main WebView. Settings (JS, media autoplay without gesture, popups)
  /// come from [buildWebViewSettings].
  Widget _buildWebView() => InAppWebView(
        initialSettings: buildWebViewSettings(),
        onWebViewCreated: (controller) {
          _webViewController = controller;
          _userAgentSwitcher =
              WebViewUserAgentSwitcher(initialUserAgent: null);
          if (!_webViewReady.isCompleted) {
            _webViewReady.complete(controller);
          }
        },
        onLoadStart: (controller, url) {
          // Fallback for loads that skip shouldOverrideUrlLoading (e.g. POST
          // form submissions returning from Google sign-in).
          _userAgentSwitcher?.applyFor(controller, url?.toString());
          if (!mounted) {
            return;
          }
          _isLoadingWebView.value = true;
          _syncErrorBadge();
        },
        onLoadStop: (controller, url) {
          if (!mounted) {
            return;
          }
          _isLoadingWebView.value = false;
          _syncErrorBadge();
          _webViewFocusNode.requestFocus();
        },
        onReceivedError: (controller, request, error) {
          final isMainFrame = request.isForMainFrame ?? false;
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
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url?.toString();
          final policy = _navigationPolicy;
          if (policy == null || !policy.isAllowed(url)) {
            debugPrint('Blocked: ${blockedHostForLog(url)}');
            return NavigationActionPolicy.CANCEL;
          }
          if (action.isForMainFrame) {
            await _userAgentSwitcher?.applyFor(controller, url);
          }
          return NavigationActionPolicy.ALLOW;
        },
        onCreateWindow: (controller, action) => _openPopup(action),
      );

  /// Opens an allowlisted popup (e.g. "Sign in with Google") in a dialog.
  /// Returns false to refuse it: not allowlisted, or a popup is already
  /// open (keeps pop-under ads and popup floods out).
  Future<bool> _openPopup(CreateWindowAction action) async {
    final policy = _navigationPolicy;
    final url = action.request.url?.toString();
    if (!mounted || policy == null || _isPopupOpen) {
      return false;
    }
    // A popup opened without a URL navigates afterwards; the popup itself
    // enforces the same policy on that navigation.
    final hasUrl = url != null && url.isNotEmpty;
    if (hasUrl && !policy.isAllowed(url)) {
      debugPrint('Blocked popup: ${blockedHostForLog(url)}');
      return false;
    }

    _isPopupOpen = true;
    final userAgent =
        await WebViewUserAgentSwitcher.initialUserAgentFor(hasUrl ? url : null);
    if (!mounted) {
      _isPopupOpen = false;
      return false;
    }

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          _popupContext = dialogContext;
          return PopupWebViewDialog(
            windowId: action.windowId,
            policy: policy,
            initialUserAgent: userAgent,
          );
        },
      ).whenComplete(() {
        _popupContext = null;
        _isPopupOpen = false;
        if (mounted) {
          _webViewFocusNode.requestFocus();
        }
      }),
    );
    return true;
  }

  void _closePopup() {
    final popupContext = _popupContext;
    if (popupContext != null && popupContext.mounted) {
      Navigator.of(popupContext).pop();
    }
  }

  /// Rebuilds [_navigationPolicy] for the selected website, using the
  /// freshest stored allowlist (it may have changed through a sync or edit
  /// after the website was selected).
  void _refreshNavigationPolicy() {
    final selected = _selectedWebsite;
    if (selected == null) {
      _navigationPolicy = null;
      return;
    }
    final latest = _websites.firstWhere(
      (w) => selected.isCustom
          ? w.id == selected.id
          : !w.isCustom && w.webviewUrl == selected.webviewUrl,
      orElse: () => selected,
    );
    _navigationPolicy =
        NavigationPolicy.forWebsite(selected.webviewUrl, latest.allowedHosts);
  }

  /// Forgets the main WebView when it leaves the tree (no website selected),
  /// so the next selection waits for the newly created one.
  void _detachWebView() {
    _closePopup();
    _webViewController = null;
    _userAgentSwitcher = null;
    if (_webViewReady.isCompleted) {
      _webViewReady = Completer();
    }
  }

  /// Default websites stored before allowlists existed have no `allowed`
  /// hosts. Re-sync them once in the background; on failure the next launch
  /// tries again. Never blocks or interrupts the user.
  Future<void> _resyncAllowlistsIfNeeded() async {
    try {
      if (!await _databaseService.needsAllowlistResync()) {
        return;
      }
      final remoteWebsites = await _urlLoaderService.fetchWebsites();
      await _databaseService.syncDefaultWebsites(remoteWebsites);
      final updatedWebsites = await _databaseService.getWebsites();
      if (!mounted) {
        return;
      }
      setState(() {
        _websites = updatedWebsites;
        _refreshNavigationPolicy();
      });
    } on Exception catch (e) {
      debugPrint('Allowlist resync failed: $e');
      _errorLogger.logWarning(
        'Allowlist Resync',
        'Background sync failed; it will be retried on next launch.',
      );
    }
  }

  Future<void> _loadWebsites() async {
    try {
      var websites = await _databaseService.getWebsites();

      if (websites.isEmpty) {
        final remoteWebsites = await _urlLoaderService.fetchWebsites();
        await _databaseService.syncDefaultWebsites(remoteWebsites);
        websites = await _databaseService.getWebsites();
      } else {
        unawaited(_resyncAllowlistsIfNeeded());
      }

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
    } on Exception catch (e) {
      _handleError(e);
    }
  }

  Future<void> _showWebsiteSelectionDialog() async {
    if (!mounted || _selectionDialogVisible || _websites.isEmpty) {
      return;
    }

    _selectionDialogVisible = true;

    var tempSelected =
        _selectedWebsite ?? (_websites.isNotEmpty ? _websites.first : null);

    var searchQuery = '';

    final selectedWebsite = await showDialog<WebsiteConfig>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => VisualEffects.dialogBackdrop(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            // Keep tempSelected in sync with available websites
            if (tempSelected == null && _websites.isNotEmpty) {
              tempSelected = _websites.first;
            } else if (tempSelected != null &&
                !_websites
                    .any((w) => w.webviewUrl == tempSelected!.webviewUrl)) {
              tempSelected = _websites.isNotEmpty ? _websites.first : null;
            }

            // Use MediaQuery so the dialog always fits inside the physical

            final filteredWebsites = _websiteSearchIndex.filter(searchQuery);
            // screen regardless of device size or pixel density.
            final screenHeight = MediaQuery.of(context).size.height;
            final maxDialogHeight = (screenHeight * 0.82).clamp(300.0, 600.0);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              alignment: Alignment.center,
              // insetPadding guarantees a safe margin from all screen edges
              // and prevents the dialog from ever overflowing the viewport.
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                // width: double.infinity makes the container always fill the
                // available width (bounded by insetPadding + maxWidth) so the
                // dialog stays centered and looks consistent on all devices.
                width: double.infinity,
                constraints:
                    BoxConstraints(maxWidth: 500, maxHeight: maxDialogHeight),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: VisualEffects.shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
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
                          const Spacer(),
                          if (_isLoadingUrl)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          else
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white70),
                              tooltip: 'Opsi',
                              color: const Color(0xFF1E1E2E),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == 'sync') {
                                  _syncWebsites(setDialogState);
                                } else if (value == 'add') {
                                  _showAddEditWebsiteDialog(
                                      context, null, setDialogState);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'sync',
                                  child: Row(
                                    children: [
                                      Icon(Icons.sync,
                                          color: Colors.blueAccent, size: 20),
                                      SizedBox(width: 12),
                                      Text('Sync Online'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'add',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add,
                                          color: Colors.greenAccent, size: 20),
                                      SizedBox(width: 12),
                                      Text('Tambah Website'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    if (_websites.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cari website (nama atau url)...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white54,
                            ),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (value) {
                            setDialogState(() {
                              searchQuery = value;
                            });
                          },
                        ),
                      ),
                    const Divider(height: 1, color: Colors.white12),
                    Flexible(
                      child: _isLoadingUrl
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _websites.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Text(
                                      'Tidak ada website tersedia.\n'
                                      'Klik Sync Online untuk mengunduh.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                )
                              : filteredWebsites.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(40),
                                        child: Text(
                                          'Tidak Ada Hasil',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: shouldShrinkWrapList(
                                        filteredWebsites.length,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      itemCount: filteredWebsites.length,
                                      itemBuilder: (context, i) =>
                                          _DialogWebsiteItem(
                                        website: filteredWebsites[i],
                                        tempSelected: tempSelected,
                                        autofocus: i == 0,
                                        onSelected: (value) {
                                          setDialogState(() {
                                            tempSelected = value;
                                          });
                                        },
                                        onEdit: () {
                                          _showAddEditWebsiteDialog(
                                            context,
                                            filteredWebsites[i],
                                            setDialogState,
                                          );
                                        },
                                        onDelete: () {
                                          _showDeleteConfirmDialog(
                                            context,
                                            filteredWebsites[i],
                                            setDialogState,
                                          );
                                        },
                                      ),
                                    ),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const TextButton(
                            onPressed: SystemNavigator.pop,
                            child: Text('Keluar',
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
                            onPressed: tempSelected == null || _isLoadingUrl
                                ? null
                                : () =>
                                    Navigator.pop(dialogContext, tempSelected),
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
                                  .withValues(alpha: 0.5),
                            ),
                            child: const Text(AppConstants.openButtonLabel,
                                style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
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

    _closePopup();
    setState(() {
      _selectedWebsite = selectedWebsite;
      _isLoadingUrl = false;
      _refreshNavigationPolicy();
    });

    await _startupCleanup;
    if (!mounted) {
      return;
    }
    final controller = await _webViewReady.future;
    if (!mounted) {
      return;
    }
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(selectedWebsite.webviewUrl)),
    );
    _webViewFocusNode.requestFocus();
  }

  Future<void> _syncWebsites(StateSetter setDialogState) async {
    final messenger = ScaffoldMessenger.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    try {
      setDialogState(() {
        _isLoadingUrl = true;
      });

      final remoteWebsites = await _urlLoaderService.fetchWebsites();
      await _databaseService.syncDefaultWebsites(remoteWebsites);
      final updatedWebsites = await _databaseService.getWebsites();

      if (!mounted) {
        return;
      }

      setState(() {
        _websites = updatedWebsites;
      });

      setDialogState(() {
        _isLoadingUrl = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Berhasil sinkronisasi website online!',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: primaryColor,
        ),
      );
    } on Exception catch (e) {
      _errorLogger.logError('Sync Error', e.toString());
      if (!mounted) {
        return;
      }

      setDialogState(() {
        _isLoadingUrl = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Gagal sinkronisasi: $e',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAddEditWebsiteDialog(
    BuildContext context,
    WebsiteConfig? existing,
    StateSetter setDialogState,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameController =
        TextEditingController(text: existing?.websiteName ?? '');
    final urlController =
        TextEditingController(text: existing?.webviewUrl ?? '');
    final allowedController = TextEditingController(
      text: AllowedHostsField.format(existing?.allowedHosts ?? const []),
    );

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return VisualEffects.dialogBackdrop(
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: VisualEffects.shadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            existing == null
                                ? Icons.add_to_home_screen
                                : Icons.edit,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            existing == null
                                ? 'Tambah Website'
                                : 'Edit Website',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameController,
                        maxLength: 50,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nama Website',
                          labelStyle: const TextStyle(color: Colors.white70),
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
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama website tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'URL Website',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'https://example.com',
                          hintStyle: const TextStyle(color: Colors.white30),
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
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'URL tidak boleh kosong';
                          }
                          final urlPattern = RegExp(
                            r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
                            caseSensitive: false,
                          );
                          if (!urlPattern.hasMatch(value)) {
                            return 'Format URL tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AllowedHostsField(controller: allowedController),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Batal',
                                style: TextStyle(color: Colors.white70)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                final name = nameController.text.trim();
                                var url = urlController.text.trim();
                                if (!url.startsWith('http://') &&
                                    !url.startsWith('https://')) {
                                  url = 'https://$url';
                                }
                                final allowedHosts = AllowedHostsField.parse(
                                  allowedController.text,
                                );

                                if (existing == null) {
                                  final newSite = WebsiteConfig(
                                    websiteName: name,
                                    webviewUrl: url,
                                    isCustom: true,
                                    allowedHosts: allowedHosts,
                                  );
                                  await _databaseService.insertWebsite(newSite);
                                } else {
                                  final updatedSite = WebsiteConfig(
                                    id: existing.id,
                                    websiteName: name,
                                    webviewUrl: url,
                                    version: existing.version,
                                    isCustom: true,
                                    allowedHosts: allowedHosts,
                                  );
                                  await _databaseService
                                      .updateWebsite(updatedSite);
                                }

                                final updatedWebsites =
                                    await _databaseService.getWebsites();
                                if (!mounted) {
                                  return;
                                }

                                setState(() {
                                  _websites = updatedWebsites;
                                  // Applies an edited allowlist to the
                                  // website that is currently open.
                                  _refreshNavigationPolicy();
                                });

                                setDialogState(() {});

                                if (!dialogContext.mounted) {
                                  return;
                                }
                                Navigator.pop(dialogContext);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(existing == null ? 'Tambah' : 'Simpan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    WebsiteConfig website,
    StateSetter setDialogState,
  ) {
    if (website.id == null) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return VisualEffects.dialogBackdrop(
          child: AlertDialog(
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Text('Hapus Website',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              'Apakah Anda yakin ingin menghapus "${website.websiteName}"?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal',
                    style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _databaseService.deleteWebsite(website.id!);
                  final updatedWebsites = await _databaseService.getWebsites();

                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    _websites = updatedWebsites;
                    if (_selectedWebsite?.id == website.id) {
                      _selectedWebsite = null;
                      _detachWebView();
                    }
                    _refreshNavigationPolicy();
                  });

                  setDialogState(() {});

                  if (!dialogContext.mounted) {
                    return;
                  }
                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleWebViewError(WebResourceError error) {
    var errorMsg = 'Failed to load page';
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
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingWebView.value = false;
    });
  }

  void _handleError(Object error) {
    var errorMsg = AppConstants.genericErrorMessage;
    var errorTitle = 'Unknown Error';

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
    if (!mounted) {
      return;
    }
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
      _detachWebView();
      _refreshNavigationPolicy();
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
    if (targetLandscape) {
      await _screenOrientationService.setLandscapeFollowingSensor();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isLandscapeMode = targetLandscape;
    });
  }

  /// Clears WebView cache, local storage and (on Android) cookies.
  /// Uses static APIs so it also works before any WebView exists.
  Future<void> _clearWebViewData() async {
    await InAppWebViewController.clearAllCache();
    await WebStorageManager.instance().deleteAllData();
    if (Platform.isAndroid) {
      await CookieManager.instance().deleteAllCookies();
    }
  }

  /// Clears WebView data on app launch. Failures are logged and swallowed so
  /// a cleanup problem never blocks the user from opening a website.
  Future<void> _clearWebViewDataOnStartup() async {
    try {
      await _clearWebViewData();
    } on Exception catch (e) {
      _errorLogger.logError('Startup Cleanup Error', e.toString());
    }
  }

  Future<void> _clearCacheAndData() async {
    _closePopup();
    _isLoadingWebView.value = true;
    _isFabExpanded.value = false;

    await _clearWebViewData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Cache dan Data berhasil dibersihkan',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

    await _webViewController?.reload();

    if (!mounted) {
      return;
    }
    _isLoadingWebView.value = false;
    _syncErrorBadge();
  }

  /// Rebuilds the screen only when the error count shown in the app bar is
  /// stale (errors can be logged outside setState, e.g. startup cleanup).
  void _syncErrorBadge() {
    if (mounted && _errorLogger.getErrorCount() != _renderedErrorCount) {
      setState(() {});
    }
  }

  // Listens to [_isFabExpanded] so opening/closing the menu rebuilds only the
  // buttons; the RepaintBoundary keeps their animations from repainting the
  // rest of the screen.
  Widget _buildFloatingButtons() => RepaintBoundary(
      child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.sizeOf(context).height * 0.05,
      ),
      child: ValueListenableBuilder<bool>(
      valueListenable: _isFabExpanded,
      builder: (context, isFabExpanded, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isFabExpanded) ...[
            FloatingActionButton.extended(
              heroTag: 'clear-cache',
              onPressed: _clearCacheAndData,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Clear Cache',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.orange.shade700,
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
              heroTag: 'switch-website',
              onPressed: () {
                _isFabExpanded.value = false;
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
                _isFabExpanded.value = false;
                _toggleOrientation();
              },
              icon: Icon(_isLandscapeMode
                  ? Icons.screen_lock_landscape
                  : Icons.screen_lock_portrait),
              label: Text(_isLandscapeMode ? 'Mode Landscape' : 'Mode Portrait',
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
                _isFabExpanded.value = false;
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
              _isFabExpanded.value = !_isFabExpanded.value;
            },
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                  turns: child.key == const ValueKey('icon1')
                      ? Tween<double>(begin: 0.5, end: 1).animate(anim)
                      : Tween<double>(begin: 0.5, end: 1).animate(anim),
                  child: FadeTransition(opacity: anim, child: child)),
              child: isFabExpanded
                  ? const Icon(Icons.close, key: ValueKey('icon1'), size: 28)
                  : const Icon(Icons.menu, key: ValueKey('icon2'), size: 28),
            ),
          ),
        ],
      ))));

  Widget _buildLoadingScreen() => Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    boxShadow: VisualEffects.shadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ),
                  child: const Icon(Icons.movie_filter,
                          size: 72, color: Colors.white)
                      .animate(
                        onPlay: (c) {
                          // Low-end devices play the pulse once instead of
                          // repainting it every frame.
                          if (VisualEffects.allowLoopingAnimations) {
                            c.repeat(reverse: true);
                          }
                        },
                      )
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Colors.white54),
              ],
            ),
          ),
        ),
      );

  Widget _buildErrorScreen() => Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.shade900.withValues(alpha: 0.4),
                Theme.of(context).colorScheme.surface
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                          size: 120, color: Colors.red.shade400)
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
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
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
                            if (mounted) {
                              setState(() {});
                            }
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

  @override
  Widget build(BuildContext context) {
    _renderedErrorCount = _errorLogger.getErrorCount();
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }
    if (_isLoadingUrl || _selectedWebsite == null) {
      return _buildLoadingScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        final surfaceColor = Theme.of(context).colorScheme.surface;

        final controller = _webViewController;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text(
                  'Tekan sekali lagi untuk keluar',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: surfaceColor,
                duration: const Duration(seconds: 2),
              ),
            );
          return;
        }
        await SystemNavigator.pop();
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
                child: _buildWebView(),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isLoadingWebView,
                  builder: (context, isLoading, _) => isLoading
                      ? RepaintBoundary(
                          child: LinearProgressIndicator(
                            color: Theme.of(context).colorScheme.secondary,
                            backgroundColor: Colors.transparent,
                          ),
                        )
                      : const SizedBox.shrink(),
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
  const _DialogWebsiteItem({
    required this.website,
    required this.tempSelected,
    required this.autofocus,
    required this.onSelected,
    this.onEdit,
    this.onDelete,
  });
  final WebsiteConfig website;
  final WebsiteConfig? tempSelected;
  final bool autofocus;
  final ValueChanged<WebsiteConfig?> onSelected;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : (isFocused
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black26),
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
          Expanded(
            child: InkWell(
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              onTap: () {
                _focusNode.requestFocus();
                widget.onSelected(website);
              },
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                bottomLeft: const Radius.circular(15),
                topRight:
                    website.isCustom ? Radius.zero : const Radius.circular(15),
                bottomRight:
                    website.isCustom ? Radius.zero : const Radius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
            ),
          ),
          if (website.isCustom) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.blueAccent, size: 20),
              tooltip: 'Edit Website',
              onPressed: widget.onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              tooltip: 'Hapus Website',
              onPressed: widget.onDelete,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
