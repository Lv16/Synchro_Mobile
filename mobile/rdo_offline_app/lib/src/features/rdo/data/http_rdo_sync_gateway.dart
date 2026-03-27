import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../application/rdo_sync_gateway.dart';
import '../domain/entities/pending_sync_item.dart';

const String _metaEntityAliasKey = '__entity_alias';
const String _metaDependsOnKey = '__depends_on';
const String _localRefPrefix = '@local:';
const String _serverRefPrefix = '@ref:';

class HttpRdoSyncGateway implements RdoSyncGateway, BatchRdoSyncGateway {
  HttpRdoSyncGateway({
    required this.syncUrl,
    this.batchSyncUrl,
    this.photoUploadUrl,
    http.Client? client,
    this.staticHeaders = const <String, String>{},
    this.authTokenProvider,
  }) : _client = client ?? http.Client();

  final Uri syncUrl;
  final Uri? batchSyncUrl;
  final Uri? photoUploadUrl;
  final http.Client _client;
  final Map<String, String> staticHeaders;
  final FutureOr<String?> Function()? authTokenProvider;

  @override
  Future<SyncExecutionResult> syncItem(PendingSyncItem item) async {
    final op = item.operation.toLowerCase();
    if (_isPhotoOperation(op)) {
      final cleanPayload = _removePayloadMetadata(item.payload);
      return _uploadPhoto(item.copyWith(payload: cleanPayload));
    }

    final body = <String, dynamic>{
      'client_uuid': item.clientUuid,
      'operation': item.operation,
      'payload': _jsonSafeMap(_removePayloadMetadata(item.payload)),
    };

    late final http.Response response;
    try {
      response = await _client.post(
        syncUrl,
        headers: await _jsonHeaders(),
        body: jsonEncode(_jsonSafeValue(body)),
      );
    } on SocketException {
      return const SyncExecutionResult(
        success: false,
        errorMessage: 'Sem conexão para sincronizar este item.',
      );
    } on HttpException {
      return const SyncExecutionResult(
        success: false,
        errorMessage: 'Falha de rede durante a sincronização.',
      );
    } catch (err) {
      return SyncExecutionResult(
        success: false,
        errorMessage: 'Falha ao preparar envio do item: $err',
      );
    }

    final status = response.statusCode;
    final responseBody = _decodeJsonMap(response.body);

    if (status == 409) {
      return SyncExecutionResult(
        success: false,
        conflict: true,
        errorMessage:
            (responseBody['error_message'] ?? responseBody['error'])
                ?.toString() ??
            'Conflito de sincronização detectado.',
      );
    }

    final serverSuccess = responseBody['success'];
    final bool ok =
        status >= 200 &&
        status < 300 &&
        (serverSuccess is! bool || serverSuccess);
    if (ok) {
      return const SyncExecutionResult(success: true);
    }

    return SyncExecutionResult(
      success: false,
      errorMessage: _extractErrorMessageByStatus(
        status,
        responseBody,
        fallback: 'Falha no envio para API mobile.',
      ),
    );
  }

