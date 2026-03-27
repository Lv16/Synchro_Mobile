import 'package:flutter/foundation.dart';

import '../data/mobile_auth_api.dart';
import '../data/shared_prefs_auth_session_store.dart';
import '../domain/auth_session.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({
    required AuthSessionStore store,
    MobileAuthApiClient? apiClient,
  }) : _store = store,
       _apiClient = apiClient;

  factory AuthSessionController.disabled() {
    return AuthSessionController(store: const _NoopAuthSessionStore());
  }

  final AuthSessionStore _store;
  final MobileAuthApiClient? _apiClient;

  AuthSession? _session;
  bool _bootstrapping = false;
  bool _busy = false;
  String? _message;

  bool get bootstrapping => _bootstrapping;
  bool get busy => _busy;
  bool get loginAvailable => _apiClient != null;
  bool get isAuthenticated => _session != null && !_session!.isExpired;
  String? get accessToken => isAuthenticated ? _session?.accessToken : null;
  String? get username => _session?.username;
  DateTime? get expiresAt => _session?.expiresAt;
  String? get message => _message;

  Future<void> bootstrap() async {
    if (_bootstrapping) {
      return;
    }
    _bootstrapping = true;
    notifyListeners();

    try {
      final stored = await _store.read();
      if (stored == null) {
        _session = null;
        return;
      }
      if (stored.isExpired) {
        await _store.clear();
        _session = null;
        _message = 'Sessão expirada. Faça login novamente.';
        return;
      }
      _session = stored;
    } finally {
      _bootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    required String deviceName,
    required String platform,
  }) async {
    if (_busy) {
      return false;
    }
    final api = _apiClient;
    if (api == null) {
      _message = 'Login online não está configurado neste build.';
      notifyListeners();
      return false;
    }

    _busy = true;
    _message = null;
    notifyListeners();

    try {
      final session = await api.login(
        username: username,
        password: password,
        deviceName: deviceName,
        platform: platform,
      );
      _session = session;
      await _store.write(session);
      return true;
    } on MobileAuthException catch (err) {
      _message = err.message;
      return false;
    } catch (_) {
      _message = 'Falha inesperada ao autenticar.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_busy) {
      return;
    }
    _busy = true;
    notifyListeners();

    try {
      final token = _session?.accessToken;
      if (token != null && token.isNotEmpty) {
        await _apiClient?.revoke(token);
      }
      _session = null;
      await _store.clear();
      _message = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

class _NoopAuthSessionStore implements AuthSessionStore {
  const _NoopAuthSessionStore();

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> write(AuthSession session) async {}
}
