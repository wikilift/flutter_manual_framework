import 'package:flutter/material.dart';

import 'material_icon_catalog.dart';

/// Material icon names supported by Omni Manuals library catalogs.
///
/// The catalog stores only the Material icon name, never code points, indexes,
/// SVG or host-specific objects. Keep this file synchronized with
/// `tool/material_icons.json`.
abstract final class OmniMaterialIcons {
  /// Legacy admin icon IDs mapped to their canonical Material icon name.
  static const Map<String, String> legacyAliases =
      OmniMaterialIconCatalog.legacyAliases;

  /// Supported Material icon names.
  static const Set<String> names = OmniMaterialIconCatalog.names;

  /// Resolves a stored icon name to [IconData].
  ///
  /// Legacy aliases are accepted here only to keep old cached/generated catalogs
  /// readable. New catalogs should store the canonical Material name.
  static IconData? iconData(String? name) {
    final normalized = normalize(name);
    if (normalized == null) return null;
    return _data[normalized];
  }

  /// Returns the canonical Material name for [name], including legacy aliases.
  static String? normalize(String? name) =>
      OmniMaterialIconCatalog.normalize(name);

  static const Map<String, IconData> _data = <String, IconData>{
    'add': Icons.add,
    'article': Icons.article,
    'bluetooth': Icons.bluetooth,
    'book': Icons.book,
    'bug_report': Icons.bug_report,
    'build': Icons.build,
    'cancel': Icons.cancel,
    'check_circle': Icons.check_circle,
    'cloud': Icons.cloud,
    'computer': Icons.computer,
    'construction': Icons.construction,
    'create_new_folder': Icons.create_new_folder,
    'delete': Icons.delete,
    'description': Icons.description,
    'device_hub': Icons.device_hub,
    'devices': Icons.devices,
    'dns': Icons.dns,
    'download': Icons.download,
    'edit': Icons.edit,
    'engineering': Icons.engineering,
    'error': Icons.error,
    'extension': Icons.extension,
    'favorite': Icons.favorite,
    'folder': Icons.folder,
    'folder_open': Icons.folder_open,
    'home': Icons.home,
    'image': Icons.image,
    'image_search': Icons.image_search,
    'info': Icons.info,
    'lan': Icons.lan,
    'lock': Icons.lock,
    'lock_open': Icons.lock_open,
    'memory': Icons.memory,
    'menu_book': Icons.menu_book,
    'movie': Icons.movie,
    'photo': Icons.photo,
    'play_circle': Icons.play_circle,
    'router': Icons.router,
    'save': Icons.save,
    'school': Icons.school,
    'search': Icons.search,
    'security': Icons.security,
    'settings': Icons.settings,
    'star': Icons.star,
    'storage': Icons.storage,
    'terminal': Icons.terminal,
    'upload': Icons.upload,
    'usb': Icons.usb,
    'video_library': Icons.video_library,
    'warning': Icons.warning,
    'warning_amber': Icons.warning_amber,
    'wifi': Icons.wifi,
  };
}
