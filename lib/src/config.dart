import 'errors.dart';
import 'distribution/progress.dart';
import 'library_catalog.dart';
import 'provider.dart';

/// Receives optional diagnostic messages emitted by the SDK.
///
/// The callback is intended for host application logging. It is not required for
/// normal rendering and does not expose runtime internals.
typedef OmniManualsLogSink =
    void Function(OmniManualsErrorCode code, String message, [Object? context]);

/// Deprecated compatibility name for [OmniManualsLogSink].
@Deprecated('Use OmniManualsLogSink instead.')
typedef OmniManualsLogger = OmniManualsLogSink;

/// Configuration used to initialize the Omni Manuals Flutter SDK.
///
/// This is the single public setup point for the SDK. It selects the preferred
/// language and catalog source while keeping the embedded runtime server,
/// WebView bridge and asset resolution private.
final class OmniManualsConfig {
  /// Creates SDK configuration.
  ///
  /// Prefer [source] and [logSink] in new code. [provider] and [logger] are kept
  /// as compatibility aliases for early SDK consumers.
  const OmniManualsConfig({
    this.defaultLanguage,
    OmniManualsSource? source,
    @Deprecated('Use source instead.') OmniManualsSource? provider,
    OmniManualsLogSink? logSink,
    @Deprecated('Use logSink instead.') OmniManualsLogSink? logger,
    this.catalogSource,
    this.userGroups = const <String>{'default'},
    this.publicApiBaseUrl,
    this.onSyncProgress,
    this.debug = false,
  }) : source = source ?? provider,
       logSink = logSink ?? logger;

  /// Preferred language requested when opening manuals, for example `es`.
  ///
  /// The runtime still applies its own fallback chain from the manual package.
  final String? defaultLanguage;

  /// Catalog source used to populate library widgets and validate manual IDs.
  final OmniManualsSource? source;

  /// Optional Library Catalog source used only to organize the Flutter library.
  ///
  /// This is intentionally independent from [source]. The registry answers
  /// which manuals physically exist; the Library Catalog answers how the host
  /// should organize and present them.
  final OmniLibraryCatalogSource? catalogSource;

  /// Arbitrary visibility groups applied to Library Catalog entries.
  final Set<String> userGroups;

  /// Public base URL for optional runtime-backed media endpoints.
  ///
  /// The SDK never stores authentication material in manuals. When this is set,
  /// the embedded runtime can resolve declarative API video endpoints through
  /// the host API, for example `/api/v1/videos/stream?name=demo.mp4`.
  final Uri? publicApiBaseUrl;

  /// Optional progress sink for explicit remote synchronization operations.
  ///
  /// Initialization and local loading never start synchronization. This callback
  /// is invoked only when the host calls update/check/install APIs explicitly.
  final OmniSyncProgressSink? onSyncProgress;

  /// Deprecated compatibility getter for [source].
  @Deprecated('Use source instead.')
  OmniManualsSource? get provider => source;

  /// Optional diagnostic sink for host application logs.
  final OmniManualsLogSink? logSink;

  /// Deprecated compatibility getter for [logSink].
  @Deprecated('Use logSink instead.')
  OmniManualsLogSink? get logger => logSink;

  /// Enables additional diagnostics intended for development builds.
  final bool debug;
}
