import 'package:flutter/services.dart';

import 'runtime_paths.dart';

final class RuntimeAssetBundleResolver {
  RuntimeAssetBundleResolver({
    this.assetRoot = packageRuntimeAssetRoot,
    AssetBundle? bundle,
  }) : bundle = bundle ?? rootBundle;

  final String assetRoot;
  final AssetBundle bundle;
  Set<String> _assetKeys = const {};

  Set<String> get assetKeys => _assetKeys;

  Future<void> loadManifest() async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    _assetKeys = manifest
        .listAssets()
        .where((asset) => asset.startsWith('$assetRoot/'))
        .toSet();
  }

  Future<ByteData?> load(String relativePath) async {
    final runtimePath = _runtimePath(relativePath);
    if (runtimePath == null) return null;
    final assetKey = '$assetRoot/$runtimePath';
    if (!_assetKeys.contains(assetKey)) return null;
    return bundle.load(assetKey);
  }
}

String? _runtimePath(String relativePath) {
  if (relativePath == 'index.html') return relativePath;
  if (relativePath.startsWith('src/') || relativePath.startsWith('styles/')) {
    return relativePath;
  }
  return null;
}
