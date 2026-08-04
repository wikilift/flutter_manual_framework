/// Lifecycle state of the SDK singleton.
///
/// Most applications only need to call `OmniManuals.initialize` and render
/// `OmniManualsPage`. The state is public for diagnostics, tests and advanced
/// integrations that need to coordinate setup explicitly.
enum OmniManualsState {
  /// The SDK has not been initialized in this process.
  uninitialized,

  /// Initialization is currently running.
  initializing,

  /// The catalog and private runtime infrastructure are ready.
  ready,

  /// Initialization failed.
  failed,

  /// Resources are being released.
  disposing,

  /// Resources have been released and the SDK may be initialized again.
  disposed,
}
