import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models.dart';
import '../provider.dart';
import 'manifest.dart';

typedef OmniAuthTokenProvider = FutureOr<String?> Function();

final Map<String, _MetadataValidator> _metadataValidators =
    <String, _MetadataValidator>{};

/// Backend-neutral HTTP source using only `manifest.json` and ZIP files.
base class HttpSource extends OmniManualsDistributionSource {
  const HttpSource({
    required this.endpoint,
    this.manifestPath = 'manifest.json',
    this.tokenProvider,
    this.headers = const <String, String>{},
    this.timeout = const Duration(seconds: 20),
    this.maxMetadataBytes = 1024 * 1024,
    this.retries = 1,
  }) : assert(maxMetadataBytes > 0),
       assert(retries >= 0);

  final Uri endpoint;
  final String manifestPath;
  final OmniAuthTokenProvider? tokenProvider;
  final Map<String, String> headers;
  final Duration timeout;
  final int maxMetadataBytes;
  final int retries;

  @override
  Future<List<OmniManualInfo>> loadManuals() async => const <OmniManualInfo>[];

  @override
  Future<OmniDistributionManifest> fetchManifest() => _withRetry(() async {
    final uri = _resolve(manifestPath);
    final body = await _getMetadata(uri, 'manifest HTTP');
    return OmniDistributionManifest.parse(body);
  });

  @override
  Future<Stream<List<int>>> openPackage(OmniDistributionPackage package) async {
    final client = HttpClient();
    try {
      final uri = _resolve(package.downloadUrl.toString());
      final request = await _openGet(client, uri);
      final response = await request.close();
      _rejectUnsafeRedirect(uri, response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close();
        throw HttpException(
          'No se pudo descargar paquete HTTP: ${response.statusCode}',
          uri: uri,
        );
      }
      _validatePackageLength(package, response, uri);
      return response
          .timeout(timeout)
          .transform(
            StreamTransformer<List<int>, List<int>>.fromHandlers(
              handleData: (data, sink) => sink.add(data),
              handleError: (error, stackTrace, sink) {
                client.close(force: true);
                sink.addError(error, stackTrace);
              },
              handleDone: (sink) {
                client.close();
                sink.close();
              },
            ),
          );
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  Future<String> _getMetadata(Uri uri, String label) async {
    final key = _metadataKey(uri);
    final client = HttpClient();
    try {
      final request = await _openGet(client, uri, metadataKey: key);
      final response = await request.close();
      _rejectUnsafeRedirect(uri, response);
      if (response.statusCode == HttpStatus.notModified) {
        final cached = _metadataValidators[key];
        if (cached == null) {
          throw HttpException(
            '$label respondió 304 sin metadatos previos.',
            uri: uri,
          );
        }
        return cached.body;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'No se pudo descargar $label: ${response.statusCode}',
          uri: uri,
        );
      }
      final contentLength = response.contentLength;
      if (contentLength > maxMetadataBytes) {
        throw HttpException(
          'Respuesta HTTP demasiado grande para metadatos Omni Manuals',
          uri: uri,
        );
      }
      final body = await _readResponseUtf8(response, uri);
      _storeMetadataValidator(key, response, body);
      return body;
    } finally {
      client.close();
    }
  }

  Future<HttpClientRequest> _openGet(
    HttpClient client,
    Uri uri, {
    String? metadataKey,
  }) async {
    client.connectionTimeout = timeout;
    final request = await client.getUrl(uri).timeout(timeout);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    final validator = metadataKey == null
        ? null
        : _metadataValidators[metadataKey];
    final etag = validator?.etag;
    if (etag != null && etag.isNotEmpty) {
      request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
    }
    final lastModified = validator?.lastModified;
    if (lastModified != null) {
      request.headers.ifModifiedSince = lastModified;
    }
    final tokenResult = tokenProvider?.call();
    final token = tokenResult == null
        ? null
        : await Future<String?>.value(tokenResult).timeout(timeout);
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    return request;
  }

  Future<String> _readResponseUtf8(HttpClientResponse response, Uri uri) async {
    final builder = BytesBuilder(copy: false);
    var totalBytes = 0;
    await for (final chunk in response.timeout(timeout)) {
      totalBytes += chunk.length;
      if (totalBytes > maxMetadataBytes) {
        throw HttpException(
          'Respuesta HTTP demasiado grande para metadatos Omni Manuals',
          uri: uri,
        );
      }
      builder.add(chunk);
    }
    return utf8.decode(builder.takeBytes());
  }

  void _validatePackageLength(
    OmniDistributionPackage package,
    HttpClientResponse response,
    Uri uri,
  ) {
    final contentLength = response.contentLength;
    if (contentLength < 0 || contentLength == package.compressedSize) return;
    throw HttpException(
      'Content-Length inesperado para paquete ${package.id}: '
      '$contentLength != ${package.compressedSize}',
      uri: uri,
    );
  }

  void _rejectUnsafeRedirect(Uri originalUri, HttpClientResponse response) {
    if (originalUri.scheme != 'https') return;
    for (final redirect in response.redirects) {
      if (redirect.location.scheme == 'http') {
        throw HttpException(
          'Redirección insegura HTTPS -> HTTP rechazada.',
          uri: redirect.location,
        );
      }
    }
  }

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt <= retries; attempt += 1) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt == retries || !_isRetryable(error)) rethrow;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  bool _isRetryable(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is HttpException;

  String _metadataKey(Uri uri) => uri.normalizePath().toString();

  void _storeMetadataValidator(
    String key,
    HttpClientResponse response,
    String body,
  ) {
    final etag = response.headers.value(HttpHeaders.etagHeader);
    final lastModifiedValue = response.headers.value(
      HttpHeaders.lastModifiedHeader,
    );
    DateTime? lastModified;
    if (lastModifiedValue != null && lastModifiedValue.isNotEmpty) {
      try {
        lastModified = HttpDate.parse(lastModifiedValue);
      } catch (_) {
        lastModified = null;
      }
    }
    if ((etag == null || etag.isEmpty) && lastModified == null) return;
    _metadataValidators[key] = _MetadataValidator(
      body: body,
      etag: etag,
      lastModified: lastModified,
    );
  }

  Uri _resolve(String pathOrUrl) {
    final uri = Uri.parse(pathOrUrl);
    if (uri.hasScheme) return uri;
    final base = endpoint.path.endsWith('/')
        ? endpoint
        : endpoint.replace(path: '${endpoint.path}/');
    return base.resolveUri(uri);
  }
}

