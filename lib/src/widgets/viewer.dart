import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../errors.dart';
import '../internal/runtime_bridge.dart';
import '../internal/sdk_controller.dart';
import '../models.dart';
import 'customization.dart';

class OmniManualViewerPage extends StatefulWidget {
  const OmniManualViewerPage({
    super.key,
    required this.manual,
    this.language,
    this.strings = const OmniManualsStrings(),
    this.theme = const OmniManualsThemeData(),
    this.builders = const OmniManualsBuilders(),
    this.options = const OmniManualViewerOptions(),
    this.loadingBuilder,
    this.errorBuilder,
  });

  final OmniManualInfo manual;
  final String? language;
  final OmniManualsStrings strings;
  final OmniManualsThemeData theme;
  final OmniManualsBuilders builders;
  final OmniManualViewerOptions options;

  @Deprecated('Use builders.loadingBuilder instead.')
  final OmniManualsLoadingBuilder? loadingBuilder;

  @Deprecated('Use builders.errorBuilder instead.')
  final OmniManualsErrorBuilder? errorBuilder;

  @override
  State<OmniManualViewerPage> createState() => _OmniManualViewerPageState();
}

enum _ViewerState { initializing, loading, ready, error, closing, disposed }

class _OmniManualViewerPageState extends State<OmniManualViewerPage> {
  RuntimeBridge? _bridge;
  _ViewerState _state = _ViewerState.initializing;
  OmniManualsException? _error;
  Future<void>? _activeAction;

  OmniManualsLoadingBuilder? get _loadingBuilder =>
      widget.loadingBuilder ?? widget.builders.loadingBuilder;

  OmniManualsErrorBuilder? get _errorBuilder =>
      widget.errorBuilder ?? widget.builders.errorBuilder;

  bool get _ready =>
      _state == _ViewerState.ready && _bridge != null && _activeAction == null;

  @override
  void initState() {
    super.initState();
    _state = _ViewerState.loading;
  }

  @override
  void dispose() {
    _bridge?.markClosing();
    _state = _ViewerState.disposed;
    super.dispose();
  }

  Future<bool> _close() async {
    if (_state == _ViewerState.closing || _state == _ViewerState.disposed) {
      return false;
    }
    setState(() {
      _state = _ViewerState.closing;
      _bridge?.markClosing();
    });
    return true;
  }

