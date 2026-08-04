import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../provider.dart';
import 'asset_bundle_resolver.dart';
import 'runtime_paths.dart';

final class OfflineRuntimeServer {
  OfflineRuntimeServer({RuntimeAssetBundleResolver? resolver, this.source})
    : _resolver = resolver ?? RuntimeAssetBundleResolver(),
      super();

  final RuntimeAssetBundleResolver _resolver;
  final OmniManualsSource? source;
  HttpServer? _server;

  Future<Uri> start() async {
    if (_server != null) return baseUri;
    await _resolver.loadManifest();
    debugPrint('[OmniManuals] loading package runtime: ${_resolver.assetRoot}');
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.idleTimeout = null;
    _server!.listen(_handle, onError: (_) {});
    return baseUri;
  }

  Uri get baseUri {
    final server = _server;
    if (server == null) throw StateError('OfflineRuntimeServer no iniciado');
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/',
    );
  }

  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    await server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
    final relative = safeRelativePath(request.uri.path);
    debugPrint('[OmniManuals] request ${request.method} /${relative ?? ""}');
    if (relative == null) {
      await _notFound(request, origin: 'not found');
      return;
    }
    final sourceBytes = relative.startsWith('manuals/')
        ? await _loadSourceAsset(relative)
        : null;
    final bundleData = sourceBytes == null && !relative.startsWith('manuals/')
        ? await _resolver.load(relative)
        : null;
    if (sourceBytes == null && bundleData == null) {
      await _notFound(
        request,
        origin: relative.startsWith('manuals/')
            ? 'consumer asset source'
            : 'package runtime',
      );
      return;
    }
    debugPrint(
      '[OmniManuals] resolved /$relative from '
      '${sourceBytes != null ? "consumer asset source" : "package runtime"}',
    );
    final bytes =
        sourceBytes ??
        Uint8List.view(
          bundleData!.buffer,
          bundleData.offsetInBytes,
          bundleData.lengthInBytes,
        );
    final range = parseRangeHeader(
      request.headers.value(HttpHeaders.rangeHeader),
      bytes.length,
    );
    request.response.headers
      ..set(HttpHeaders.contentTypeHeader, mimeType(relative))
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.cacheControlHeader, 'no-store');
    if (range == null) {
      request.response.contentLength = bytes.length;
      if (request.method == 'GET') request.response.add(bytes);
    } else {
      request.response.statusCode = HttpStatus.partialContent;
      request.response.contentLength = range.length;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${range.start}-${range.endInclusive}/${bytes.length}',
      );
      if (request.method == 'GET') request.response.add(range.slice(bytes));
    }
    await request.response.close();
  }

  Future<void> _notFound(HttpRequest request, {required String origin}) async {
    debugPrint('[OmniManuals] 404 ${request.uri.path} origin=$origin');
    request.response.statusCode = HttpStatus.notFound;
    request.response.headers.contentType = ContentType.text;
    request.response.write('Recurso no encontrado');
    await request.response.close();
  }

  Future<Uint8List?> _loadSourceAsset(String relative) async {
    final currentSource = source;
    if (currentSource == null) return null;
    try {
      return await currentSource.loadAsset(relative);
    } catch (_) {
      return null;
    }
  }
}
