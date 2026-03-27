import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'features/auth/application/auth_session_controller.dart';
import 'features/auth/data/mobile_auth_api.dart';
import 'features/auth/data/shared_prefs_auth_session_store.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/application/app_update_gateway.dart';
import 'features/home/application/supervisor_bootstrap_gateway.dart';
import 'features/home/application/translation_preview_gateway.dart';
import 'features/home/data/http_app_update_gateway.dart';
import 'features/home/data/http_supervisor_bootstrap_gateway.dart';
import 'features/home/data/http_translation_preview_gateway.dart';
import 'features/home/presentation/home_page.dart';
import 'features/rdo/application/rdo_sync_gateway.dart';
import 'features/rdo/data/demo_rdo_sync_gateway.dart';
import 'features/rdo/data/http_rdo_sync_gateway.dart';
import 'features/rdo/data/shared_prefs_offline_rdo_repository.dart';
import 'features/rdo/data/sqlite_offline_rdo_repository.dart';
import 'features/rdo/domain/repositories/offline_rdo_repository.dart';
import 'theme/app_theme.dart';

class RdoOfflineApp extends StatefulWidget {
  const RdoOfflineApp({
    super.key,
    this.repository,
    this.syncGateway,
    this.supervisorBootstrapGateway,
    this.translationPreviewGateway,
    this.appUpdateGateway,
  });

  static const String _syncUrlEnv = String.fromEnvironment(
    'RDO_SYNC_URL',
    defaultValue: '',
  );
  static const String _photoUploadUrlEnv = String.fromEnvironment(
    'RDO_PHOTO_UPLOAD_URL',
    defaultValue: '',
  );
  static const String _syncBatchUrlEnv = String.fromEnvironment(
    'RDO_SYNC_BATCH_URL',
    defaultValue: '',
  );
  static const String _apiTokenEnv = String.fromEnvironment(
    'RDO_API_TOKEN',
    defaultValue: '',
  );
  static const String _authTokenUrlEnv = String.fromEnvironment(
    'RDO_AUTH_TOKEN_URL',
    defaultValue: '',
  );
  static const String _authRevokeUrlEnv = String.fromEnvironment(
    'RDO_AUTH_REVOKE_URL',
    defaultValue: '',
  );
  static const String _bootstrapUrlEnv = String.fromEnvironment(
    'RDO_BOOTSTRAP_URL',
    defaultValue: '',
  );
  static const String _translatePreviewUrlEnv = String.fromEnvironment(
    'RDO_TRANSLATE_PREVIEW_URL',
    defaultValue: '',
  );
  static const String _translationUrlLegacyEnv = String.fromEnvironment(
    'RDO_TRANSLATION_URL',
    defaultValue: '',
  );
  static const String _appUpdateUrlEnv = String.fromEnvironment(
    'RDO_APP_UPDATE_URL',
    defaultValue: '',
  );
  static const String _mobileRdoPageUrlEnv = String.fromEnvironment(
    'RDO_MOBILE_RDO_PAGE_URL',
    defaultValue: '',
  );
  static const String _mobileOsRdosUrlEnv = String.fromEnvironment(
    'RDO_MOBILE_OS_RDOS_URL',
    defaultValue: '',
  );
  static const String _deviceNameEnv = String.fromEnvironment(
    'RDO_DEVICE_NAME',
    defaultValue: '',
  );
  static const String _releaseChannelEnv = String.fromEnvironment(
    'RDO_RELEASE_CHANNEL',
    defaultValue: 'prod',
  );
  static const String _appTitleEnv = String.fromEnvironment(
    'RDO_APP_TITLE',
    defaultValue: '',
  );

  final OfflineRdoRepository? repository;
  final RdoSyncGateway? syncGateway;
  final SupervisorBootstrapGateway? supervisorBootstrapGateway;
  final TranslationPreviewGateway? translationPreviewGateway;
  final AppUpdateGateway? appUpdateGateway;

