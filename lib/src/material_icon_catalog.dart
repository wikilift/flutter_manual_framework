/// Material icon names supported by Omni Manuals library catalogs.
///
/// This file intentionally has no Flutter imports. The registry generator is a
/// Dart CLI and must remain isolated from Flutter-only libraries.
abstract final class OmniMaterialIconCatalog {
  /// Legacy admin icon IDs mapped to their canonical Material icon name.
  static const Map<String, String> legacyAliases = <String, String>{
    '__default__': 'folder',
    'Folder': 'folder',
    'folder-special': 'folder_open',
    'controllers': 'memory',
    'configuration': 'settings',
    'manuals': 'menu_book',
    'tools': 'build',
    'videos': 'video_library',
  };

  /// Supported Material icon names.
  static const Set<String> names = <String>{
    'add',
    'article',
    'bluetooth',
    'book',
    'bug_report',
    'build',
    'cancel',
    'check_circle',
    'cloud',
    'computer',
    'construction',
    'create_new_folder',
    'delete',
    'description',
    'device_hub',
    'devices',
    'dns',
    'download',
    'edit',
    'engineering',
    'error',
    'extension',
    'favorite',
    'folder',
    'folder_open',
    'home',
    'image',
    'image_search',
    'info',
    'lan',
    'lock',
    'lock_open',
    'memory',
    'menu_book',
    'movie',
    'photo',
    'play_circle',
    'router',
    'save',
    'school',
    'search',
    'security',
    'settings',
    'star',
    'storage',
    'terminal',
    'upload',
    'usb',
    'video_library',
    'warning',
    'warning_amber',
    'wifi',
  };

  /// Returns the canonical Material name for [name], including legacy aliases.
  static String? normalize(String? name) {
    final value = name?.trim();
    if (value == null || value.isEmpty) return null;
    return legacyAliases[value] ?? (names.contains(value) ? value : null);
  }
}