  Future<void> _runBridgeAction(
    Future<RuntimeBridgeActionResult> Function(RuntimeBridge bridge) action,
  ) async {
    final bridge = _bridge;
    if (!_ready || bridge == null) return;

    late final Future<void> pending;

    pending = () async {
      try {
        await action(bridge);
      } catch (error) {
        if (!mounted ||
            _state == _ViewerState.closing ||
            _state == _ViewerState.disposed) {
          return;
        }

        final exception = _exception(error, widget.strings);

        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(exception.message)));
      } finally {
        if (mounted &&
            _state != _ViewerState.closing &&
            _state != _ViewerState.disposed &&
            identical(_activeAction, pending)) {
          setState(() => _activeAction = null);
        }
      }
    }();

    setState(() => _activeAction = pending);
    await pending;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    final scaffold = Scaffold(
      appBar: widget.options.showAppBar
          ? AppBar(
              title: Text(widget.manual.title),
              centerTitle: widget.options.centerTitle,
              automaticallyImplyLeading:
                  widget.options.automaticallyImplyLeading,
              actions: [
                if (widget.options.showSearch)
                  IconButton(
                    tooltip: widget.strings.searchTooltip,
                    icon: Icon(widget.theme.searchIcon ?? Icons.search),
                    onPressed: ready
                        ? () => unawaited(
                            _runBridgeAction((bridge) => bridge.openSearch()),
                          )
                        : null,
                  ),
                if (widget.options.showTableOfContents)
                  IconButton(
                    tooltip: widget.strings.tableOfContentsTooltip,
                    icon: Icon(
                      widget.theme.tableOfContentsIcon ??
                          Icons.format_list_bulleted,
                    ),
                    onPressed: ready
                        ? () => unawaited(
                            _runBridgeAction(
                              (bridge) => bridge.openTableOfContents(),
                            ),
                          )
                        : null,
                  ),
                if (widget.options.showLanguageSelector)
                  _LanguageMenu(
                    languages: widget.manual.languages,
                    selectedLanguage: widget.language,
                    strings: widget.strings,
                    theme: widget.theme,
                    onSelected: ready
                        ? (language) => unawaited(
                            _runBridgeAction(
                              (bridge) => bridge.setLocale(language),
                            ),
                          )
                        : null,
                  ),
              ],
            )
          : null,
      body: Stack(
        children: [
          OmniManual._embedded(
            id: widget.manual.id,
            language: widget.language,
            strings: widget.strings,
            theme: widget.theme,
            loadingBuilder: _loadingBuilder,
            onBridgeStateChanged: _handleBridgeState,
            onBridgeReady: (bridge) {
              if (!mounted ||
                  _state == _ViewerState.closing ||
                  _state == _ViewerState.disposed) {
                return;
              }
              setState(() {
                _bridge = bridge;
                _state = _ViewerState.ready;
                _error = null;
              });
            },
            onBridgeError: (error) {
              if (!mounted ||
                  _state == _ViewerState.closing ||
                  _state == _ViewerState.disposed) {
                return;
              }
              setState(() {
                _state = _ViewerState.error;
                _error = error;
              });
            },
          ),
          if (_state != _ViewerState.ready)
            Positioned.fill(child: _viewerOverlay(context)),
        ],
      ),
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_close());
      },
      child: scaffold,
    );
  }

  void _handleBridgeState(RuntimeBridgeState state) {
    if (!mounted ||
        _state == _ViewerState.closing ||
        _state == _ViewerState.disposed) {
      return;
    }
    if (state == RuntimeBridgeState.failed) {
      setState(() {
        _state = _ViewerState.error;
        _error = OmniManualsException(
          code: OmniManualsErrorCode.webviewLoadFailed,
          message: widget.strings.runtimeLoadError,
        );
      });
      return;
    }
    if (state == RuntimeBridgeState.loading && _state != _ViewerState.loading) {
      setState(() => _state = _ViewerState.loading);
    }
  }

  Widget _viewerOverlay(BuildContext context) {
    final overlayColor =
        widget.theme.viewerOverlayColor ??
        Theme.of(context).colorScheme.surface;

    if (_state == _ViewerState.error && _error != null) {
      return ColoredBox(
        color: overlayColor,
        child:
            _errorBuilder?.call(context, _error!) ??
            Center(
              child: Text(
                _error!.message,
                textAlign: TextAlign.center,
                style: widget.theme.emptyTextStyle,
              ),
            ),
      );
    }

    return ColoredBox(
      color: overlayColor,
      child:
          _loadingBuilder?.call(context) ??
          DefaultOmniManualsLoadingState(
            strings: widget.strings,
            theme: widget.theme,
          ),
    );
  }
}

class OmniManual extends StatefulWidget {
  const OmniManual({
    super.key,
    required this.id,
    this.language,
    this.initialSectionId,
    this.errorBuilder,
    this.loadingBuilder,
    this.onRouteChanged,
    this.strings = const OmniManualsStrings(),
    this.theme = const OmniManualsThemeData(),
  }) : _embedded = false,
       onBridgeReady = null,
       onBridgeStateChanged = null,
       onBridgeError = null;

  const OmniManual._embedded({
    required this.id,
    this.language,
    required this.onBridgeReady,
    required this.onBridgeStateChanged,
    required this.onBridgeError,
    required this.strings,
    required this.theme,
    this.loadingBuilder,
  }) : _embedded = true,
       initialSectionId = null,
       errorBuilder = null,
       onRouteChanged = null,
       super();

  final String id;
  final String? language;
  final bool _embedded;
  final String? initialSectionId;
  final OmniManualsErrorBuilder? errorBuilder;
  final OmniManualsLoadingBuilder? loadingBuilder;
  final ValueChanged<Uri>? onRouteChanged;
  final ValueChanged<RuntimeBridge>? onBridgeReady;
  final ValueChanged<RuntimeBridgeState>? onBridgeStateChanged;
  final ValueChanged<OmniManualsException>? onBridgeError;
  final OmniManualsStrings strings;
  final OmniManualsThemeData theme;

  @override
  State<OmniManual> createState() => _OmniManualState();
}

