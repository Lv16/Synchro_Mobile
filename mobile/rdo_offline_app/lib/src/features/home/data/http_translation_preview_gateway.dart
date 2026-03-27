import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../application/translation_preview_gateway.dart';

class TranslationPreviewException implements Exception {
  const TranslationPreviewException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HttpTranslationPreviewGateway implements TranslationPreviewGateway {
  HttpTranslationPreviewGateway({
    required this.translateUrl,
    http.Client? client,
    this.staticHeaders = const <String, String>{},
    this.authTokenProvider,
  }) : _client = client ?? http.Client();

  final Uri translateUrl;
  final http.Client _client;
  final Map<String, String> staticHeaders;
  final FutureOr<String?> Function()? authTokenProvider;

  @override
  Future<String> translatePtToEn(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      return '';
    }

    late final http.Response response;
    try {
      response = await _client.post(
        translateUrl,
        headers: await _requestHeaders(),
        body: jsonEncode(<String, dynamic>{'text': clean}),
      );
    } on SocketException {
      throw const TranslationPreviewException(
        'Sem conexão para traduzir no momento.',
      );
    } on HttpException {
      throw const TranslationPreviewException(
        'Falha de rede ao traduzir no momento.',
      );
    }

    final payload = _decodeJsonMap(response.body);
    final ok =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        payload['success'] != false;
    if (!ok) {
      throw TranslationPreviewException(
        _extractErrorMessage(payload, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final translated = (payload['en'] ?? '').toString().trim();
    return translated;
  }

  Future<Map<String, String>> _requestHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...staticHeaders,
    };
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
        return 'Sessão inválida para tradução.';
      case 403:
        return 'Sem permissão para tradução.';
      default:
        return 'Falha ao traduzir texto.';
    }
  }
}
