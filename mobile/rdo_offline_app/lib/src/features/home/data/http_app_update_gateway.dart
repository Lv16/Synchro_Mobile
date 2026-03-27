import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../application/app_update_gateway.dart';

class AppUpdateException implements Exception {
  const AppUpdateException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HttpAppUpdateGateway implements AppUpdateGateway {
  HttpAppUpdateGateway({
    required this.updateUrl,
    http.Client? client,
    this.staticHeaders = const <String, String>{},
    this.authTokenProvider,
  }) : _client = client ?? http.Client();

  final Uri updateUrl;
  final http.Client _client;
  final Map<String, String> staticHeaders;
  final FutureOr<String?> Function()? authTokenProvider;

  @override
  Future<AppUpdateInfo?> fetchLatestUpdate({
    String platform = 'android',
  }) async {
    final normalizedPlatform = platform.trim().toLowerCase().isEmpty
        ? 'android'
        : platform.trim().toLowerCase();
    final requestUrl = updateUrl.replace(
      queryParameters: <String, String>{'platform': normalizedPlatform},
    );

    late final http.Response response;
    try {
      response = await _client.get(
        requestUrl,
        headers: await _requestHeaders(),
      );
    } on SocketException {
      throw const AppUpdateException('Sem conexão para verificar atualização.');
    } on HttpException {
      throw const AppUpdateException('Falha de rede ao verificar atualização.');
    }

    final payload = _decodeJsonMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException(
        _extractErrorMessage(payload, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final success = payload['success'];
    if (success is bool && !success) {
      throw AppUpdateException(
        _extractErrorMessage(payload, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final rawUpdate = payload['update'];
    if (rawUpdate is! Map) {
      return null;
    }
    final update = Map<String, dynamic>.from(rawUpdate);

    return AppUpdateInfo(
      available: _coerceBool(update['available']),
      downloadUrl: _cleanString(update['download_url']),
      versionName: _cleanString(update['version_name']),
      buildNumber: _coerceInt(update['build_number']) ?? 0,
      forceUpdate: _coerceBool(update['force_update']),
      minSupportedBuild: _coerceInt(update['min_supported_build']),
      releaseNotes: _cleanString(update['release_notes']),
    );
  }

  Future<Map<String, String>> _requestHeaders() async {
    final headers = <String, String>{...staticHeaders};
    final tokenProvider = authTokenProvider;
    if (tokenProvider != null) {
      final token = (await tokenProvider())?.trim();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    if (body.trim().isEmpty) {
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

  String _extractErrorMessage(Map<String, dynamic> payload, int statusCode) {
    final fromApi =
        (payload['error_message'] ?? payload['error'] ?? payload['message'])
            ?.toString()
            .trim();
    if (fromApi != null && fromApi.isNotEmpty) {
      return fromApi;
    }
    switch (statusCode) {
      case 401:
        return 'Sessão inválida. Faça login novamente.';
      case 403:
        return 'Acesso não permitido para verificação de atualização.';
      default:
        return 'Falha ao verificar atualização.';
    }
  }
}

bool _coerceBool(dynamic raw) {
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    return raw != 0;
  }
  final value = '$raw'.trim().toLowerCase();
  return value == '1' || value == 'true' || value == 'yes' || value == 'on';
}

int? _coerceInt(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  final value = '$raw'.trim();
  if (value.isEmpty) {
    return null;
  }
  return int.tryParse(value);
}

String _cleanString(dynamic raw) {
  if (raw == null) {
    return '';
  }
  return '$raw'.trim();
}