class _OmniManualState extends State<OmniManual> {
  late final Future<WebViewController> _controller = _createController();
  RuntimeBridge? _bridge;
  WebViewController? _controllerInstance;
  bool _reportedReady = false;
  bool _closing = false;

  Future<WebViewController> _createController() async {
    try {
      final uri = await omniManualsController.manualUri(
        id: widget.id,
        language: widget.language,
        embedded: widget._embedded,
      );
      if (!mounted || _closing) {
        throw StateError(
          'OmniManual disposed before WebView creation completed',
        );
      }

      final target = widget.initialSectionId == null
          ? uri
          : uri.replace(fragment: widget.initialSectionId);

      widget.onRouteChanged?.call(target);

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.theme.webViewBackgroundColor);

      _controllerInstance = controller;
      final bridge = RuntimeBridge(controller);
      _bridge = bridge;

      widget.onBridgeStateChanged?.call(RuntimeBridgeState.loading);

      controller
        ..addJavaScriptChannel(
          'OmniManualBridge',
          onMessageReceived: (message) {
            if (!mounted || _closing || bridge.isDisposed) {
              return;
            }

            final state = bridge.handleMessage(message.message);
            if (state == null) return;

            widget.onBridgeStateChanged?.call(state);

            if (state == RuntimeBridgeState.ready && !_reportedReady) {
              _reportedReady = true;
              widget.onBridgeReady?.call(bridge);
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              if (!mounted || _closing) return;
              widget.onBridgeError?.call(
                OmniManualsException(
                  code: OmniManualsErrorCode.webviewLoadFailed,
                  message: widget.strings.webViewLoadError,
                  context: error.description,
                ),
              );
            },
          ),
        )
        ..loadRequest(target);

      return controller;
    } catch (error) {
      final exception = _exception(error, widget.strings);
      widget.onBridgeError?.call(exception);
      throw exception;
    }
  }

  @override
  void dispose() {
    _closing = true;
    final controller = _controllerInstance;
    if (controller != null) {
      unawaited(
        controller.removeJavaScriptChannel('OmniManualBridge').catchError((
          Object error,
        ) {
          debugPrint(
            '[OmniManuals] ignored WebView cleanup error after dispose: $error',
          );
        }),
      );
    }
    _bridge?.markClosing();
    _bridge?.dispose();
    _bridge = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: _controller,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ??
              DefaultOmniManualsLoadingState(
                strings: widget.strings,
                theme: widget.theme,
              );
        }
        if (snapshot.hasError) {
          final error = _exception(snapshot.error, widget.strings);
          return widget.errorBuilder?.call(context, error) ??
              Center(
                child: Text(
                  error.message,
                  textAlign: TextAlign.center,
                  style: widget.theme.emptyTextStyle,
                ),
              );
        }
        return WebViewWidget(controller: snapshot.requireData);
      },
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.languages,
    required this.selectedLanguage,
    required this.onSelected,
    required this.strings,
    required this.theme,
  });

  final List<String> languages;
  final String? selectedLanguage;
  final ValueChanged<String>? onSelected;
  final OmniManualsStrings strings;
  final OmniManualsThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (languages.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: strings.languageTooltip,
      icon: Icon(theme.languageIcon ?? Icons.translate),
      initialValue: selectedLanguage,
      enabled: onSelected != null,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final language in languages)
          PopupMenuItem<String>(
            value: language,
            child: Text(language.toUpperCase()),
          ),
      ],
    );
  }
}

/// Default loading state used by all SDK widgets.
class DefaultOmniManualsLoadingState extends StatelessWidget {
  const DefaultOmniManualsLoadingState({
    super.key,
    this.strings = const OmniManualsStrings(),
    this.theme = const OmniManualsThemeData(),
  });

  final OmniManualsStrings strings;
  final OmniManualsThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: strings.loadingSemanticsLabel,
      liveRegion: true,
      child: Center(
        child: CircularProgressIndicator(color: theme.progressIndicatorColor),
      ),
    );
  }
}

OmniManualsException _exception(Object? error, OmniManualsStrings strings) {
  if (error is OmniManualsException) return error;
  return OmniManualsException(
    code: OmniManualsErrorCode.initializationFailed,
    message: strings.genericLoadError,
    cause: error,
  );
}