  @override
  State<RdoOfflineApp> createState() => _RdoOfflineAppState();
}

class _RdoOfflineAppState extends State<RdoOfflineApp> {
  late final OfflineRdoRepository _repository;
  late final RdoSyncGateway _gateway;
  late final SupervisorBootstrapGateway? _bootstrapGateway;
  late final TranslationPreviewGateway? _translationGateway;
  late final AppUpdateGateway? _appUpdateGateway;
  late final AuthSessionController _authController;
  Uri? _mobileRdoPageBaseUrl;
  Uri? _mobileOsRdosBaseUrl;

  bool _initialized = false;
  bool _remoteMode = false;
  bool _requiresLogin = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (kIsWeb
            ? SharedPrefsOfflineRdoRepository()
            : SqliteOfflineRdoRepository());
    _configureApp();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  void _configureApp() {
    if (widget.syncGateway != null) {
      _gateway = widget.syncGateway!;
      _bootstrapGateway = widget.supervisorBootstrapGateway;
      _translationGateway = widget.translationPreviewGateway;
      _appUpdateGateway = widget.appUpdateGateway;
      _mobileRdoPageBaseUrl = _parseOptionalUri(
        RdoOfflineApp._mobileRdoPageUrlEnv,
      );
      _mobileOsRdosBaseUrl = _parseOptionalUri(
        RdoOfflineApp._mobileOsRdosUrlEnv,
      );
      _authController = AuthSessionController.disabled();
      _initialized = true;
      return;
    }

    final syncUrl = _resolveSyncUrl();
    if (syncUrl == null) {
      _gateway = DemoRdoSyncGateway();
      _bootstrapGateway = widget.supervisorBootstrapGateway;
      _translationGateway = widget.translationPreviewGateway;
      _appUpdateGateway = widget.appUpdateGateway;
      _mobileRdoPageBaseUrl = _parseOptionalUri(
        RdoOfflineApp._mobileRdoPageUrlEnv,
      );
      _mobileOsRdosBaseUrl = _parseOptionalUri(
        RdoOfflineApp._mobileOsRdosUrlEnv,
      );
      _authController = AuthSessionController.disabled();
      _startupError =
          'Configure RDO_SYNC_URL para iniciar o app com login de Supervisor.';
      _initialized = true;
      return;
    }

    _remoteMode = true;

    final staticToken = RdoOfflineApp._apiTokenEnv.trim();
    _requiresLogin = true;

    final authTokenUrl = _resolveAuthTokenUrl(syncUrl);
    final authRevokeUrl = _resolveAuthRevokeUrl(syncUrl);

    _authController = AuthSessionController(
      store: const SharedPrefsAuthSessionStore(),
      apiClient: _requiresLogin && authTokenUrl != null
          ? MobileAuthApiClient(
              tokenUrl: authTokenUrl,
              revokeUrl: authRevokeUrl,
            )
          : null,
    );

    final staticHeaders = <String, String>{};
    if (staticToken.isNotEmpty) {
      staticHeaders['Authorization'] = 'Bearer $staticToken';
    }

    _gateway = HttpRdoSyncGateway(
      syncUrl: syncUrl,
      batchSyncUrl: _parseOptionalUri(RdoOfflineApp._syncBatchUrlEnv),
      photoUploadUrl: _resolvePhotoUploadUrl(syncUrl),
      staticHeaders: staticHeaders,
      authTokenProvider: _requiresLogin
          ? () => _authController.accessToken
          : null,
    );

    final bootstrapUrl = _resolveBootstrapUrl(syncUrl);
    _bootstrapGateway =
        widget.supervisorBootstrapGateway ??
        (bootstrapUrl == null
            ? null
            : HttpSupervisorBootstrapGateway(
                bootstrapUrl: bootstrapUrl,
                staticHeaders: staticHeaders,
                authTokenProvider: _requiresLogin
                    ? () => _authController.accessToken
                    : null,
              ));

    final translatePreviewUrl = _resolveTranslatePreviewUrl(syncUrl);
    _translationGateway =
        widget.translationPreviewGateway ??
        (translatePreviewUrl == null
            ? null
            : HttpTranslationPreviewGateway(
                translateUrl: translatePreviewUrl,
                staticHeaders: staticHeaders,
                authTokenProvider: _requiresLogin
                    ? () => _authController.accessToken
                    : null,
              ));

    final updateUrl = _resolveAppUpdateUrl(syncUrl);
    _appUpdateGateway =
        widget.appUpdateGateway ??
        (updateUrl == null
            ? null
            : HttpAppUpdateGateway(
                updateUrl: updateUrl,
                staticHeaders: staticHeaders,
                authTokenProvider: _requiresLogin
                    ? () => _authController.accessToken
                    : null,
              ));

    _mobileRdoPageBaseUrl = _resolveMobileRdoPageBaseUrl(syncUrl);
    _mobileOsRdosBaseUrl = _resolveMobileOsRdosBaseUrl(syncUrl);

    _bootstrapAuth(authTokenUrl);
  }