  @override
  Future<List<BatchSyncExecutionResult>> syncItems(
    List<PendingSyncItem> items,
  ) async {
    if (items.isEmpty) {
      return const <BatchSyncExecutionResult>[];
    }

    final prepared = items.map(_prepareBatchItem).toList(growable: false);
    final nonPhoto = prepared
        .where((item) => !item.isPhoto)
        .toList(growable: false);
    final photo = prepared
        .where((item) => item.isPhoto)
        .toList(growable: false);

    final resultsByUuid = <String, BatchSyncExecutionResult>{};
    final aliasToServerId = <String, int>{};

    if (nonPhoto.isNotEmpty) {
      await _syncNonPhotoBatch(nonPhoto, resultsByUuid, aliasToServerId);
    }

    if (photo.isNotEmpty) {
      for (final item in photo) {
        final resolvedPayload = _resolvePayloadRefsWithIdMap(
          item.cleanedPayload,
          aliasToServerId,
        );

        if (_containsUnresolvedLocalOrServerRef(resolvedPayload)) {
          resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
            clientUuid: item.clientUuid,
            success: false,
            conflict: true,
            blocked: true,
            errorMessage:
                'Referência local não resolvida para upload de foto (${item.operation}).',
          );
          continue;
        }

        final singleResult = await syncItem(
          item.source.copyWith(payload: resolvedPayload),
        );
        resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
          clientUuid: item.clientUuid,
          success: singleResult.success,
          conflict: singleResult.conflict,
          blocked: false,
          errorMessage: singleResult.errorMessage,
        );
      }
    }

    final orderedResults = <BatchSyncExecutionResult>[];
    for (final original in items) {
      orderedResults.add(
        resultsByUuid[original.clientUuid] ??
            BatchSyncExecutionResult(
              clientUuid: original.clientUuid,
              success: false,
              errorMessage: 'Item não retornado no processamento de lote.',
            ),
      );
    }

    return orderedResults;
  }

  Future<void> _syncNonPhotoBatch(
    List<_PreparedBatchItem> items,
    Map<String, BatchSyncExecutionResult> resultsByUuid,
    Map<String, int> aliasToServerId,
  ) async {
    final ordered = _topologicalOrder(items);
    final requestBody = <String, dynamic>{
      'stop_on_error': false,
      'items': ordered.map((item) => item.toBatchMap()).toList(growable: false),
    };

    late final String encodedBody;
    try {
      encodedBody = jsonEncode(_jsonSafeValue(requestBody));
    } catch (err) {
      final message = 'Payload local inválido para sincronização em lote: $err';
      for (final item in ordered) {
        resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
          clientUuid: item.clientUuid,
          success: false,
          errorMessage: message,
        );
      }
      return;
    }

    late final http.Response response;
    try {
      response = await _client.post(
        _resolveBatchSyncUrl(),
        headers: await _jsonHeaders(),
        body: encodedBody,
      );
    } on SocketException {
      for (final item in ordered) {
        resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
          clientUuid: item.clientUuid,
          success: false,
          errorMessage: 'Sem conexão para sincronizar lote.',
        );
      }
      return;
    } on HttpException {
      for (final item in ordered) {
        resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
          clientUuid: item.clientUuid,
          success: false,
          errorMessage: 'Falha de rede durante sincronização em lote.',
        );
      }
      return;
    } catch (err) {
      for (final item in ordered) {
        resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
          clientUuid: item.clientUuid,
          success: false,
          errorMessage: 'Falha de rede no envio em lote: $err',
        );
      }
      return;
    }

    final parsedBody = _decodeJsonMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractErrorMessageByStatus(
        response.statusCode,
        parsedBody,
        fallback: 'Falha no endpoint de batch.',
      );
      for (final item in ordered) {
        resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
          clientUuid: item.clientUuid,
          success: false,
          errorMessage: message,
        );
      }
      return;
    }

    aliasToServerId.addAll(_parseIdMap(parsedBody['id_map']));

    final rawItems = parsedBody['items'];
    final rawItemByUuid = <String, Map<String, dynamic>>{};
    if (rawItems is List) {
      for (final row in rawItems) {
        if (row is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(row);
        final uuid = (map['client_uuid'] ?? '').toString().trim();
        if (uuid.isNotEmpty) {
          rawItemByUuid[uuid] = map;
        }
      }
    }

    for (final item in ordered) {
      final rawResult = rawItemByUuid[item.clientUuid];
      if (rawResult == null) {
        resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
          clientUuid: item.clientUuid,
          success: false,
          errorMessage: 'Item não retornado pela API batch.',
        );
        continue;
      }

      final success = rawResult['success'] == true;
      final blocked =
          rawResult['blocked'] == true ||
          (rawResult['state'] ?? '').toString().toLowerCase() == 'blocked';
      final status =
          _coerceInt(rawResult['http_status']) ?? response.statusCode;
      final conflict = blocked || status == 409;
      final errorMessage = (rawResult['error_message'] ?? rawResult['error'])
          ?.toString();

      if (success && item.entityAlias != null) {
        final entityId =
            _coerceInt(rawResult['entity_id']) ??
            aliasToServerId[item.entityAlias!];
        if (entityId != null) {
          aliasToServerId[item.entityAlias!] = entityId;
        }
      }

      resultsByUuid[item.clientUuid] = BatchSyncExecutionResult(
        clientUuid: item.clientUuid,
        success: success,
        conflict: conflict,
        blocked: blocked,
        errorMessage: errorMessage,
      );
    }
  }

  Future<SyncExecutionResult> _uploadPhoto(PendingSyncItem item) async {
    final uploadUrl = photoUploadUrl;
    if (uploadUrl == null) {
      return const SyncExecutionResult(
        success: false,
        errorMessage: 'URL de upload de foto não configurada no app.',
      );
    }

    final rawRdoId = item.payload['rdo_id'];
    if (rawRdoId == null) {
      return const SyncExecutionResult(
        success: false,
        errorMessage: 'rdo_id ausente no payload de foto.',
      );
    }

    final filePath =
        (item.payload['file_path'] ?? item.payload['photo_path'] ?? '')
            .toString()
            .trim();
    if (filePath.isEmpty) {
      return const SyncExecutionResult(
        success: false,
        errorMessage: 'file_path ausente no payload de foto.',
      );
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      return SyncExecutionResult(
        success: false,
        errorMessage: 'Arquivo não encontrado no dispositivo: $filePath',
      );
    }

    final request = http.MultipartRequest('POST', uploadUrl);
    request.headers.addAll(await _requestHeaders());
    request.fields['client_uuid'] = item.clientUuid;
    request.fields['rdo_id'] = '$rawRdoId';

    for (final entry in item.payload.entries) {
      final key = entry.key;
      if (key == 'file_path' || key == 'photo_path' || key == 'rdo_id') {
        continue;
      }
      final value = entry.value;
      if (value == null) {
        continue;
      }
      request.fields[key] = '$value';
    }

    request.files.add(await http.MultipartFile.fromPath('fotos', file.path));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final status = response.statusCode;

    final responseBody = _decodeJsonMap(response.body);

    if (status == 409) {
      return SyncExecutionResult(
        success: false,
        conflict: true,
        errorMessage:
            (responseBody['error_message'] ?? responseBody['error'])
                ?.toString() ??
            'Conflito de sincronização de foto.',
      );
    }

    final serverSuccess = responseBody['success'];
    final bool ok =
        status >= 200 &&
        status < 300 &&
        (serverSuccess is! bool || serverSuccess);
    if (ok) {
      return const SyncExecutionResult(success: true);
    }

    return SyncExecutionResult(
      success: false,
      errorMessage:
          (responseBody['error_message'] ??
                  responseBody['error'] ??
                  'Falha no upload de foto.')
              .toString(),
    );
  }

  _PreparedBatchItem _prepareBatchItem(PendingSyncItem item) {
    final rawPayload = _deepCopy(item.payload);
    final payloadMap = rawPayload is Map<String, dynamic>
        ? rawPayload
        : <String, dynamic>{};

    final dependsOn = <String>{
      ..._coerceDependencyList(payloadMap[_metaDependsOnKey]),
    };

    final cleanedPayload = _stripBatchMetadataAndCollectRefs(
      payloadMap,
      dependsOn,
    );

    String? entityAlias = _normalizeAlias(payloadMap[_metaEntityAliasKey]);
    entityAlias ??= item.clientUuid;

    return _PreparedBatchItem(
      source: item,
      clientUuid: item.clientUuid,
      operation: item.operation,
      cleanedPayload: cleanedPayload,
      entityAlias: entityAlias,
      dependsOn: dependsOn.toList(growable: false),
      isPhoto: _isPhotoOperation(item.operation.toLowerCase()),
    );
  }

  List<_PreparedBatchItem> _topologicalOrder(List<_PreparedBatchItem> items) {
    final ordered = <_PreparedBatchItem>[];
    final remaining = List<_PreparedBatchItem>.from(items);
    final resolvedUuids = <String>{};
    final knownUuids = items.map((item) => item.clientUuid).toSet();
    final aliasToUuid = <String, String>{
      for (final item in items)
        if (item.entityAlias != null && item.entityAlias!.trim().isNotEmpty)
          item.entityAlias!.trim(): item.clientUuid,
    };

    while (remaining.isNotEmpty) {
      var progressed = false;

      for (var i = 0; i < remaining.length; i++) {
        final item = remaining[i];
        var depsSatisfied = true;

        for (final dep in item.dependsOn) {
          final key = dep.trim();
          if (key.isEmpty) {
            continue;
          }

          String? depUuid;
          if (knownUuids.contains(key)) {
            depUuid = key;
          } else {
            depUuid = aliasToUuid[key];
          }

          if (depUuid != null && !resolvedUuids.contains(depUuid)) {
            depsSatisfied = false;
            break;
          }
        }

        if (!depsSatisfied) {
          continue;
        }

        ordered.add(item);
        resolvedUuids.add(item.clientUuid);
        remaining.removeAt(i);
        i -= 1;
        progressed = true;
      }

      if (!progressed) {
        ordered.addAll(remaining);
        break;
      }
    }

    return ordered;
  }

  Uri _resolveBatchSyncUrl() {
    if (batchSyncUrl != null) {
      return batchSyncUrl!;
    }

    final path = syncUrl.path;
    if (path.endsWith('/sync/')) {
      return syncUrl.replace(path: '${path}batch/');
    }
    if (path.endsWith('/sync')) {
      return syncUrl.replace(path: '$path/batch/');
    }
    if (path.endsWith('/')) {
      return syncUrl.replace(path: '${path}batch/');
    }
    return syncUrl.replace(path: '$path/batch/');
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  Future<Map<String, String>> _jsonHeaders() async {
    final headers = await _requestHeaders();
    headers.putIfAbsent('Content-Type', () => 'application/json');
    return headers;
  }

  Future<Map<String, String>> _requestHeaders() async {
    final headers = <String, String>{...staticHeaders};
    final rawToken = await authTokenProvider?.call();
    final token = (rawToken ?? '').trim();
    if (token.isNotEmpty && !_hasAuthorizationHeader(headers)) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  bool _hasAuthorizationHeader(Map<String, String> headers) {
    for (final key in headers.keys) {
      if (key.toLowerCase() == 'authorization') {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _removePayloadMetadata(Map<String, dynamic> payload) {
    final cleaned = _removeMetaRecursive(payload);
    if (cleaned is Map<String, dynamic>) {
      return cleaned;
    }
    return <String, dynamic>{};
  }

  dynamic _removeMetaRecursive(dynamic value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, val) {
        final keyStr = '$key';
        if (keyStr == _metaEntityAliasKey || keyStr == _metaDependsOnKey) {
          return;
        }
        out[keyStr] = _removeMetaRecursive(val);
      });
      return out;
    }

    if (value is List) {
      return value.map(_removeMetaRecursive).toList(growable: false);
    }

    return value;
  }

  Map<String, dynamic> _stripBatchMetadataAndCollectRefs(
    Map<String, dynamic> payload,
    Set<String> dependsOn,
  ) {
    final cleaned = _stripMetaAndCollectRecursive(payload, dependsOn);
    if (cleaned is Map<String, dynamic>) {
      return cleaned;
    }
    return <String, dynamic>{};
  }

  dynamic _stripMetaAndCollectRecursive(dynamic value, Set<String> dependsOn) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, val) {
        final keyStr = '$key';
        if (keyStr == _metaEntityAliasKey || keyStr == _metaDependsOnKey) {
          return;
        }
        out[keyStr] = _stripMetaAndCollectRecursive(val, dependsOn);
      });
      return out;
    }

    if (value is List) {
      return value
          .map((entry) => _stripMetaAndCollectRecursive(entry, dependsOn))
          .toList(growable: false);
    }

    if (value is String) {
      final raw = value.trim();
      if (raw.startsWith(_localRefPrefix)) {
        final alias = raw.substring(_localRefPrefix.length).trim();
        if (alias.isNotEmpty) {
          dependsOn.add(alias);
          return '$_serverRefPrefix$alias';
        }
      }
      if (raw.startsWith(_serverRefPrefix)) {
        final alias = raw.substring(_serverRefPrefix.length).trim();
        if (alias.isNotEmpty) {
          dependsOn.add(alias);
        }
      }
      return value;
    }

    return value;
  }

  Map<String, dynamic> _resolvePayloadRefsWithIdMap(
    Map<String, dynamic> payload,
    Map<String, int> aliasToServerId,
  ) {
    final resolved = _resolveRefsRecursive(payload, aliasToServerId);
    if (resolved is Map<String, dynamic>) {
      return resolved;
    }
    return <String, dynamic>{};
  }

  dynamic _resolveRefsRecursive(
    dynamic value,
    Map<String, int> aliasToServerId,
  ) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, val) {
        out['$key'] = _resolveRefsRecursive(val, aliasToServerId);
      });
      return out;
    }

    if (value is List) {
      return value
          .map((entry) => _resolveRefsRecursive(entry, aliasToServerId))
          .toList(growable: false);
    }

    if (value is String) {
      final raw = value.trim();
      if (raw.startsWith(_localRefPrefix)) {
        final alias = raw.substring(_localRefPrefix.length).trim();
        final resolved = aliasToServerId[alias];
        return resolved ?? value;
      }
      if (raw.startsWith(_serverRefPrefix)) {
        final alias = raw.substring(_serverRefPrefix.length).trim();
        final resolved = aliasToServerId[alias];
        return resolved ?? value;
      }
      return value;
    }

    return value;
  }

  bool _containsUnresolvedLocalOrServerRef(dynamic value) {
    if (value is String) {
      final raw = value.trim();
      return raw.startsWith(_localRefPrefix) ||
          raw.startsWith(_serverRefPrefix);
    }

    if (value is List) {
      for (final entry in value) {
        if (_containsUnresolvedLocalOrServerRef(entry)) {
          return true;
        }
      }
      return false;
    }

    if (value is Map) {
      for (final entry in value.values) {
        if (_containsUnresolvedLocalOrServerRef(entry)) {
          return true;
        }
      }
      return false;
    }

    return false;
  }

  dynamic _deepCopy(dynamic value) {
    if (value is Map) {
      final copy = <String, dynamic>{};
      value.forEach((key, entry) {
        copy['$key'] = _deepCopy(entry);
      });
      return copy;
    }

    if (value is List) {
      return value.map(_deepCopy).toList(growable: false);
    }

    return value;
  }

  List<String> _coerceDependencyList(dynamic raw) {
    final out = <String>[];

    void addOne(dynamic value) {
      final key = (value ?? '').toString().trim();
      if (key.isEmpty) {
        return;
      }
      if (!out.contains(key)) {
        out.add(key);
      }
    }

    if (raw is List) {
      for (final entry in raw) {
        addOne(entry);
      }
      return out;
    }

    if (raw is String) {
      addOne(raw);
      return out;
    }

    if (raw is Map) {
      for (final entry in raw.values) {
        addOne(entry);
      }
      return out;
    }

    if (raw != null) {
      addOne(raw);
    }

    return out;
  }

  String? _normalizeAlias(dynamic value) {
    final alias = (value ?? '').toString().trim();
    if (alias.isEmpty) {
      return null;
    }
    return alias;
  }

  Map<String, int> _parseIdMap(dynamic rawIdMap) {
    final out = <String, int>{};
    if (rawIdMap is! Map) {
      return out;
    }

    rawIdMap.forEach((key, value) {
      final alias = '$key'.trim();
      final parsed = _coerceInt(value);
      if (alias.isEmpty || parsed == null) {
        return;
      }
      out[alias] = parsed;
    });
    return out;
  }

  int? _coerceInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final asString = value.toString().trim();
    if (asString.isEmpty) {
      return null;
    }

    return int.tryParse(asString) ??
        (() {
          final n = double.tryParse(asString);
          if (n == null) {
            return null;
          }
          return n.toInt();
        })();
  }

  bool _isPhotoOperation(String op) {
    return op == 'rdo.photo.upload' || op == 'rdo_photo_upload';
  }

  String _extractErrorMessageByStatus(
    int statusCode,
    Map<String, dynamic> responseBody, {
    required String fallback,
  }) {
    final apiMessage =
        (responseBody['error_message'] ??
                responseBody['error'] ??
                responseBody['message'])
            ?.toString()
            .trim();
    if (apiMessage != null && apiMessage.isNotEmpty) {
      return apiMessage;
    }
    if (statusCode == 401) {
      return 'Sessão inválida ou expirada. Faça login novamente.';
    }
    if (statusCode == 403) {
      return 'Acesso negado para sincronizar neste app.';
    }
    return fallback;
  }

  Map<String, dynamic> _jsonSafeMap(dynamic value) {
    final safe = _jsonSafeValue(value);
    if (safe is Map<String, dynamic>) {
      return safe;
    }
    if (safe is Map) {
      final out = <String, dynamic>{};
      safe.forEach((key, val) {
        out['$key'] = val;
      });
      return out;
    }
    return <String, dynamic>{};
  }

  dynamic _jsonSafeValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, val) {
        out['$key'] = _jsonSafeValue(val);
      });
      return out;
    }

    if (value is Iterable) {
      return value.map(_jsonSafeValue).toList(growable: false);
    }

    return value.toString();
  }
}

class _PreparedBatchItem {
  const _PreparedBatchItem({
    required this.source,
    required this.clientUuid,
    required this.operation,
    required this.cleanedPayload,
    required this.dependsOn,
    required this.isPhoto,
    this.entityAlias,
  });

  final PendingSyncItem source;
  final String clientUuid;
  final String operation;
  final Map<String, dynamic> cleanedPayload;
  final List<String> dependsOn;
  final String? entityAlias;
  final bool isPhoto;

  Map<String, dynamic> toBatchMap() {
    final out = <String, dynamic>{
      'client_uuid': clientUuid,
      'operation': operation,
      'payload': cleanedPayload,
    };

    if (dependsOn.isNotEmpty) {
      out['depends_on'] = dependsOn;
    }
    if (entityAlias != null && entityAlias!.trim().isNotEmpty) {
      out['entity_alias'] = entityAlias;
    }

    return out;
  }
}
