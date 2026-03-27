import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/auth_session.dart';

class MobileAuthException implements Exception {
  const MobileAuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MobileAuthApiClient {
  MobileAuthApiClient({
    required this.tokenUrl,
    this.revokeUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri tokenUrl;
  final Uri? revokeUrl;
  final http.Client _client;

  Future<AuthSession> login({
    required String username,
    required String password,
    required String deviceName,
    required String platform,
  }) async {
    late final http.Response response;
    try {
      response = await _client.post(
        tokenUrl,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'username': username.trim(),
          'password': password,
          'device_name': deviceName.trim(),
          'platform': platform.trim(),
        }),
      );
    } on SocketException {
      throw const MobileAuthException(
        'Sem conexão com o servidor de autenticação.',
      );
    } on HttpException {
      throw const MobileAuthException('Falha de rede na autenticação.');
    }

    final body = _decodeJsonMap(response.body);
    final ok =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['success'] != false;

    if (!ok) {
      throw MobileAuthException(
        _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final accessToken = (body['access_token'] ?? '').toString().trim();
    if (accessToken.isEmpty) {
      throw MobileAuthException(
        'Resposta de login inválida: token ausente.',
        statusCode: response.statusCode,
      );
    }

    final tokenType = (body['token_type'] ?? 'Bearer').toString();
    final user = body['user'];
    int? userId;
    String? resolvedUsername;
    bool isSupervisor = true;
    if (user is Map) {
      userId = _coerceInt(user['id']);
      resolvedUsername = user['username']?.toString();
      if (user['is_supervisor'] == false) {
        isSupervisor = false;
      }
    }

    if (!isSupervisor) {
      throw MobileAuthException(
        'Este aplicativo permite apenas login de Supervisor.',
        statusCode: 403,
      );
    }

    return AuthSession(
      accessToken: accessToken,
      tokenType: tokenType,
      userId: userId,
      username: resolvedUsername ?? username.trim(),
      expiresAt: DateTime.tryParse((body['expires_at'] ?? '').toString()),
    );
  }

  Future<void> revoke(String accessToken) async {
    final url = revokeUrl;
    if (url == null) {
      return;
    }

    try {
      await _client.post(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(const <String, dynamic>{}),
      );
    } catch (_) {
      // O logout local é suficiente; erro remoto não deve bloquear.
    }
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

  String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    final fromApi = (body['error_message'] ?? body['error'] ?? body['message'])
        ?.toString()
        .trim();
    if (fromApi != null && fromApi.isNotEmpty) {
      return fromApi;
    }
    if (statusCode == 401) {
      return 'Credenciais inválidas.';
    }
    if (statusCode == 403) {
      return 'Acesso não autorizado para o app mobile.';
    }
    return 'Falha ao autenticar no app.';
  }
}

int? _coerceInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
