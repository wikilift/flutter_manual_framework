import 'package:flutter/foundation.dart';

@immutable
/// Public metadata for a manual available to the Flutter SDK.
///
/// This is intentionally not the full manual JSON. It contains only the
/// information Flutter needs to list, select and identify manuals while the web
/// runtime remains responsible for rendering manual content.
final class OmniManualInfo {
  /// Describes a manual entry that can be shown by [OmniLibrary] or opened by
  /// [OmniManualsPage].
  const OmniManualInfo({
    required this.id,
    required this.title,
    this.subtitle,
    this.version,
    this.minimumRuntimeVersion,
    this.languages = const <String>[],
    this.icon,
    this.poster,
  });

  /// Stable manual identifier used by the runtime asset bundle.
  final String id;

  /// Human-readable title shown by Flutter library surfaces.
  final String title;

  /// Optional short description shown in library cards.
  final String? subtitle;

  /// Optional package/manual version displayed as metadata.
  final String? version;

  /// Minimum runtime version declared by the manual package, when available.
  final String? minimumRuntimeVersion;

  /// Languages advertised by the manual package.
  final List<String> languages;

  /// Optional icon path or URL advertised by a distribution manifest.
  final String? icon;

  /// Optional poster path or URL advertised by a distribution manifest.
  final String? poster;
}

/// Deprecated compatibility name for [OmniManualInfo].
///
/// New code should use [OmniManualInfo]. The alias remains available so
/// generated registries and applications built against early SDK iterations do
/// not need an immediate source change.
@Deprecated('Use OmniManualInfo instead.')
typedef OmniManualDescriptor = OmniManualInfo;

/// Base class for entries shown by [OmniManualsLibrary].
///
/// Entries are generated from the consumer application's manual assets. The
/// web runtime does not fetch or parse collection metadata.
sealed class OmniLibraryEntry {
  /// Creates a library entry.
  const OmniLibraryEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.icon,
    this.image,
    this.badges = const <String>[],
    this.featured = false,
    this.metadata = const <String, Object?>{},
  });

  /// Stable entry identifier.
  final String id;

  /// Human-readable title shown by Flutter widgets.
  final String title;

  /// Optional short text shown below [title].
  final String? subtitle;

  /// Optional longer description supplied by a Library Catalog.
  final String? description;

  /// Optional Material icon name supplied by a Library Catalog.
  final String? icon;

  /// Optional image path supplied by a Library Catalog.
  final String? image;

  /// Human-readable badges resolved for the active language.
  final List<String> badges;

  /// Whether this entry should be visually highlighted by host widgets.
  final bool featured;

  /// Additional catalog metadata intentionally left uninterpreted by the SDK.
  final Map<String, Object?> metadata;
}

/// A manual entry in the Flutter library.
final class OmniManualLibraryEntry extends OmniLibraryEntry {
  /// Creates a manual entry.
  OmniManualLibraryEntry({
    required this.manual,
    String? title,
    String? subtitle,
    super.description,
    String? icon,
    String? image,
    super.badges,
    super.featured,
    super.metadata,
  }) : super(
         id: manual.id,
         title: title ?? manual.title,
         subtitle: subtitle ?? manual.subtitle,
         icon: icon ?? manual.icon,
         image: image ?? manual.poster,
       );

  /// Manual metadata opened by the runtime.
  final OmniManualInfo manual;
}

/// A recursive collection of manuals and subcollections.
final class OmniCollectionEntry extends OmniLibraryEntry {
  /// Creates a collection entry.
  const OmniCollectionEntry({
    required super.id,
    required super.title,
    super.subtitle,
    super.description,
    super.icon,
    super.image,
    super.badges,
    super.featured,
    super.metadata,
    required this.children,
  });

  /// Child manuals and collections in declared order.
  final List<OmniLibraryEntry> children;

  /// Returns all manuals below this collection.
  List<OmniManualInfo> get manualsRecursive {
    final manuals = <OmniManualInfo>[];

    for (final child in children) {
      switch (child) {
        case OmniManualLibraryEntry(:final manual):
          manuals.add(manual);
        case OmniCollectionEntry():
          manuals.addAll(child.manualsRecursive);
      }
    }

    return List<OmniManualInfo>.unmodifiable(manuals);
  }
}