final class _MetadataValidator {
  const _MetadataValidator({required this.body, this.etag, this.lastModified});

  final String body;
  final String? etag;
  final DateTime? lastModified;
}

/// Firebase Storage source prepared without importing Firebase SDKs.
///
/// Authentication, App Check and signed URL creation must live in the host app.
/// The SDK receives only a resolved endpoint and optional bearer token.
final class FirebaseSource extends HttpSource {
  const FirebaseSource({
    required super.endpoint,
    super.manifestPath,
    super.tokenProvider,
    super.headers,
    super.timeout,
    super.maxMetadataBytes,
    super.retries,
  });
}

/// Azure Blob source prepared without importing Azure/MSAL SDKs.
final class AzureBlobSource extends HttpSource {
  const AzureBlobSource({
    required super.endpoint,
    super.manifestPath,
    super.tokenProvider,
    super.headers,
    super.timeout,
    super.maxMetadataBytes,
    super.retries,
  });
}

/// SharePoint/OneDrive source prepared without importing Microsoft auth SDKs.
final class SharePointSource extends HttpSource {
  const SharePointSource({
    required super.endpoint,
    super.manifestPath,
    super.tokenProvider,
    super.headers,
    super.timeout,
    super.maxMetadataBytes,
    super.retries,
  });
}
