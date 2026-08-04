/// Stable error codes surfaced by the SDK.
///
/// Codes are intended for logging, tests and host-level recovery flows. They do
/// not expose implementation details such as local server paths or JavaScript
/// selectors.
enum OmniManualsErrorCode {
  /// The SDK received an invalid or conflicting configuration.
  configInvalid('config.invalid'),

  /// SDK startup failed before the catalog/runtime became available.
  initializationFailed('initialization.failed'),

  /// A generated or configured registry could not be found.
  registryMissing('registry.missing'),

  /// A local asset required by the runtime or a manual is missing.
  assetMissing('asset.missing'),

  /// The configured catalog source failed.
  providerFailed('provider.failed'),

  /// A manual requires a runtime version newer than the bundled runtime.
  runtimeIncompatible('runtime.incompatible'),

  /// The web runtime could not be loaded from bundled assets.
  runtimeLoadFailed('runtime.loadFailed'),

  /// The private local runtime server could not start.
  serverStartFailed('server.startFailed'),

  /// The embedded WebView failed to load or execute a runtime action.
  webviewLoadFailed('webview.loadFailed'),

  /// A requested manual ID is not present in the catalog.
  manualNotFound('manual.notFound'),

  /// A requested language is unavailable or invalid.
  languageUnavailable('language.unavailable'),

  /// A remote distribution operation failed.
  distributionFailed('distribution.failed'),

  /// A package download, hash or ZIP extraction is invalid.
  packageInvalid('package.invalid'),

  /// A synchronization was explicitly cancelled by the host app.
  synchronizationCancelled('synchronization.cancelled');

  const OmniManualsErrorCode(this.code);

  /// Machine-readable code suitable for logs and tests.
  final String code;
}

/// Exception type thrown by the public Omni Manuals SDK.
///
/// The exception describes recoverable configuration, catalog and runtime
/// failures in terms meaningful to a Flutter host app. It intentionally avoids
/// exposing private file paths, server internals or WebView implementation
/// details unless they are provided as [cause].
final class OmniManualsException implements Exception {
  /// Creates an SDK exception with a stable [code] and human-readable [message].
  const OmniManualsException({
    required this.code,
    required this.message,
    this.context,
    this.cause,
    this.recoveryHint,
    this.fatal = false,
  });

  /// Stable error category.
  final OmniManualsErrorCode code;

  /// Human-readable summary intended for logs or fallback UI.
  final String message;

  /// Optional structured context such as a manual ID or language code.
  final Object? context;

  /// Original lower-level error, when available.
  final Object? cause;

  /// Optional guidance suitable for development diagnostics.
  final String? recoveryHint;

  /// Whether the SDK considers the failure unrecoverable for the current setup.
  final bool fatal;

  @override
  String toString() {
    final hint = recoveryHint == null ? '' : ' Hint: $recoveryHint';
    return 'OmniManualsException(${code.code}): $message$hint';
  }
}
