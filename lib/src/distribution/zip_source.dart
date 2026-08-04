import 'dart:io';

import '../models.dart';
import '../provider.dart';
import 'manifest.dart';

/// Local ZIP distribution source backed by a manifest file and package files.
///
/// This is useful for side-loaded updates, MDM deployments, NAS-mounted folders
/// or tests. Package `downloadUrl` values may be absolute `file://` URLs or
/// paths relative to [packageRoot].
final class ZipSource extends OmniManualsDistributionSource {
  const ZipSource({required this.manifestFile, this.packageRoot});

  final File manifestFile;
  final Directory? packageRoot;

  @override
  Future<List<OmniManualInfo>> loadManuals() async => const <OmniManualInfo>[];

  @override
  Future<OmniDistributionManifest> fetchManifest() async =>
      OmniDistributionManifest.parse(await manifestFile.readAsString());

  @override
  Future<Stream<List<int>>> openPackage(OmniDistributionPackage package) async {
    final file = _resolvePackageFile(package.downloadUrl);
    if (!await file.exists()) {
      throw FileSystemException('No existe el paquete ZIP.', file.path);
    }
    return file.openRead();
  }

  File _resolvePackageFile(Uri uri) {
    if (uri.hasScheme && uri.scheme == 'file') return File.fromUri(uri);
    if (uri.hasScheme) {
      throw ArgumentError.value(
        uri,
        'downloadUrl',
        'ZipSource solo acepta rutas locales o file://.',
      );
    }
    final root = packageRoot ?? manifestFile.parent;
    if (uri.hasQuery || uri.hasFragment) {
      throw ArgumentError.value(uri, 'downloadUrl', 'Ruta ZIP insegura.');
    }
    final parts = uri.pathSegments;
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw ArgumentError.value(uri, 'downloadUrl', 'Ruta ZIP insegura.');
    }
    return File('${root.path}/${parts.join('/')}');
  }
}