  Future<void> _bootstrapAuth(Uri? authTokenUrl) async {
    if (!_requiresLogin) {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      } else {
        _initialized = true;
      }
      return;
    }

    if (authTokenUrl == null || !_authController.loginAvailable) {
      if (mounted) {
        setState(() {
          _startupError =
              'Configure RDO_AUTH_TOKEN_URL para habilitar login do Supervisor.';
          _initialized = true;
        });
      } else {
        _startupError =
            'Configure RDO_AUTH_TOKEN_URL para habilitar login do Supervisor.';
        _initialized = true;
      }
      return;
    }

    try {
      await _authController.bootstrap();
    } catch (err) {
      _startupError = 'Falha ao carregar sessão local: $err';
    } finally {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      } else {
        _initialized = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTitle = _resolveAppTitle();
    Widget home = _buildHome();
    final releaseChannelLabel = _resolveReleaseChannelLabel();
    if (releaseChannelLabel != null) {
      home = Banner(
        message: releaseChannelLabel,
        location: BannerLocation.topEnd,
        color: const Color(0xFFE65100),
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
        child: home,
      );
    }

    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: home,
    );
  }

  Widget _buildHome() {
    if (!_initialized) {
      return const _SplashPage();
    }

    if (_startupError != null) {
      return _StartupErrorPage(message: _startupError!);
    }

    if (!_remoteMode) {
      return _StartupErrorPage(
        message:
            'Configure RDO_SYNC_URL para iniciar o app com login de Supervisor.',
      );
    }

    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        if (_authController.bootstrapping) {
          return const _SplashPage();
        }

        if (!_authController.isAuthenticated) {
          return LoginPage(
            controller: _authController,
            deviceName: _resolveDeviceName(),
            platform: _resolvePlatform(),
          );
        }

        return HomePage(
          repository: _repository,
          syncGateway: _gateway,
          bootstrapGateway: _bootstrapGateway,
          translationGateway: _translationGateway,
          appUpdateGateway: _appUpdateGateway,
          mobileRdoPageBaseUrl: _mobileRdoPageBaseUrl,
          mobileOsRdosBaseUrl: _mobileOsRdosBaseUrl,
          mobileApiAccessToken: _authController.accessToken,
          supervisorLabel: _authController.username ?? 'Supervisor',
          sessionExpiresAt: _authController.expiresAt,
          onLogout: _authController.logout,
          showSeedAction: false,
        );
      },
    );
  }

  Uri? _resolveAuthTokenUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(RdoOfflineApp._authTokenUrlEnv);
    if (configured != null) {
      return configured;
    }
    return _deriveFromSync(syncUrl, '/auth/token/');
  }

  Uri? _resolveAuthRevokeUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(RdoOfflineApp._authRevokeUrlEnv);
    if (configured != null) {
      return configured;
    }
    return _deriveFromSync(syncUrl, '/auth/revoke/');
  }

  Uri? _resolveBootstrapUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(RdoOfflineApp._bootstrapUrlEnv);
    if (configured != null) {
      return configured;
    }
    return _deriveFromSync(syncUrl, '/bootstrap/');
  }

  Uri? _resolveTranslatePreviewUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(RdoOfflineApp._translatePreviewUrlEnv);
    if (configured != null) {
      return configured;
    }
    final legacyConfigured = _parseOptionalUri(
      RdoOfflineApp._translationUrlLegacyEnv,
    );
    if (legacyConfigured != null) {
      return legacyConfigured;
    }
    return _deriveFromSync(syncUrl, '/translate/preview/');
  }

  Uri? _resolveAppUpdateUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(RdoOfflineApp._appUpdateUrlEnv);
    if (configured != null) {
      return configured;
    }
    return _deriveFromSync(syncUrl, '/app/update/');
  }

  Uri? _resolveMobileRdoPageBaseUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(RdoOfflineApp._mobileRdoPageUrlEnv);
    if (configured != null) {
      return configured;
    }
    return _deriveFromSync(syncUrl, '/rdo/');
  }

  Uri? _resolveMobileOsRdosBaseUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(RdoOfflineApp._mobileOsRdosUrlEnv);
    if (configured != null) {
      return configured;
    }
    return _deriveFromSync(syncUrl, '/os/');
  }

  Uri? _resolvePhotoUploadUrl(Uri syncUrl) {
    final configured = _parseOptionalUri(RdoOfflineApp._photoUploadUrlEnv);
    if (configured != null) {
      return configured;
    }
    return _deriveFromSync(syncUrl, '/photo/upload/');
  }

  Uri? _resolveSyncUrl() {
    final rawSyncUrl = RdoOfflineApp._syncUrlEnv.trim();
    if (rawSyncUrl.isNotEmpty) {
      try {
        return Uri.parse(rawSyncUrl);
      } catch (_) {
        _startupError = 'RDO_SYNC_URL inválida no build do app.';
        return null;
      }
    }

    if (!kIsWeb) {
      return null;
    }

    final base = Uri.base;
    if (base.scheme != 'http' && base.scheme != 'https') {
      return null;
    }

    return base.replace(
      path: '/api/mobile/v1/rdo/sync/',
      query: null,
      fragment: null,
    );
  }

  Uri? _deriveFromSync(Uri syncUrl, String replacementSuffix) {
    final marker = '/rdo/sync';
    final path = syncUrl.path;
    final markerIndex = path.indexOf(marker);
    if (markerIndex < 0) {
      return null;
    }
    final prefix = path.substring(0, markerIndex);
    return syncUrl.replace(path: '$prefix$replacementSuffix');
  }

  Uri? _parseOptionalUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    try {
      return Uri.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _resolveDeviceName() {
    final configured = RdoOfflineApp._deviceNameEnv.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    return 'Supervisor ${_resolvePlatform().toUpperCase()}';
  }

  String _resolveAppTitle() {
    final configured = RdoOfflineApp._appTitleEnv.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    if (_normalizedReleaseChannel() == 'homolog') {
      return 'Ambipar Synchro HML';
    }
    return 'Ambipar Synchro';
  }

  String? _resolveReleaseChannelLabel() {
    if (_normalizedReleaseChannel() == 'homolog') {
      return 'HML';
    }
    return null;
  }

  String _normalizedReleaseChannel() {
    final raw = RdoOfflineApp._releaseChannelEnv.trim().toLowerCase();
    if (raw == 'hml' || raw == 'homolog' || raw == 'qa' || raw == 'staging') {
      return 'homolog';
    }
    return 'prod';
  }

  String _resolvePlatform() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageSurface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 28,
                    color: Color(0xFFB42318),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Falha de configuração do app',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
