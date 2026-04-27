import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../../../background/background_sync_notification_service.dart';
import '../../../background/background_sync_service.dart';
import '../../../background/background_sync_telemetry.dart';
import '../application/app_update_gateway.dart';
import '../application/supervisor_bootstrap_gateway.dart';
import '../application/translation_preview_gateway.dart';
import '../../rdo/application/offline_sync_controller.dart';
import '../../rdo/application/rdo_sync_gateway.dart';
import '../../rdo/domain/entities/pending_sync_item.dart';
import '../../rdo/domain/repositories/offline_rdo_repository.dart';

const Color _kInk = Color(0xFF111111);
const Color _kMutedInk = Color(0xFF5C6168);
const Color _kCardBorder = Color(0xFFE4E8ED);
const Color _kGreenSoft = Color(0xFFF4FCD6);
const Color _kSurfaceSoft = Color(0xFFF7F8FA);
const Color _kError = Color(0xFFB42318);
const Color _kWarning = Color(0xFFC2410C);
const String _kMetaEntityAliasKey = '__entity_alias';
const String _kMetaDependsOnKey = '__depends_on';
const String _kLocalRefPrefix = '@local:';
const String _kServerRefPrefix = '@ref:';
final RegExp _kMissingDependenciesPattern = RegExp(
  r'depend[êe]ncias ausentes:\s*(.+)$',
  caseSensitive: false,
);
const int _kMaxRdoPhotos = 5;
const bool _kHomologationMode = bool.fromEnvironment(
  'RDO_HOMOLOG_MODE',
  defaultValue: false,
);
const String _kHomologationStorageKey = 'rdo_mobile_homolog_parte1_v1';
const String _kBootstrapCacheStoragePrefix = 'rdo_mobile_bootstrap_cache_v1';

const List<ActivityChoiceItem> _kFallbackActivityChoices = <ActivityChoiceItem>[
  ActivityChoiceItem(value: 'abertura pt', label: 'Abertura PT / Opening PT'),
  ActivityChoiceItem(
    value: 'acesso ao tanque',
    label: 'Acesso ao Tanque / Tank access',
  ),
  ActivityChoiceItem(value: 'almoço', label: 'Almoço / Lunch'),
  ActivityChoiceItem(
    value: 'avaliação inicial da área de trabalho',
    label: 'Avaliação Inicial da Área de Trabalho / Work area pre-check',
  ),
  ActivityChoiceItem(
    value: 'conferência do material e equipamento no container',
    label: 'Conferência de Material no Container / Container material check',
  ),
  ActivityChoiceItem(
    value: 'coleta de água',
    label: 'Coleta de Água / Water sampling',
  ),
  ActivityChoiceItem(value: 'dds', label: 'DDS / Work safety dialog'),
  ActivityChoiceItem(
    value: 'desobstrução de linhas',
    label: 'Desobstrução de Linhas / Drain line clearing',
  ),
  ActivityChoiceItem(
    value: 'drenagem do tanque',
    label: 'Drenagem do Tanque / Tank draining',
  ),
  ActivityChoiceItem(value: 'em espera', label: 'Em Espera / Stand-by'),
  ActivityChoiceItem(
    value: 'equipe chegou no aeroporto',
    label: 'Equipe Chegou no Aeroporto / Team arrived at the airport',
  ),
  ActivityChoiceItem(
    value: 'vôo com destino a unidade',
    label: 'Voo com Destino à Unidade / Flight to unit',
  ),
  ActivityChoiceItem(
    value: 'vôo postergado',
    label: 'Voo Postergado / Flight postponed',
  ),
  ActivityChoiceItem(value: 'triagem', label: 'Triagem / Security screening'),
  ActivityChoiceItem(
    value: 'check-in, pesagem, briefing',
    label: 'Check-in, Pesagem, Briefing / Check-in, weighing, briefing',
  ),
  ActivityChoiceItem(
    value: 'saída da base',
    label: 'Saída da Base / Departure from base',
  ),
  ActivityChoiceItem(
    value: 'equipe se apresenta ao responsável da unidade',
    label: 'Equipe se Apresenta / Team introduces itself at unit',
  ),
  ActivityChoiceItem(
    value: 'instalação/preparação/montagem',
    label: 'Instalação/Preparação/Montagem / Setup',
  ),
  ActivityChoiceItem(value: 'jantar', label: 'Jantar / Dinner'),
  ActivityChoiceItem(
    value: 'limpeza da área',
    label: 'Limpeza da Área / Housekeeping',
  ),
  ActivityChoiceItem(
    value: 'treinamento de abandono',
    label: 'Treinamento de Abandono / Drill',
  ),
  ActivityChoiceItem(value: 'alarme real', label: 'Alarme Real / Real alarm'),
  ActivityChoiceItem(
    value: 'instrução de segurança',
    label: 'Instrução de Segurança / Safety instruction',
  ),
  ActivityChoiceItem(
    value: 'mobilização de material - dentro do tanque',
    label: 'Mobilização Dentro do Tanque / Material mobilization inside tank',
  ),
  ActivityChoiceItem(
    value: 'mobilização de material - fora do tanque',
    label: 'Mobilização Fora do Tanque / Material mobilization outside tank',
  ),
  ActivityChoiceItem(
    value: 'desmobilização do material - dentro do tanque',
    label:
        'Desmobilização Dentro do Tanque / Material demobilization inside tank',
  ),
  ActivityChoiceItem(
    value: 'desmobilização do material - fora do tanque',
    label:
        'Desmobilização Fora do Tanque / Material demobilization outside tank',
  ),
  ActivityChoiceItem(value: 'reunião', label: 'Reunião / Meeting'),
  ActivityChoiceItem(
    value: 'limpeza de dutos',
    label: 'Limpeza de Dutos / Duct cleaning',
  ),
  ActivityChoiceItem(
    value: 'operação com robô',
    label: 'Operação com Robô / Robot operation',
  ),
  ActivityChoiceItem(
    value: 'renovação de pt/pet',
    label: 'Renovação de PT/PET / PT/PET renewal',
  ),
  ActivityChoiceItem(
    value: 'limpeza mecânica',
    label: 'Limpeza Mecânica / Mechanical cleaning',
  ),
  ActivityChoiceItem(
    value: 'teste tubo a tubo',
    label: 'Teste Tubo a Tubo / Tube-to-tube test',
  ),
  ActivityChoiceItem(
    value: 'teste hidrostático',
    label: 'Teste Hidrostático / Hydrostatic test',
  ),
  ActivityChoiceItem(
    value: 'desmontagem de equipamento',
    label: 'Desmontagem de Equipamento / Equipment disassembly',
  ),
  ActivityChoiceItem(
    value: 'montagem de equipamento',
    label: 'Montagem de Equipamento / Equipment assembly',
  ),
  ActivityChoiceItem(
    value: 'limpeza do convés',
    label: 'Limpeza do Convés / Deck cleaning',
  ),
];

const List<ActivityChoiceItem> _kFallbackServiceChoices = <ActivityChoiceItem>[
  ActivityChoiceItem(value: 'COLETA DE AR', label: 'COLETA DE AR'),
  ActivityChoiceItem(value: 'COLETA DE ÁGUA', label: 'COLETA DE ÁGUA'),
  ActivityChoiceItem(
    value: 'DELINEAMENTO DE ATIVIDADES',
    label: 'DELINEAMENTO DE ATIVIDADES',
  ),
  ActivityChoiceItem(
    value: 'DESOBSTRUÇÃO DE LINHAS',
    label: 'DESOBSTRUÇÃO DE LINHAS',
  ),
  ActivityChoiceItem(
    value: 'DESOBSTRUÇÃO DE RALOS',
    label: 'DESOBSTRUÇÃO DE RALOS',
  ),
  ActivityChoiceItem(
    value: 'EMISSÃO DE FREE FOR FIRE',
    label: 'EMISSÃO DE FREE FOR FIRE',
  ),
  ActivityChoiceItem(
    value: "LIMPEZA DE CAIXA D'ÁGUA/BEBEDOURO",
    label: "LIMPEZA DE CAIXA D'ÁGUA/BEBEDOURO",
  ),
  ActivityChoiceItem(value: 'LIMPEZA DE COIFA', label: 'LIMPEZA DE COIFA'),
  ActivityChoiceItem(value: 'LIMPEZA DE COSTADO', label: 'LIMPEZA DE COSTADO'),
  ActivityChoiceItem(value: 'LIMPEZA DE DUTO', label: 'LIMPEZA DE DUTO'),
  ActivityChoiceItem(
    value: 'LIMPEZA DE DUTO, COIFA',
    label: 'LIMPEZA DE DUTO, COIFA',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE DUTO, COIFA, COLETA DE AR',
    label: 'LIMPEZA DE DUTO, COIFA, COLETA DE AR',
  ),
  ActivityChoiceItem(value: 'LIMPEZA DE SILO', label: 'LIMPEZA DE SILO'),
  ActivityChoiceItem(
    value: 'LIMPEZA DE SILO CIMENTO',
    label: 'LIMPEZA DE SILO CIMENTO',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE DE ÁGUA',
    label: 'LIMPEZA DE TANQUE DE ÁGUA',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE DE ÁGUA PRODUZIDA',
    label: 'LIMPEZA DE TANQUE DE ÁGUA PRODUZIDA',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE DE CARGA',
    label: 'LIMPEZA DE TANQUE DE CARGA',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE DE DIESEL',
    label: 'LIMPEZA DE TANQUE DE DIESEL',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE DE DRENO',
    label: 'LIMPEZA DE TANQUE DE DRENO',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE DE ÓLEO',
    label: 'LIMPEZA DE TANQUE DE ÓLEO',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE DE PRODUTO QUÍMICO',
    label: 'LIMPEZA DE TANQUE DE PRODUTO QUÍMICO',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE DE LAMA',
    label: 'LIMPEZA DE TANQUE DE LAMA',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE SEWAGE',
    label: 'LIMPEZA DE TANQUE SEWAGE',
  ),
  ActivityChoiceItem(value: 'LIMPEZA DE VASO', label: 'LIMPEZA DE VASO'),
  ActivityChoiceItem(
    value: 'LIMPEZA DE TANQUE OFFSPEC',
    label: 'LIMPEZA DE TANQUE OFFSPEC',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA TROCADOR DE CALOR',
    label: 'LIMPEZA TROCADOR DE CALOR',
  ),
  ActivityChoiceItem(
    value: 'LIMPEZA QUÍMICA DE TUBULAÇÃO',
    label: 'LIMPEZA QUÍMICA DE TUBULAÇÃO',
  ),
  ActivityChoiceItem(value: 'LIMPEZA DE REDE', label: 'LIMPEZA DE REDE'),
  ActivityChoiceItem(value: 'LIMPEZA HVAC', label: 'LIMPEZA HVAC'),
  ActivityChoiceItem(
    value: 'MOBILIZAÇÃO/DESMOBILIZAÇÃO DE TANQUE',
    label: 'MOBILIZAÇÃO/DESMOBILIZAÇÃO DE TANQUE',
  ),
  ActivityChoiceItem(
    value: 'SERVIÇO DE MONITORAMENTO OCUPACIONAL',
    label: 'SERVIÇO DE MONITORAMENTO OCUPACIONAL',
  ),
  ActivityChoiceItem(
    value: 'SERVIÇO DE RÁDIO PROTEÇÃO',
    label: 'SERVIÇO DE RÁDIO PROTEÇÃO',
  ),
  ActivityChoiceItem(
    value: 'TRATAMENTO E PINTURA',
    label: 'TRATAMENTO E PINTURA',
  ),
  ActivityChoiceItem(value: 'VISITA TÉCNICA', label: 'VISITA TÉCNICA'),
];

const List<ActivityChoiceItem> _kFallbackMethodChoices = <ActivityChoiceItem>[
  ActivityChoiceItem(value: 'Manual', label: 'Manual'),
  ActivityChoiceItem(value: 'Mecanizada', label: 'Mecanizada'),
  ActivityChoiceItem(value: 'Robotizada', label: 'Robotizada'),
  ActivityChoiceItem(value: 'N/A', label: 'N/A'),
];

const List<ActivityChoiceItem> _kFallbackFunctionChoices = <ActivityChoiceItem>[
  ActivityChoiceItem(value: 'SUPERVISOR', label: 'SUPERVISOR'),
  ActivityChoiceItem(value: 'SUPERVISOR IRATA', label: 'SUPERVISOR IRATA'),
  ActivityChoiceItem(value: 'ELETRICISTA', label: 'ELETRICISTA'),
  ActivityChoiceItem(
    value: 'TÉCNICO DE SEGURANÇA',
    label: 'TÉCNICO DE SEGURANÇA',
  ),
  ActivityChoiceItem(value: 'AJUDANTE', label: 'AJUDANTE'),
  ActivityChoiceItem(value: 'RESGATISTA', label: 'RESGATISTA'),
  ActivityChoiceItem(value: 'MECÂNICO', label: 'MECÂNICO'),
];

const Map<String, String> _kPtToEnKeywords = <String, String>{
  'abertura': 'opening',
  'tanque': 'tank',
  'acesso': 'access',
  'limpeza': 'cleaning',
  'equipe': 'team',
  'almoço': 'lunch',
  'jantar': 'dinner',
  'reunião': 'meeting',
  'espera': 'stand-by',
  'chegada': 'arrival',
  'saída': 'departure',
  'material': 'material',
  'dentro': 'inside',
  'fora': 'outside',
  'manutenção': 'maintenance',
  'instalação': 'setup',
  'treinamento': 'training',
  'segurança': 'safety',
  'drenagem': 'draining',
  'desobstrução': 'clearing',
  'água': 'water',
  'ar': 'air',
  'operação': 'operation',
  'robô': 'robot',
};

const List<_HomologationCase> _kHomologationCases = <_HomologationCase>[
  _HomologationCase(
    id: 'B1',
    title: 'Home carrega OS atribuída',
    description: 'Supervisor vê apenas as OS atribuídas corretamente.',
  ),
  _HomologationCase(
    id: 'B2',
    title: 'OS finalizada bloqueada',
    description: 'OS finalizada não permite iniciar novo RDO.',
  ),
  _HomologationCase(
    id: 'B3',
    title: 'Consolidação de OS duplicada',
    description: 'Mesmo número de OS aparece de forma consolidada.',
  ),
  _HomologationCase(
    id: 'C1',
    title: 'Formulário completo',
    description: 'Modal supervisor com todos os campos obrigatórios do RDO.',
  ),
  _HomologationCase(
    id: 'C2',
    title: 'Salvar e adicionar tanque',
    description: 'Permite registrar múltiplos tanques no mesmo RDO.',
  ),
  _HomologationCase(
    id: 'C3',
    title: 'Previsão travada',
    description: 'Previsão preenchida uma vez e bloqueada nos próximos RDOs.',
  ),
  _HomologationCase(
    id: 'D1',
    title: 'Autosync',
    description: 'Sincroniza ao abrir, retomar app e no timer automático.',
  ),
  _HomologationCase(
    id: 'D2',
    title: 'Sincronizar agora',
    description: 'Botão manual envia imediatamente itens pendentes.',
  ),
  _HomologationCase(
    id: 'D3',
    title: 'Retry após erro',
    description: 'Reenvio funciona sem duplicar RDO/tanque.',
  ),
  _HomologationCase(
    id: 'F1',
    title: 'RDO aparece no web',
    description: 'RDO do app surge na tabela correta da OS.',
  ),
  _HomologationCase(
    id: 'F2',
    title: 'KPI diário/acumulado',
    description: 'KPIs do web refletem os dados enviados pelo app.',
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({
    required this.repository,
    required this.syncGateway,
    this.bootstrapGateway,
    this.translationGateway,
    this.appUpdateGateway,
    this.mobileRdoPageBaseUrl,
    this.mobileOsRdosBaseUrl,
    this.mobileApiAccessToken,
    this.supervisorLabel,
    this.sessionExpiresAt,
    this.onLogout,
    this.showSeedAction = true,
    super.key,
  });

  final OfflineRdoRepository repository;
  final RdoSyncGateway syncGateway;
  final SupervisorBootstrapGateway? bootstrapGateway;
  final TranslationPreviewGateway? translationGateway;
  final AppUpdateGateway? appUpdateGateway;
  final Uri? mobileRdoPageBaseUrl;
  final Uri? mobileOsRdosBaseUrl;
  final String? mobileApiAccessToken;
  final String? supervisorLabel;
  final DateTime? sessionExpiresAt;
  final Future<void> Function()? onLogout;
  final bool showSeedAction;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final OfflineSyncController _controller;
  final Uuid _uuid = const Uuid();
  static const Duration _autoSyncInterval = Duration(seconds: 45);
  static const Duration _autoSyncThrottle = Duration(seconds: 8);

  Timer? _autoSyncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _autoSyncInFlight = false;
  bool _authRecoveryInProgress = false;
  DateTime? _lastAutoSyncAt;
  DateTime? _lastSyncAttemptAt;
  String? _lastSyncReasonLabel;
  String? _lastSyncOutcomeLabel;
  BackgroundSyncSnapshot? _lastBackgroundSyncSnapshot;
  bool _loggingOut = false;
  Map<String, _HomologationEntry> _homologationEntries =
      <String, _HomologationEntry>{};
  List<AssignedOsItem> _assignedOsItems = const <AssignedOsItem>[];
  List<ActivityChoiceItem> _activityChoices = const <ActivityChoiceItem>[];
  List<ActivityChoiceItem> _serviceChoices = const <ActivityChoiceItem>[];
  List<ActivityChoiceItem> _methodChoices = const <ActivityChoiceItem>[];
  List<ActivityChoiceItem> _personChoices = const <ActivityChoiceItem>[];
  List<ActivityChoiceItem> _functionChoices = const <ActivityChoiceItem>[];
  List<ActivityChoiceItem> _sentidoChoices = const <ActivityChoiceItem>[];
  List<ActivityChoiceItem> _ptTurnosChoices = const <ActivityChoiceItem>[];
  bool _loadingAssignedOs = false;
  String? _assignedOsError;
  int? _selectedAssignedOsId;
  bool _assignedOsFromCache = false;
  DateTime? _assignedOsCachedAt;
  AppUpdateInfo? _availableAppUpdate;
  bool _checkingAppUpdate = false;
  String _installedVersionName = '';
  int _installedBuildNumber = 0;
  bool _showingUpdateDialog = false;
  String? _lastShownUpdateKey;
  bool _hasNetworkConnectivity = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = OfflineSyncController(widget.repository, widget.syncGateway);
    unawaited(BackgroundSyncNotificationService.requestPermissionIfNeeded());
    unawaited(_initializeConnectivityMonitor());
    if (_kHomologationMode) {
      unawaited(_loadHomologationEntries());
    }
    unawaited(_bootstrapPage());
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_triggerAutoSync(reason: 'resume'));
      return;
    }
    if (state == AppLifecycleState.paused) {
      unawaited(BackgroundSyncService.scheduleImmediateSync(reason: 'paused'));
    }
  }

  Future<void> _bootstrapPage() async {
    try {
      await _refreshAll(showLoading: true);
      await _triggerAutoSync(reason: 'startup');
    } finally {
      _startAutoSyncTimer();
    }
  }

  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      unawaited(_triggerAutoSync(reason: 'timer'));
    });
  }

  String _syncReasonLabel(String reason) {
    switch (reason) {
      case 'manual':
        return 'Manual';
      case 'startup':
        return 'Abertura do app';
      case 'resume':
        return 'Retorno ao app';
      case 'timer':
        return 'Auto (timer)';
      case 'connectivity':
        return 'Retorno da internet';
      case 'after_save':
        return 'Após salvar RDO';
      default:
        return reason.trim().isEmpty ? 'Automático' : reason.trim();
    }
  }

  Future<void> _initializeConnectivityMonitor() async {
    final connectivity = Connectivity();
    try {
      final initialResults = await connectivity.checkConnectivity();
      _hasNetworkConnectivity = _isConnectivityAvailable(initialResults);
    } catch (_) {
      _hasNetworkConnectivity = true;
    }

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final hasConnectivity = _isConnectivityAvailable(results);
      final hadConnectivity = _hasNetworkConnectivity;
      if (mounted) {
        setState(() {
          _hasNetworkConnectivity = hasConnectivity;
        });
      } else {
        _hasNetworkConnectivity = hasConnectivity;
      }
      if (hasConnectivity && !hadConnectivity) {
        unawaited(_handleConnectivityRestored());
      }
    });
  }

  bool _isConnectivityAvailable(List<ConnectivityResult> results) {
    for (final result in results) {
      if (result != ConnectivityResult.none) {
        return true;
      }
    }
    return false;
  }

  Future<void> _handleConnectivityRestored() async {
    await BackgroundSyncService.scheduleImmediateSync(reason: 'connectivity');
    await _triggerAutoSync(reason: 'connectivity', force: true);
  }

  void _setSyncAttemptStatus({
    required String reason,
    required String outcome,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _lastSyncAttemptAt = DateTime.now();
      _lastSyncReasonLabel = _syncReasonLabel(reason);
      _lastSyncOutcomeLabel = outcome;
    });
  }

  String _buildSyncOutcomeFromController() {
    if (_controller.errorCount > 0) {
      return 'Concluída com erro em ${_controller.errorCount} item(ns).';
    }
    if (_controller.queuedCount > 0) {
      return 'Concluída parcialmente. Ainda há itens pendentes.';
    }
    return 'Concluída com sucesso.';
  }

  Future<void> _loadHomologationEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHomologationStorageKey);
      if (raw == null || raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final entries = <String, _HomologationEntry>{};
      decoded.forEach((key, value) {
        if (value is! Map) {
          return;
        }
        final id = '$key'.trim();
        if (id.isEmpty) {
          return;
        }
        final status = _homologationStatusFromRaw(value['status']);
        final note = (value['note'] ?? '').toString().trim();
        entries[id] = _HomologationEntry(status: status, note: note);
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _homologationEntries = entries;
      });
    } catch (_) {
      // Falha de leitura da checklist não deve travar a Home.
    }
  }

  Future<void> _persistHomologationEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, Map<String, String>>{};
      _homologationEntries.forEach((key, value) {
        payload[key] = <String, String>{
          'status': value.status.name,
          'note': value.note.trim(),
        };
      });
      await prefs.setString(_kHomologationStorageKey, jsonEncode(payload));
    } catch (_) {
      // Não bloqueia fluxo principal por falha de persistência do checklist.
    }
  }

  _HomologationSummary _computeHomologationSummary(
    Map<String, _HomologationEntry> source,
  ) {
    var ok = 0;
    var nok = 0;
    var na = 0;
    var pending = 0;
    for (final testCase in _kHomologationCases) {
      final status = source[testCase.id]?.status ?? _HomologationStatus.pending;
      switch (status) {
        case _HomologationStatus.ok:
          ok += 1;
          break;
        case _HomologationStatus.nok:
          nok += 1;
          break;
        case _HomologationStatus.na:
          na += 1;
          break;
        case _HomologationStatus.pending:
          pending += 1;
          break;
      }
    }
    return _HomologationSummary(ok: ok, nok: nok, na: na, pending: pending);
  }

  Future<void> _openHomologationChecklist() async {
    if (!mounted) {
      return;
    }

    var working = <String, _HomologationEntry>{..._homologationEntries};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final summary = _computeHomologationSummary(working);
            final reportText = _buildHomologationReport(working);

            Future<void> editNote(String caseId) async {
              final current = working[caseId];
              final controller = TextEditingController(
                text: current?.note ?? '',
              );
              final saved = await showDialog<String>(
                context: context,
                builder: (dialogCtx) {
                  return AlertDialog(
                    title: const Text('Observação do teste'),
                    content: TextField(
                      controller: controller,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Descreva o resultado ou problema encontrado',
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(dialogCtx).pop(controller.text.trim()),
                        child: const Text('Salvar'),
                      ),
                    ],
                  );
                },
              );
              if (saved == null) {
                return;
              }
              final base = working[caseId] ?? const _HomologationEntry();
              setModalState(() {
                working[caseId] = base.copyWith(note: saved);
              });
            }

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.92,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 5,
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD3D8DE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Checklist Parte 1',
                                style: TextStyle(
                                  color: _kInk,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _HomologationBadge(
                              text:
                                  '${summary.done}/${_kHomologationCases.length}',
                              color: AppTheme.supervisorLime.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: <Widget>[
                            _HomologationBadge(
                              text: 'OK ${summary.ok}',
                              color: const Color(0xFFE7F8D1),
                            ),
                            const SizedBox(width: 8),
                            _HomologationBadge(
                              text: 'NOK ${summary.nok}',
                              color: const Color(0xFFFFE3E3),
                            ),
                            const SizedBox(width: 8),
                            _HomologationBadge(
                              text: 'NA ${summary.na}',
                              color: const Color(0xFFEAEFF4),
                            ),
                            const SizedBox(width: 8),
                            _HomologationBadge(
                              text: 'Pend. ${summary.pending}',
                              color: const Color(0xFFF4F6F9),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          itemCount: _kHomologationCases.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final testCase = _kHomologationCases[index];
                            final entry =
                                working[testCase.id] ??
                                const _HomologationEntry();
                            return Container(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kCardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        testCase.id,
                                        style: const TextStyle(
                                          color: _kInk,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          testCase.title,
                                          style: const TextStyle(
                                            color: _kInk,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => editNote(testCase.id),
                                        icon: Icon(
                                          entry.note.trim().isEmpty
                                              ? Icons.note_add_outlined
                                              : Icons.sticky_note_2_rounded,
                                          size: 20,
                                          color: _kMutedInk,
                                        ),
                                        tooltip: 'Observação',
                                      ),
                                    ],
                                  ),
                                  Text(
                                    testCase.description,
                                    style: const TextStyle(
                                      color: _kMutedInk,
                                      fontSize: 12.3,
                                    ),
                                  ),
                                  if (entry.note.trim().isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F8FA),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _kCardBorder),
                                      ),
                                      child: Text(
                                        entry.note,
                                        style: const TextStyle(
                                          color: _kMutedInk,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    children: <Widget>[
                                      _HomologationChoiceChip(
                                        label: 'Pendente',
                                        selected:
                                            entry.status ==
                                            _HomologationStatus.pending,
                                        onTap: () {
                                          setModalState(() {
                                            working[testCase.id] = entry
                                                .copyWith(
                                                  status: _HomologationStatus
                                                      .pending,
                                                );
                                          });
                                        },
                                      ),
                                      _HomologationChoiceChip(
                                        label: 'OK',
                                        selected:
                                            entry.status ==
                                            _HomologationStatus.ok,
                                        onTap: () {
                                          setModalState(() {
                                            working[testCase.id] = entry
                                                .copyWith(
                                                  status:
                                                      _HomologationStatus.ok,
                                                );
                                          });
                                        },
                                      ),
                                      _HomologationChoiceChip(
                                        label: 'NOK',
                                        selected:
                                            entry.status ==
                                            _HomologationStatus.nok,
                                        onTap: () {
                                          setModalState(() {
                                            working[testCase.id] = entry
                                                .copyWith(
                                                  status:
                                                      _HomologationStatus.nok,
                                                );
                                          });
                                        },
                                      ),
                                      _HomologationChoiceChip(
                                        label: 'NA',
                                        selected:
                                            entry.status ==
                                            _HomologationStatus.na,
                                        onTap: () {
                                          setModalState(() {
                                            working[testCase.id] = entry
                                                .copyWith(
                                                  status:
                                                      _HomologationStatus.na,
                                                );
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: _kCardBorder)),
                        ),
                        child: Row(
                          children: <Widget>[
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  working = <String, _HomologationEntry>{};
                                });
                              },
                              child: const Text('Limpar'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: reportText),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Relatório copiado para área de transferência.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copiar relatório'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Fechar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _homologationEntries = working;
    });
    await _persistHomologationEntries();
  }

  String _buildHomologationReport(Map<String, _HomologationEntry> source) {
    final summary = _computeHomologationSummary(source);
    final lines = <String>[];
    lines.add('Homologação Parte 1 - ${DateTime.now().toIso8601String()}');
    lines.add('OK: ${summary.ok}');
    lines.add('NOK: ${summary.nok}');
    lines.add('NA: ${summary.na}');
    lines.add('Pendentes: ${summary.pending}');
    lines.add('');
    for (final testCase in _kHomologationCases) {
      final entry = source[testCase.id] ?? const _HomologationEntry();
      lines.add(
        '${testCase.id} - ${testCase.title}: ${entry.status.name.toUpperCase()}',
      );
      if (entry.note.trim().isNotEmpty) {
        lines.add('Obs: ${entry.note.trim()}');
      }
    }
    return lines.join('\n');
  }

  bool _hasBlockingAuthError({DateTime? updatedAfter}) {
    for (final item in _controller.items) {
      if (!_isPendingState(item.state)) {
        continue;
      }
      if (updatedAfter != null) {
        final updatedAt = item.updatedAt;
        if (updatedAt == null || updatedAt.isBefore(updatedAfter)) {
          continue;
        }
      }
      final raw = item.lastError;
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }
      if (_isAuthFailureMessage(raw)) {
        return true;
      }
    }
    return false;
  }

  bool _isAuthFailureMessage(String raw) {
    final message = raw.toLowerCase();
    return message.contains('sessão inválida') ||
        message.contains('sessao invalida') ||
        message.contains('sessão expirada') ||
        message.contains('sessao expirada') ||
        message.contains('token expirado') ||
        message.contains('token inválido') ||
        message.contains('token invalido') ||
        message.contains('autenticação requerida') ||
        message.contains('autenticacao requerida') ||
        message.contains('não autorizado') ||
        message.contains('nao autorizado') ||
        message.contains('acesso negado');
  }

  bool _isAuthFailureError(Object err) {
    try {
      final dynamic dynamicError = err;
      final dynamic statusCode = dynamicError.statusCode;
      if (statusCode is int && (statusCode == 401 || statusCode == 403)) {
        return true;
      }
    } catch (_) {
      // Ignora erros de reflexão em exceções sem statusCode.
    }
    return _isAuthFailureMessage('$err');
  }

  Future<void> _triggerAuthRecovery({String? reason}) async {
    if (!mounted || _authRecoveryInProgress) {
      return;
    }
    if (widget.onLogout == null) {
      return;
    }
    _authRecoveryInProgress = true;
    try {
      final feedback = (reason ?? '').trim();
      if (feedback.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(feedback)));
      }
      await _handleLogout();
    } finally {
      _authRecoveryInProgress = false;
    }
  }

  Future<void> _triggerAutoSync({
    required String reason,
    bool force = false,
  }) async {
    if (!mounted || _autoSyncInFlight || _controller.busy) {
      return;
    }
    if (_authRecoveryInProgress) {
      return;
    }
    if (_controller.queuedCount <= 0) {
      return;
    }

    final now = DateTime.now();
    final last = _lastAutoSyncAt;
    if (!force && last != null && now.difference(last) < _autoSyncThrottle) {
      return;
    }

    _autoSyncInFlight = true;
    _lastAutoSyncAt = now;
    _setSyncAttemptStatus(reason: reason, outcome: 'Sincronizando...');

    try {
      final syncStartedAt = DateTime.now();
      await _repairOrphanedRdoDependenciesIfPossible();
      await _controller.syncQueuedItems();
      if (_hasBlockingAuthError(updatedAfter: syncStartedAt)) {
        _setSyncAttemptStatus(
          reason: reason,
          outcome: 'Falhou: sessão expirada.',
        );
        await _triggerAuthRecovery(
          reason: 'Sessão expirada. Faça login novamente para sincronizar.',
        );
        return;
      }
      _setSyncAttemptStatus(
        reason: reason,
        outcome: _buildSyncOutcomeFromController(),
      );
      if (reason != 'manual' &&
          _controller.lastRoundSuccessRdoCount > 0 &&
          _controller.lastRoundSuccessCount > 0 &&
          _controller.errorCount == 0 &&
          _controller.queuedCount == 0) {
        unawaited(
          BackgroundSyncNotificationService.showSyncSuccess(
            rdoCount: _controller.lastRoundSuccessRdoCount,
            operationCount: _controller.lastRoundSuccessCount,
          ),
        );
      }
      await _loadAssignedOs();
    } finally {
      _autoSyncInFlight = false;
    }
  }

  Future<void> _handleLogout() async {
    final action = widget.onLogout;
    if (action == null || _loggingOut) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  Future<void> _refreshAll({bool showLoading = false}) async {
    await _ensureInstalledVersionLoaded();
    await Future.wait(<Future<void>>[
      _controller.loadQueue(),
      _loadAssignedOs(showLoading: showLoading),
      _loadBackgroundSyncSnapshot(),
      _checkForAppUpdate(),
    ]);
  }

  Future<void> _ensureInstalledVersionLoaded() async {
    if (_installedBuildNumber > 0 || _installedVersionName.trim().isNotEmpty) {
      return;
    }
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versionName = packageInfo.version.trim();
      final buildNumber = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;
      if (!mounted) {
        _installedVersionName = versionName;
        _installedBuildNumber = buildNumber;
        return;
      }
      setState(() {
        _installedVersionName = versionName;
        _installedBuildNumber = buildNumber;
      });
    } catch (_) {
      // Falha na leitura de versão local não bloqueia o app.
    }
  }

  bool _hasNewerAppVersion(AppUpdateInfo update) {
    if (!update.available || update.downloadUrl.trim().isEmpty) {
      return false;
    }

    final latestBuild = update.buildNumber;
    if (latestBuild > 0 && _installedBuildNumber > 0) {
      return latestBuild > _installedBuildNumber;
    }

    final latestVersion = update.versionName.trim();
    final installedVersion = _installedVersionName.trim();
    if (latestVersion.isNotEmpty && installedVersion.isNotEmpty) {
      return latestVersion != installedVersion;
    }

    return latestBuild > 0 || latestVersion.isNotEmpty;
  }

  Future<void> _checkForAppUpdate() async {
    final gateway = widget.appUpdateGateway;
    if (gateway == null || _checkingAppUpdate) {
      return;
    }
    _checkingAppUpdate = true;
    try {
      final update = await gateway.fetchLatestUpdate(
        platform: _appUpdatePlatform(),
      );
      final nextUpdate = update != null && _hasNewerAppVersion(update)
          ? update
          : null;
      if (!mounted) {
        _availableAppUpdate = nextUpdate;
        return;
      }
      setState(() {
        _availableAppUpdate = nextUpdate;
      });
      if (nextUpdate != null) {
        unawaited(_showAppUpdateDialog(nextUpdate));
      }
    } catch (err) {
      if (_isAuthFailureError(err)) {
        if (mounted) {
          setState(() {
            _availableAppUpdate = null;
          });
        } else {
          _availableAppUpdate = null;
        }
        return;
      }
      // Falhas de rede na checagem de update são silenciosas.
    } finally {
      _checkingAppUpdate = false;
    }
  }

  Future<void> _showAppUpdateDialog(AppUpdateInfo update) async {
    if (!mounted || _showingUpdateDialog) {
      return;
    }
    final key = '${update.versionName.trim()}#${update.buildNumber}';
    if (_lastShownUpdateKey == key) {
      return;
    }
    _lastShownUpdateKey = key;
    _showingUpdateDialog = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Atualização disponível'),
            content: Text(
              'Atual: ${_installedVersionLabel()}\n'
              'Nova: ${_latestVersionLabel(update)}\n\n'
              '${_updateDialogRecommendation()}',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Depois'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_openAppUpdateDownload(update));
                },
                child: const Text('Atualizar agora'),
              ),
            ],
          );
        },
      );
    } finally {
      _showingUpdateDialog = false;
    }
  }

  Future<void> _loadBackgroundSyncSnapshot() async {
    final snapshot = await BackgroundSyncTelemetry.read();
    if (!mounted) {
      _lastBackgroundSyncSnapshot = snapshot;
      return;
    }
    setState(() {
      _lastBackgroundSyncSnapshot = snapshot;
    });
  }

  String _bootstrapCacheKey() {
    final rawUser = (widget.supervisorLabel ?? 'supervisor')
        .trim()
        .toLowerCase();
    final normalized = rawUser
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final suffix = normalized.isEmpty ? 'supervisor' : normalized;
    return '$_kBootstrapCacheStoragePrefix:$suffix';
  }

  Future<void> _saveBootstrapCache(SupervisorBootstrapPayload payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wrapper = <String, dynamic>{
        'cached_at': DateTime.now().toIso8601String(),
        'payload': payload.toJson(),
      };
      await prefs.setString(_bootstrapCacheKey(), jsonEncode(wrapper));
    } catch (_) {
      // Falha de cache não deve impedir o uso do app.
    }
  }

  Future<_BootstrapCacheSnapshot?> _loadBootstrapCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_bootstrapCacheKey());
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final payloadRaw = map['payload'];
      if (payloadRaw is! Map) {
        return null;
      }
      final payload = SupervisorBootstrapPayload.fromJson(
        Map<String, dynamic>.from(payloadRaw),
      );
      final hasUsefulData =
          payload.items.isNotEmpty ||
          payload.activityChoices.isNotEmpty ||
          payload.serviceChoices.isNotEmpty ||
          payload.methodChoices.isNotEmpty ||
          payload.personChoices.isNotEmpty ||
          payload.functionChoices.isNotEmpty;
      if (!hasUsefulData) {
        return null;
      }
      final cachedAt = DateTime.tryParse('${map['cached_at'] ?? ''}');
      return _BootstrapCacheSnapshot(payload: payload, cachedAt: cachedAt);
    } catch (_) {
      return null;
    }
  }

  void _applyBootstrapPayload(
    SupervisorBootstrapPayload bootstrap, {
    required bool fromCache,
    DateTime? cachedAt,
  }) {
    if (!mounted) {
      return;
    }
    final uniqueItems = _deduplicateAssignedOs(bootstrap.items);
    final selected = _resolveSelectedOsId(uniqueItems);
    setState(() {
      _assignedOsItems = uniqueItems;
      _activityChoices = _mergeChoiceLists(
        bootstrap.activityChoices,
        _kFallbackActivityChoices,
        includeFallbackWhenPrimaryEmpty: true,
      );
      _serviceChoices = _mergeChoiceLists(
        bootstrap.serviceChoices,
        _kFallbackServiceChoices,
        includeFallbackWhenPrimaryEmpty: true,
      );
      _methodChoices = _mergeChoiceLists(
        bootstrap.methodChoices,
        _kFallbackMethodChoices,
        includeFallbackWhenPrimaryEmpty: true,
      );
      _personChoices = bootstrap.personChoices;
      _functionChoices = _mergeChoiceLists(
        bootstrap.functionChoices,
        _kFallbackFunctionChoices,
        includeFallbackWhenPrimaryEmpty: true,
      );
      _sentidoChoices = bootstrap.sentidoChoices;
      _ptTurnosChoices = bootstrap.ptTurnosChoices;
      _assignedOsError = null;
      _loadingAssignedOs = false;
      _selectedAssignedOsId = selected;
      _assignedOsFromCache = fromCache;
      _assignedOsCachedAt = cachedAt;
    });
  }

  Future<void> _loadAssignedOs({bool showLoading = false}) async {
    final gateway = widget.bootstrapGateway;
    if (gateway == null) {
      if (mounted) {
        setState(() {
          _assignedOsItems = const <AssignedOsItem>[];
          _activityChoices = const <ActivityChoiceItem>[];
          _serviceChoices = const <ActivityChoiceItem>[];
          _methodChoices = const <ActivityChoiceItem>[];
          _personChoices = const <ActivityChoiceItem>[];
          _functionChoices = const <ActivityChoiceItem>[];
          _sentidoChoices = const <ActivityChoiceItem>[];
          _ptTurnosChoices = const <ActivityChoiceItem>[];
          _assignedOsError = null;
          _loadingAssignedOs = false;
          _selectedAssignedOsId = null;
          _assignedOsFromCache = false;
          _assignedOsCachedAt = null;
        });
      }
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _loadingAssignedOs = true;
        _assignedOsError = null;
      });
    }

    try {
      final bootstrap = await gateway.fetchBootstrap();
      await _saveBootstrapCache(bootstrap);
      _applyBootstrapPayload(
        bootstrap,
        fromCache: false,
        cachedAt: DateTime.now(),
      );
    } catch (err) {
      final authFailure = _isAuthFailureError(err);
      if (!mounted) {
        return;
      }
      if (!authFailure) {
        final cached = await _loadBootstrapCache();
        if (!mounted) {
          return;
        }
        if (cached != null) {
          _applyBootstrapPayload(
            cached.payload,
            fromCache: true,
            cachedAt: cached.cachedAt,
          );
          return;
        }
        if (_assignedOsItems.isNotEmpty) {
          setState(() {
            _assignedOsError = null;
            _loadingAssignedOs = false;
            _assignedOsFromCache = true;
          });
          return;
        }
      }
      setState(() {
        _assignedOsItems = const <AssignedOsItem>[];
        _activityChoices = const <ActivityChoiceItem>[];
        _serviceChoices = const <ActivityChoiceItem>[];
        _methodChoices = const <ActivityChoiceItem>[];
        _personChoices = const <ActivityChoiceItem>[];
        _functionChoices = const <ActivityChoiceItem>[];
        _sentidoChoices = const <ActivityChoiceItem>[];
        _ptTurnosChoices = const <ActivityChoiceItem>[];
        _assignedOsError = authFailure
            ? 'Sessão inválida. Faça login novamente.'
            : '$err\nConecte o app pelo menos uma vez para baixar as OS no aparelho.';
        _loadingAssignedOs = false;
        _selectedAssignedOsId = null;
        _assignedOsFromCache = false;
        _assignedOsCachedAt = null;
      });
      if (authFailure) {
        unawaited(
          _triggerAuthRecovery(
            reason: 'Sessão expirada. Faça login novamente.',
          ),
        );
      }
    }
  }

  int? _resolveSelectedOsId(List<AssignedOsItem> items) {
    if (items.isEmpty) {
      return null;
    }
    final current = _selectedAssignedOsId;
    if (current != null && items.any((item) => item.id == current)) {
      return current;
    }
    for (final item in items) {
      if (!item.isFinalizada) {
        return item.id;
      }
    }
    return items.first.id;
  }

  List<AssignedOsItem> _deduplicateAssignedOs(List<AssignedOsItem> items) {
    if (items.isEmpty) {
      return const <AssignedOsItem>[];
    }
    if (items.length == 1) {
      final only = items.first;
      if (only.isFinalizada) {
        return const <AssignedOsItem>[];
      }
      return items;
    }
    final byKey = <String, AssignedOsItem>{};
    for (final item in items) {
      final normalized = _normalizeOsNumber(item.osNumber);
      final key = normalized.isEmpty ? 'id:${item.id}' : normalized;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = item;
        continue;
      }
      byKey[key] = _mergeAssignedOs(existing, item);
    }
    return byKey.values
        .where((item) => !item.isFinalizada)
        .toList(growable: false);
  }

  AssignedOsItem _mergeAssignedOs(AssignedOsItem a, AssignedOsItem b) {
    final preferred = _pickPreferredAssignedOs(a, b);
    final mergedTanks = <AssignedTankItem>[];
    final seenTankIds = <int>{};
    void appendFrom(List<AssignedTankItem> tanks) {
      for (final tank in tanks) {
        if (seenTankIds.contains(tank.id)) {
          continue;
        }
        seenTankIds.add(tank.id);
        mergedTanks.add(tank);
      }
    }

    appendFrom(a.availableTanks);
    appendFrom(b.availableTanks);
    mergedTanks.sort(
      (x, y) =>
          x.displayLabel.toLowerCase().compareTo(y.displayLabel.toLowerCase()),
    );

    var mergedServicosCount = a.servicosCount;
    if (b.servicosCount > mergedServicosCount) {
      mergedServicosCount = b.servicosCount;
    }

    int? mergedMaxTanques = a.maxTanquesServicos;
    final bMaxTanques = b.maxTanquesServicos;
    if (bMaxTanques != null &&
        (mergedMaxTanques == null || bMaxTanques > mergedMaxTanques)) {
      mergedMaxTanques = bMaxTanques;
    }
    if (mergedServicosCount > 0 &&
        (mergedMaxTanques == null || mergedServicosCount > mergedMaxTanques)) {
      mergedMaxTanques = mergedServicosCount;
    }

    var mergedTotalTanques = a.totalTanquesOs;
    if (b.totalTanquesOs > mergedTotalTanques) {
      mergedTotalTanques = b.totalTanquesOs;
    }
    if (mergedTanks.length > mergedTotalTanques) {
      mergedTotalTanques = mergedTanks.length;
    }

    return preferred.copyWith(
      servicosCount: mergedServicosCount,
      maxTanquesServicos: mergedMaxTanques,
      totalTanquesOs: mergedTotalTanques,
      availableTanks: mergedTanks,
    );
  }

  AssignedOsItem _pickPreferredAssignedOs(AssignedOsItem a, AssignedOsItem b) {
    int score(AssignedOsItem item) {
      var points = 0;
      if (item.canStart == true) {
        points += 100;
      }
      if (item.isEmAndamento) {
        points += 40;
      }
      if (!item.isFinalizada) {
        points += 20;
      }
      return points;
    }

    final aScore = score(a);
    final bScore = score(b);
    if (bScore > aScore) {
      return b;
    }
    if (aScore > bScore) {
      return a;
    }

    final aDate = a.dataInicio ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.dataInicio ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (bDate.isAfter(aDate)) {
      return b;
    }
    return a;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final activeAssignedOs = _resolveActiveAssignedOs();
        final queueGroups = _buildQueueGroups(_controller.items);
        final assignedSummary = activeAssignedOs == null
            ? _resolveAssignedOs(_controller.items)
            : _buildSummaryFromAssigned(activeAssignedOs, _controller.items);

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              color: AppTheme.supervisorDeep,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: _buildHeaderCard(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _buildAssignedOsCard(
                        assignedSummary,
                        activeAssignedOs: activeAssignedOs,
                        assignedItems: _assignedOsItems,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _buildStatusCard(),
                    ),
                  ),
                  if (_availableAppUpdate != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _buildAppUpdateCard(_availableAppUpdate!),
                      ),
                    ),
                  if (_kHomologationMode)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _buildHomologationCard(),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _buildActions(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: _buildQueueTitle(queueGroups.length),
                    ),
                  ),
                  if (queueGroups.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: _buildEmptyState(context),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      sliver: SliverList.separated(
                        itemCount: queueGroups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildQueueGroupCard(queueGroups[index]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    final userLabel = widget.supervisorLabel?.trim().isNotEmpty == true
        ? widget.supervisorLabel!
        : 'supervisor';

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0F1012), Color(0xFF1A1B1F)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.supervisorLime.withValues(alpha: .26),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.supervisorLime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.anchor_rounded, size: 22, color: _kInk),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'ambipar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Synchro',
                      style: TextStyle(
                        color: AppTheme.supervisorLime,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onLogout != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.supervisorLime.withValues(alpha: .3),
                    ),
                  ),
                  child: IconButton(
                    onPressed: _loggingOut ? null : _handleLogout,
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    icon: _loggingOut
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.supervisorLime,
                            ),
                          )
                        : const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.supervisorLime,
                            size: 20,
                          ),
                    tooltip: 'Sair',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.supervisorLime.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AppTheme.supervisorLime.withValues(alpha: .32),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.person_rounded,
                  size: 15,
                  color: AppTheme.supervisorLime,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    userLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final pending = _controller.queuedCount;
    final hasErrors = _controller.errorCount > 0;
    final message = _controller.message;

    IconData icon;
    String title;
    String subtitle;
    Color accentColor;
    Color surfaceColor;

    if (_controller.busy) {
      icon = Icons.sync_rounded;
      title = 'Sincronização em andamento';
      subtitle = 'Aguarde o envio dos dados offline.';
      accentColor = _kInk;
      surfaceColor = _kGreenSoft;
    } else if (hasErrors) {
      icon = Icons.warning_amber_rounded;
      title = 'Falha na sincronização';
      subtitle = 'O app tenta automaticamente; toque para forçar agora.';
      accentColor = _kError;
      surfaceColor = const Color(0xFFFFF1F1);
    } else if (pending > 0) {
      icon = Icons.upload_rounded;
      title = pending == 1
          ? '1 RDO aguardando envio'
          : '$pending RDOs aguardando envio';
      subtitle = 'Envio automático ativo quando houver conexão.';
      accentColor = _kInk;
      surfaceColor = _kGreenSoft;
    } else {
      icon = Icons.task_alt_rounded;
      title = 'Nenhum envio pendente';
      subtitle = 'Todos os RDOs já foram sincronizados.';
      accentColor = _kInk;
      surfaceColor = _kSurfaceSoft;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accentColor.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: _kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _kMutedInk,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (message != null && message.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _kSurfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kCardBorder),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: _kMutedInk,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_lastSyncAttemptAt != null) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _kSurfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kCardBorder),
              ),
              child: Text(
                'Última tentativa: ${_formatDateTime(_lastSyncAttemptAt!)}'
                ' (${_lastSyncReasonLabel ?? 'Automático'})'
                '${_lastSyncOutcomeLabel != null ? ' • ${_lastSyncOutcomeLabel!}' : ''}',
                style: const TextStyle(
                  color: _kMutedInk,
                  fontSize: 12.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildBackgroundSyncIndicator(),
        ],
      ),
    );
  }

  String _installedVersionLabel() {
    final version = _installedVersionName.trim();
    if (version.isNotEmpty) {
      return version;
    }
    if (_installedBuildNumber > 0) {
      return 'build ${_installedBuildNumber.toString()}';
    }
    return 'desconhecida';
  }

  String _latestVersionLabel(AppUpdateInfo update) {
    final version = update.versionName.trim();
    if (version.isNotEmpty) {
      return version;
    }
    if (update.buildNumber > 0) {
      return 'build ${update.buildNumber.toString()}';
    }
    return 'nova versão';
  }

  bool _isIosRuntime() {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _appUpdatePlatform() {
    return _isIosRuntime() ? 'ios' : 'android';
  }

  String _updateDialogRecommendation() {
    if (_isIosRuntime()) {
      return 'Recomendado atualizar agora no iPhone.';
    }
    return 'Recomendado atualizar agora.';
  }

  String _updateButtonLabel() {
    if (_isIosRuntime()) {
      return 'Abrir atualização no iPhone';
    }
    return 'Atualizar aplicativo';
  }

  IconData _updateButtonIcon() {
    if (_isIosRuntime()) {
      return Icons.open_in_new_rounded;
    }
    return Icons.download_rounded;
  }

  String _updateOpenSuccessMessage() {
    if (_isIosRuntime()) {
      return 'Abrindo atualização no iPhone...';
    }
    return 'Abrindo download da atualização...';
  }

  Future<void> _openAppUpdateDownload(AppUpdateInfo update) async {
    final urlRaw = update.downloadUrl.trim();
    final uri = Uri.tryParse(urlRaw);
    if (uri == null || urlRaw.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link de atualização inválido.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) {
      return;
    }
    if (opened) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_updateOpenSuccessMessage())));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir o link de atualização.'),
      ),
    );
  }

  String _mobileAccessToken() {
    return (widget.mobileApiAccessToken ?? '').trim();
  }

  String _dynamicAsString(dynamic raw) {
    if (raw == null) {
      return '';
    }
    return '$raw'.trim();
  }

  int? _dynamicAsInt(dynamic raw) {
    final text = _dynamicAsString(raw);
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text);
  }

  bool? _dynamicAsBool(dynamic raw) {
    final text = _dynamicAsString(raw).toLowerCase();
    if (text.isEmpty) {
      return null;
    }
    if (text == 'true' || text == '1' || text == 'sim' || text == 'yes') {
      return true;
    }
    if (text == 'false' ||
        text == '0' ||
        text == 'nao' ||
        text == 'não' ||
        text == 'no') {
      return false;
    }
    return null;
  }

  Map<String, String> _mobileAuthHeaders() {
    final token = _mobileAccessToken();
    if (token.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Uri? _buildMobileOsRdosUri({required int osId, required String osNumber}) {
    final base = widget.mobileOsRdosBaseUrl;
    if (base == null) {
      return null;
    }
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final query = <String, String>{...base.queryParameters};
    final normalizedOsNumber = osNumber.trim();
    if (normalizedOsNumber.isNotEmpty) {
      query['numero_os'] = normalizedOsNumber;
    }
    final safeOsId = osId > 0 ? osId : 0;
    return base.replace(
      path: '$basePath$safeOsId/rdos/',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Uri? _buildMobileRdoPageUri(int rdoId) {
    final base = widget.mobileRdoPageBaseUrl;
    if (base == null || rdoId <= 0) {
      return null;
    }
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final query = <String, String>{...base.queryParameters, 'auto_export': '1'};
    final token = _mobileAccessToken();
    if (token.isNotEmpty) {
      query['access_token'] = token;
    }
    return base.replace(path: '$basePath$rdoId/page/', queryParameters: query);
  }

  Uri? _buildMobileRdoEditUri(int rdoId) {
    final base = widget.mobileRdoPageBaseUrl;
    if (base == null || rdoId <= 0) {
      return null;
    }
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(path: '$basePath$rdoId/edit/');
  }

  List<_TeamMemberDraft> _parseServerTeamMembers(dynamic rawTeam) {
    if (rawTeam is! List) {
      return const <_TeamMemberDraft>[];
    }
    final out = <_TeamMemberDraft>[];
    for (final row in rawTeam) {
      if (row is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(row);
      out.add(
        _TeamMemberDraft(
          nome: _dynamicAsString(map['nome']),
          funcao: _dynamicAsString(map['funcao']),
          pessoaId: _dynamicAsString(map['pessoa_id']),
          emServico: _dynamicAsBool(map['em_servico']) ?? true,
        ),
      );
    }
    return out;
  }

  _ServerRdoOption? _parseServerRdoOption(Map<String, dynamic> map) {
    final rdoId = int.tryParse('${map['id'] ?? ''}');
    if (rdoId == null || rdoId <= 0) {
      return null;
    }
    final rawSequence = '${map['rdo'] ?? ''}'.trim();
    final sequence = int.tryParse(rawSequence) ?? 0;
    final dateRaw = '${map['data'] ?? map['data_inicio'] ?? ''}'.trim();
    final date = dateRaw.isEmpty ? null : DateTime.tryParse(dateRaw);
    return _ServerRdoOption(
      id: rdoId,
      sequence: sequence,
      businessDate: date,
      teamMembers: _parseServerTeamMembers(map['equipe']),
      reportedPob: _dynamicAsInt(map['pob']),
    );
  }

  Future<List<_ServerRdoOption>> _loadRdosForOs(AssignedOsItem assigned) async {
    final uri = _buildMobileOsRdosUri(
      osId: assigned.id,
      osNumber: assigned.osNumber,
    );
    if (uri == null) {
      return const <_ServerRdoOption>[];
    }
    final headers = _mobileAuthHeaders();
    if (headers.isEmpty) {
      return const <_ServerRdoOption>[];
    }

    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <_ServerRdoOption>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const <_ServerRdoOption>[];
      }
      final rawRdos = decoded['rdos'];
      if (rawRdos is! List) {
        return const <_ServerRdoOption>[];
      }

      final out = <_ServerRdoOption>[];
      for (final row in rawRdos) {
        if (row is! Map) {
          continue;
        }
        final parsed = _parseServerRdoOption(Map<String, dynamic>.from(row));
        if (parsed == null) {
          continue;
        }
        out.add(parsed);
      }
      out.sort((a, b) {
        final aSeq = a.sequence;
        final bSeq = b.sequence;
        if (aSeq > 0 || bSeq > 0) {
          if (bSeq != aSeq) {
            return bSeq.compareTo(aSeq);
          }
        }
        final aDate = a.businessDate;
        final bDate = b.businessDate;
        if (aDate != null && bDate != null) {
          final byDate = bDate.compareTo(aDate);
          if (byDate != 0) {
            return byDate;
          }
        } else if (aDate != null) {
          return -1;
        } else if (bDate != null) {
          return 1;
        }
        return b.id.compareTo(a.id);
      });
      return out;
    } catch (_) {
      return const <_ServerRdoOption>[];
    }
  }

  List<String> _extractMissingDependencyAliases(String? errorMessage) {
    final raw = (errorMessage ?? '').trim();
    if (raw.isEmpty) {
      return const <String>[];
    }
    final match = _kMissingDependenciesPattern.firstMatch(raw);
    if (match == null) {
      return const <String>[];
    }
    final tail = (match.group(1) ?? '').trim();
    if (tail.isEmpty) {
      return const <String>[];
    }
    return tail
        .split(RegExp(r'[,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _replaceRecoveredRdoAliasesInPayload(
    Map<String, dynamic> payload, {
    required Set<String> aliases,
    required int serverRdoId,
  }) {
    dynamic replaceValue(dynamic value) {
      if (value is String) {
        final raw = value.trim();
        for (final alias in aliases) {
          if (raw == '$_kLocalRefPrefix$alias' ||
              raw == '$_kServerRefPrefix$alias') {
            return '$serverRdoId';
          }
        }
        return value;
      }

      if (value is List) {
        return value.map(replaceValue).toList(growable: false);
      }

      if (value is Map) {
        final out = <String, dynamic>{};
        value.forEach((key, nestedValue) {
          out['$key'] = replaceValue(nestedValue);
        });
        return out;
      }

      return value;
    }

    final out = <String, dynamic>{};
    payload.forEach((key, value) {
      if (key == _kMetaDependsOnKey) {
        final filtered = <String>[];
        if (value is List) {
          for (final entry in value) {
            final text = '$entry'.trim();
            if (text.isNotEmpty && !aliases.contains(text)) {
              filtered.add(text);
            }
          }
        } else if (value is Map) {
          for (final entry in value.values) {
            final text = '$entry'.trim();
            if (text.isNotEmpty && !aliases.contains(text)) {
              filtered.add(text);
            }
          }
        } else if (value != null) {
          final text = '$value'.trim();
          if (text.isNotEmpty && !aliases.contains(text)) {
            filtered.add(text);
          }
        }
        if (filtered.isNotEmpty) {
          out[key] = filtered;
        }
        return;
      }
      out[key] = replaceValue(value);
    });
    return out;
  }

  Future<void> _repairOrphanedRdoDependenciesIfPossible() async {
    if (!_hasNetworkConnectivity || !_isOnlineRdoEditConfigured()) {
      return;
    }

    final queue = await widget.repository.listQueue();
    final candidates = queue
        .where((item) {
          return item.state == SyncState.error ||
              item.state == SyncState.conflict;
        })
        .toList(growable: false);
    if (candidates.isEmpty) {
      return;
    }

    final assignedByOs = <String, AssignedOsItem>{
      for (final assigned in _assignedOsItems)
        _normalizeOsNumber(assigned.osNumber): assigned,
    };
    final rdosByOsId = <int, List<_ServerRdoOption>>{};
    var updatedAny = false;

    for (final item in candidates) {
      final missingAliases = _extractMissingDependencyAliases(item.lastError);
      if (missingAliases.isEmpty) {
        continue;
      }
      final rdoAliases = missingAliases
          .where((alias) => alias.toLowerCase().startsWith('rdo_'))
          .toSet();
      if (rdoAliases.isEmpty) {
        continue;
      }

      final assigned = assignedByOs[_normalizeOsNumber(item.osNumber)];
      if (assigned == null) {
        continue;
      }

      final options = rdosByOsId[assigned.id] ??= await _loadRdosForOs(
        assigned,
      );
      if (options.isEmpty) {
        continue;
      }

      _ServerRdoOption? serverRdo;
      for (final option in options) {
        if (option.sequence == item.rdoSequence) {
          serverRdo = option;
          break;
        }
      }
      if (serverRdo == null || serverRdo.id <= 0) {
        continue;
      }

      final repairedPayload = _replaceRecoveredRdoAliasesInPayload(
        item.payload,
        aliases: rdoAliases,
        serverRdoId: serverRdo.id,
      );
      if (jsonEncode(repairedPayload) == jsonEncode(item.payload)) {
        continue;
      }

      await widget.repository.upsert(
        item.copyWith(
          payload: repairedPayload,
          state: SyncState.queued,
          clearLastError: true,
        ),
      );
      updatedAny = true;
    }

    if (updatedAny) {
      await _controller.loadQueue();
    }
  }

  bool _isOnlineRdoEditConfigured() {
    return widget.mobileRdoPageBaseUrl != null &&
        widget.mobileOsRdosBaseUrl != null &&
        _mobileAccessToken().isNotEmpty;
  }

  String? _editRdoUnavailableReason() {
    if (!_isOnlineRdoEditConfigured()) {
      return 'Edição online indisponível: verifique sessão/configuração do app.';
    }
    if (!_hasNetworkConnectivity) {
      return 'Edição disponível apenas online. Conecte-se à internet para continuar.';
    }
    return null;
  }

  String _serverRdoLabel(_ServerRdoOption option) {
    if (option.sequence > 0) {
      return 'RDO ${option.sequence}';
    }
    return 'RDO #${option.id}';
  }

  List<ActivityChoiceItem> _ensureChoiceContainsForEdit(
    List<ActivityChoiceItem> source,
    String current,
  ) {
    final normalized = current.trim();
    if (normalized.isEmpty) {
      return source;
    }
    for (final row in source) {
      if (row.value.trim().toLowerCase() == normalized.toLowerCase()) {
        return source;
      }
    }
    return <ActivityChoiceItem>[
      ActivityChoiceItem(value: normalized, label: normalized),
      ...source,
    ];
  }

  ActivityChoiceItem? _findChoiceByValueForEdit(
    String value,
    List<ActivityChoiceItem> options,
  ) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final row in options) {
      if (row.value.trim().toLowerCase() == normalized) {
        return row;
      }
    }
    return null;
  }

  Widget _buildSearchableChoiceDecoratorForEdit({
    required String labelText,
    required String hintText,
    required String selectedLabel,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.search_rounded),
      ),
      isEmpty: selectedLabel.trim().isEmpty,
      child: Text(
        selectedLabel.trim().isEmpty ? hintText : selectedLabel,
        style: TextStyle(
          color: selectedLabel.trim().isEmpty ? _kMutedInk : _kInk,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<ActivityChoiceItem?> _openChoicePickerForEdit({
    required String title,
    required List<ActivityChoiceItem> options,
    String initialValue = '',
    bool allowManualValue = true,
  }) async {
    final searchController = TextEditingController(text: initialValue.trim());
    try {
      return showModalBottomSheet<ActivityChoiceItem>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (pickerContext) {
          var query = initialValue.trim();
          return StatefulBuilder(
            builder: (pickerContext, setPickerState) {
              final filtered = options
                  .where((item) {
                    final q = query.trim().toLowerCase();
                    if (q.isEmpty) {
                      return true;
                    }
                    return item.label.toLowerCase().contains(q) ||
                        item.value.toLowerCase().contains(q);
                  })
                  .toList(growable: false);

              return FractionallySizedBox(
                heightFactor: 0.82,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: _kInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (value) {
                          setPickerState(() {
                            query = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Buscar',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (allowManualValue && query.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(pickerContext).pop(
                                ActivityChoiceItem(
                                  value: query.trim(),
                                  label: query.trim(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_rounded),
                            label: Text('Usar "${query.trim()}"'),
                          ),
                        ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _kCardBorder),
                                  color: const Color(0xFFF9FAFB),
                                ),
                                child: const Text(
                                  'Nenhum resultado para esta busca.',
                                  style: TextStyle(
                                    color: _kMutedInk,
                                    fontSize: 12.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, context) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final item = filtered[index];
                                  final subtitle =
                                      item.value.trim() == item.label.trim()
                                      ? ''
                                      : item.value.trim();
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      item.label,
                                      style: const TextStyle(
                                        color: _kInk,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: subtitle.isEmpty
                                        ? null
                                        : Text(
                                            subtitle,
                                            style: const TextStyle(
                                              color: _kMutedInk,
                                              fontSize: 11.6,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                    onTap: () =>
                                        Navigator.of(pickerContext).pop(item),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  String _buildTeamCountLabel(
    List<_TeamMemberDraft> teamMembers, {
    int? reportedPob,
  }) {
    final normalized = _normalizeTeamMembers(teamMembers);
    final total = normalized.isNotEmpty
        ? normalized.length
        : (reportedPob ?? 0);
    if (total <= 0) {
      return 'Sem equipe registrada';
    }
    if (total == 1) {
      return '1 membro registrado';
    }
    return '$total membros registrados';
  }

  _TeamSyncRow? _findSupervisorTeamMember(List<_TeamMemberDraft> teamMembers) {
    final normalized = _normalizeTeamMembers(teamMembers);
    if (normalized.isEmpty) {
      return null;
    }
    for (final row in normalized) {
      final role = row.funcao.trim().toUpperCase();
      if (role.contains('SUPERVISOR')) {
        return row;
      }
    }
    for (final row in normalized) {
      if (row.nome.trim().isNotEmpty) {
        return row;
      }
    }
    return normalized.first;
  }

  String _buildTeamPrimaryLabel(
    List<_TeamMemberDraft> teamMembers, {
    int? reportedPob,
  }) {
    final normalized = _normalizeTeamMembers(teamMembers);
    if (normalized.isEmpty) {
      if ((reportedPob ?? 0) > 0) {
        return _buildTeamCountLabel(teamMembers, reportedPob: reportedPob);
      }
      return 'Sem equipe registrada';
    }
    final supervisor = _findSupervisorTeamMember(teamMembers);
    final supervisorName = supervisor?.nome.trim() ?? '';
    if (supervisorName.isNotEmpty) {
      final role = supervisor?.funcao.trim().toUpperCase() ?? '';
      if (role.contains('SUPERVISOR')) {
        return 'Supervisor: $supervisorName';
      }
      return supervisorName;
    }
    return _buildTeamCountLabel(teamMembers, reportedPob: reportedPob);
  }

  String _buildTeamSecondaryLabel(
    List<_TeamMemberDraft> teamMembers, {
    int? reportedPob,
  }) {
    final normalized = _normalizeTeamMembers(teamMembers);
    final total = normalized.isNotEmpty
        ? normalized.length
        : (reportedPob ?? 0);
    if (total <= 0) {
      return 'Sem equipe registrada';
    }
    final supervisor = _findSupervisorTeamMember(teamMembers);
    final hasSupervisor =
        supervisor != null &&
        supervisor.nome.trim().isNotEmpty &&
        supervisor.funcao.trim().toUpperCase().contains('SUPERVISOR');
    final remaining = hasSupervisor ? total - 1 : total;
    if (remaining <= 0) {
      return 'Sem outros membros na equipe';
    }
    if (remaining == 1) {
      return '+1 membro na equipe';
    }
    return '+$remaining membros na equipe';
  }

  Future<_ServerRdoOption?> _pickRdoForEdit(
    AssignedOsItem assigned,
    List<_ServerRdoOption> options,
  ) async {
    if (options.isEmpty) {
      return null;
    }
    return showModalBottomSheet<_ServerRdoOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Editar RDO • OS ${assigned.osNumber}',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 16.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecione um RDO já lançado para ajustar apenas data e equipe.',
                  style: TextStyle(
                    color: _kMutedInk,
                    fontSize: 12.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, context) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      final teamPrimaryLabel = _buildTeamPrimaryLabel(
                        option.teamMembers,
                        reportedPob: option.reportedPob,
                      );
                      final teamCountLabel = _buildTeamCountLabel(
                        option.teamMembers,
                        reportedPob: option.reportedPob,
                      );
                      final teamSecondaryLabel = _buildTeamSecondaryLabel(
                        option.teamMembers,
                        reportedPob: option.reportedPob,
                      );
                      final dateLabel = option.businessDate == null
                          ? 'Sem data'
                          : _formatDate(option.businessDate!);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(ctx).pop(option),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kCardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _serverRdoLabel(option),
                                      style: const TextStyle(
                                        color: _kInk,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit_note_rounded,
                                    color: _kInk,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _MetaChip(
                                icon: Icons.calendar_today_rounded,
                                text: dateLabel,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _kCardBorder),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.groups_rounded,
                                        size: 16,
                                        color: _kInk,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            teamCountLabel,
                                            style: const TextStyle(
                                              color: _kInk,
                                              fontSize: 12.4,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            teamPrimaryLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: _kMutedInk,
                                              fontSize: 12.2,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            teamSecondaryLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: _kMutedInk,
                                              fontSize: 11.8,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _saveServerRdoEdit({
    required _ServerRdoOption option,
    required DateTime businessDate,
    required List<_TeamMemberDraft> teamMembers,
  }) async {
    final uri = _buildMobileRdoEditUri(option.id);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endpoint de edição do RDO não configurado.'),
          ),
        );
      }
      return false;
    }

    final headers = <String, String>{
      ..._mobileAuthHeaders(),
      'Content-Type': 'application/json',
    };
    if (headers['Authorization'] == null ||
        headers['Authorization']!.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão do app indisponível para editar o RDO.'),
          ),
        );
      }
      return false;
    }

    final normalizedTeam = _normalizeTeamMembers(teamMembers);
    final payload = <String, dynamic>{
      'data': _formatApiDate(businessDate),
      'data_inicio': _formatApiDate(businessDate),
      'rdo_data_inicio': _formatApiDate(businessDate),
    };
    if (normalizedTeam.isEmpty) {
      payload['equipe_nome[]'] = <String>[''];
      payload['equipe_funcao[]'] = <String>[''];
      payload['equipe_pessoa_id[]'] = <String>[''];
      payload['equipe_em_servico[]'] = <String>['true'];
    } else {
      payload['equipe_nome[]'] = normalizedTeam.map((row) => row.nome).toList();
      payload['equipe_funcao[]'] = normalizedTeam
          .map((row) => row.funcao)
          .toList();
      payload['equipe_pessoa_id[]'] = normalizedTeam
          .map((row) => row.pessoaId)
          .toList();
      payload['equipe_em_servico[]'] = normalizedTeam
          .map((row) => row.emServico ? 'true' : 'false')
          .toList();
    }

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = decoded is Map
            ? '${decoded['error'] ?? 'Falha ao editar o RDO.'}'
            : 'Falha ao editar o RDO.';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
        return false;
      }
      if (decoded is! Map || decoded['success'] != true) {
        final errorMessage = decoded is Map
            ? '${decoded['error'] ?? 'Falha ao editar o RDO.'}'
            : 'Falha ao editar o RDO.';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
        return false;
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar a edição do RDO.'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _openEditRdoSheet(
    AssignedOsItem assigned,
    _ServerRdoOption option,
  ) async {
    DateTime businessDate = option.businessDate ?? DateTime.now();
    final initialTeam = option.teamMembers.isEmpty
        ? <_TeamMemberDraft>[const _TeamMemberDraft()]
        : option.teamMembers
              .map(
                (row) => _TeamMemberDraft(
                  nome: row.nome,
                  funcao: row.funcao,
                  pessoaId: row.pessoaId,
                  emServico: row.emServico,
                ),
              )
              .toList(growable: true);
    final personChoices = _personChoices;
    final functionChoices = _functionChoices;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (modalContext) {
        final modalScrollController = ScrollController();
        final teamMembers = initialTeam;
        var saving = false;
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SingleChildScrollView(
                  controller: modalScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${_serverRdoLabel(option)} • OS ${assigned.osNumber}',
                        style: const TextStyle(
                          color: _kInk,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Edição online restrita: apenas data e equipe.',
                        style: TextStyle(
                          color: _kMutedInk,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: saving
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: modalContext,
                                  initialDate: businessDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked == null) {
                                  return;
                                }
                                setModalState(() {
                                  businessDate = picked;
                                });
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data do RDO',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          child: Text(
                            _formatDate(businessDate),
                            style: const TextStyle(
                              color: _kInk,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Membros da equipe (${teamMembers.length})',
                                  style: const TextStyle(
                                    color: _kMutedInk,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Ajuste somente quem atuou neste RDO.',
                                  style: TextStyle(
                                    color: _kMutedInk,
                                    fontSize: 11.8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: saving || teamMembers.length >= 20
                                ? null
                                : () {
                                    setModalState(() {
                                      teamMembers.add(const _TeamMemberDraft());
                                    });
                                  },
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Adicionar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...teamMembers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        final personOptions = _ensureChoiceContainsForEdit(
                          personChoices,
                          row.nome,
                        );
                        final functionOptions = _ensureChoiceContainsForEdit(
                          functionChoices,
                          row.funcao,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: _kCardBorder),
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Column(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Membro ${index + 1}',
                                      style: const TextStyle(
                                        color: _kInk,
                                        fontSize: 12.6,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remover membro',
                                    onPressed: saving || teamMembers.length <= 1
                                        ? null
                                        : () {
                                            setModalState(() {
                                              teamMembers.removeAt(index);
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.person_remove_alt_1_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: saving
                                    ? null
                                    : () async {
                                        final picked =
                                            await _openChoicePickerForEdit(
                                              title:
                                                  'Selecionar membro da equipe',
                                              options: personOptions,
                                              initialValue: row.nome,
                                              allowManualValue: true,
                                            );
                                        if (picked == null) {
                                          return;
                                        }
                                        final matched =
                                            _findChoiceByValueForEdit(
                                              picked.value,
                                              personOptions,
                                            );
                                        setModalState(() {
                                          teamMembers[index] = row.copyWith(
                                            nome:
                                                matched?.label
                                                        .trim()
                                                        .isNotEmpty ==
                                                    true
                                                ? matched!.label.trim()
                                                : picked.value.trim(),
                                            pessoaId: matched?.value ?? '',
                                          );
                                        });
                                      },
                                child: IgnorePointer(
                                  child: _buildSearchableChoiceDecoratorForEdit(
                                    labelText: 'Nome da pessoa',
                                    hintText: 'Toque para buscar pessoa',
                                    selectedLabel: row.nome.trim().isEmpty
                                        ? ''
                                        : (_findChoiceByValueForEdit(
                                                row.nome,
                                                personOptions,
                                              )?.label ??
                                              row.nome),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: saving
                                    ? null
                                    : () async {
                                        final picked =
                                            await _openChoicePickerForEdit(
                                              title: 'Selecionar função',
                                              options: functionOptions,
                                              initialValue: row.funcao,
                                              allowManualValue: true,
                                            );
                                        if (picked == null) {
                                          return;
                                        }
                                        final matched =
                                            _findChoiceByValueForEdit(
                                              picked.value,
                                              functionOptions,
                                            );
                                        setModalState(() {
                                          teamMembers[index] = row.copyWith(
                                            funcao:
                                                matched?.value ?? picked.value,
                                          );
                                        });
                                      },
                                child: IgnorePointer(
                                  child: _buildSearchableChoiceDecoratorForEdit(
                                    labelText: 'Função',
                                    hintText: 'Toque para buscar função',
                                    selectedLabel: row.funcao.trim().isEmpty
                                        ? ''
                                        : (_findChoiceByValueForEdit(
                                                row.funcao,
                                                functionOptions,
                                              )?.label ??
                                              row.funcao),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  const Expanded(
                                    child: Text(
                                      'Em serviço neste RDO',
                                      style: TextStyle(
                                        color: _kMutedInk,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: row.emServico,
                                    onChanged: saving
                                        ? null
                                        : (value) {
                                            setModalState(() {
                                              teamMembers[index] = row.copyWith(
                                                emServico: value,
                                              );
                                            });
                                          },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(modalContext).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final navigator = Navigator.of(
                                        modalContext,
                                      );
                                      setModalState(() {
                                        saving = true;
                                      });
                                      final saved = await _saveServerRdoEdit(
                                        option: option,
                                        businessDate: businessDate,
                                        teamMembers: teamMembers,
                                      );
                                      if (!mounted) {
                                        return;
                                      }
                                      if (!saved) {
                                        setModalState(() {
                                          saving = false;
                                        });
                                        return;
                                      }
                                      if (navigator.canPop()) {
                                        navigator.pop();
                                      }
                                      await _loadAssignedOs(showLoading: false);
                                      if (!mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${_serverRdoLabel(option)} atualizado com sucesso.',
                                          ),
                                        ),
                                      );
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.supervisorLime,
                                foregroundColor: _kInk,
                              ),
                              icon: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _kInk,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: const Text('Salvar edição'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onEditRdoPressed(AssignedOsItem assigned) async {
    if (!_isOnlineRdoEditConfigured()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Edição online indisponível: verifique sessão/configuração do app.',
            ),
          ),
        );
      }
      return;
    }

    if (!_hasNetworkConnectivity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Conecte-se à internet para editar um RDO já lançado.',
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carregando RDOs lançados...')),
      );
    }
    final options = await _loadRdosForOs(assigned);
    if (!mounted) {
      return;
    }
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum RDO online disponível para edição nesta OS.'),
        ),
      );
      return;
    }

    final selected = await _pickRdoForEdit(assigned, options);
    if (!mounted || selected == null) {
      return;
    }
    await _openEditRdoSheet(assigned, selected);
  }

  Future<List<_ServerRdoOption>?> _pickRdosForExport(
    AssignedOsItem assigned,
    List<_ServerRdoOption> options,
  ) async {
    if (options.isEmpty) {
      return const <_ServerRdoOption>[];
    }
    return showModalBottomSheet<List<_ServerRdoOption>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final selectedIds = <int>{};
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedCount = selectedIds.length;
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.74,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: _kInk,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selecione RDO(s) da OS ${assigned.osNumber}',
                              style: const TextStyle(
                                color: _kInk,
                                fontSize: 14.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                if (selectedIds.length == options.length) {
                                  selectedIds.clear();
                                } else {
                                  selectedIds
                                    ..clear()
                                    ..addAll(options.map((item) => item.id));
                                }
                              });
                            },
                            icon: const Icon(Icons.select_all_rounded),
                            label: Text(
                              selectedIds.length == options.length
                                  ? 'Limpar todos'
                                  : 'Selecionar todos',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$selectedCount selecionado(s)',
                            style: const TextStyle(
                              color: _kMutedInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final option = options[index];
                          final isSelected = selectedIds.contains(option.id);
                          final seqLabel = option.sequence > 0
                              ? 'RDO ${option.sequence}'
                              : 'RDO #${option.id}';
                          final dateLabel = option.businessDate == null
                              ? 'Sem data'
                              : _formatDate(option.businessDate!);
                          return CheckboxListTile(
                            value: isSelected,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (_) {
                              setSheetState(() {
                                if (isSelected) {
                                  selectedIds.remove(option.id);
                                } else {
                                  selectedIds.add(option.id);
                                }
                              });
                            },
                            title: Text(seqLabel),
                            subtitle: Text(dateLabel),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: selectedIds.isEmpty
                                  ? null
                                  : () {
                                      final selected = options
                                          .where(
                                            (item) =>
                                                selectedIds.contains(item.id),
                                          )
                                          .toList(growable: false);
                                      Navigator.of(ctx).pop(selected);
                                    },
                              icon: const Icon(Icons.file_download_outlined),
                              label: Text('Exportar ($selectedCount)'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onExportRdoPdfPressed(AssignedOsItem assigned) async {
    final localSnapshots = await _loadLocalRdoSnapshotsForOs(assigned);
    final canUseOnlineExport = _isOnlinePdfExportConfigured();

    List<_ServerRdoOption> serverOptions = const <_ServerRdoOption>[];
    if (canUseOnlineExport) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carregando RDOs da OS para exportação...'),
          ),
        );
      }
      serverOptions = await _loadRdosForOs(assigned);
      if (!mounted) {
        return;
      }
    }

    if (serverOptions.isNotEmpty) {
      final selectedOptions = await _pickRdosForExport(assigned, serverOptions);
      if (!mounted || selectedOptions == null || selectedOptions.isEmpty) {
        return;
      }
      await _openOnlinePdfExport(selectedOptions);
      return;
    }

    if (localSnapshots.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              canUseOnlineExport
                  ? 'Sem resposta online. Usando exportação offline local.'
                  : 'Modo offline: usando RDOs salvos no aparelho.',
            ),
          ),
        );
      }
      final localOptions = localSnapshots
          .map(
            (snapshot) => _ServerRdoOption(
              id: -snapshot.sequence,
              sequence: snapshot.sequence,
              businessDate: snapshot.businessDate,
            ),
          )
          .toList(growable: false);
      final selectedOptions = await _pickRdosForExport(assigned, localOptions);
      if (!mounted || selectedOptions == null || selectedOptions.isEmpty) {
        return;
      }
      final snapshotsBySequence = <int, _LocalRdoExportSnapshot>{
        for (final snapshot in localSnapshots) snapshot.sequence: snapshot,
      };
      final selectedSnapshots = selectedOptions
          .map((option) => snapshotsBySequence[option.sequence])
          .whereType<_LocalRdoExportSnapshot>()
          .toList(growable: false);
      if (selectedSnapshots.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum RDO local selecionado para exportação.'),
          ),
        );
        return;
      }
      await _exportOfflinePdf(assigned, selectedSnapshots);
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          canUseOnlineExport
              ? 'Nenhum RDO encontrado para esta OS (online ou offline).'
              : 'Nenhum RDO salvo localmente nesta OS. RDOs sincronizados antes desta atualização podem não estar disponíveis offline.',
        ),
      ),
    );
  }

  bool _isOnlinePdfExportConfigured() {
    return widget.mobileRdoPageBaseUrl != null &&
        widget.mobileOsRdosBaseUrl != null &&
        _mobileAccessToken().isNotEmpty;
  }

  Future<void> _openOnlinePdfExport(
    List<_ServerRdoOption> selectedOptions,
  ) async {
    var openedCount = 0;
    for (var index = 0; index < selectedOptions.length; index++) {
      final option = selectedOptions[index];
      final uri = _buildMobileRdoPageUri(option.id);
      if (uri == null) {
        continue;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) {
        openedCount += 1;
      }
      if (index < selectedOptions.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 420));
      }
    }

    if (!mounted) {
      return;
    }
    if (openedCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir a exportação PDF.'),
        ),
      );
      return;
    }
    if (openedCount < selectedOptions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exportação parcial: $openedCount de ${selectedOptions.length} RDO(s) enviados para PDF.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Abrindo exportação de ${selectedOptions.length} RDO(s) em PDF...',
        ),
      ),
    );
  }

  DateTime _queueItemMoment(PendingSyncItem item) {
    return item.updatedAt ?? item.createdAt ?? item.businessDate;
  }

  String _payloadText(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final raw = payload[key];
      if (raw == null) {
        continue;
      }
      if (raw is List) {
        for (final entry in raw) {
          final text = '$entry'.trim();
          if (text.isNotEmpty && text != '-') {
            return text;
          }
        }
        continue;
      }
      final text = '$raw'.trim();
      if (text.isNotEmpty && text != '-') {
        return text;
      }
    }
    return '';
  }

  List<String> _payloadIndexedList(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = payload[key];
      if (raw is List) {
        return raw
            .map((entry) => entry == null ? '' : '$entry'.trim())
            .toList(growable: false);
      }
      if (raw is String) {
        final text = raw.trim();
        if (text.isNotEmpty) {
          return <String>[text];
        }
      }
    }
    return const <String>[];
  }

  String _indexedValue(List<String> values, int index) {
    if (index < 0 || index >= values.length) {
      return '';
    }
    return values[index].trim();
  }

  List<_LocalActivityExportRow> _activitiesFromPayload(
    Map<String, dynamic> payload,
  ) {
    final names = _payloadIndexedList(payload, const <String>[
      'atividade_nome[]',
    ]);
    final starts = _payloadIndexedList(payload, const <String>[
      'atividade_inicio[]',
    ]);
    final ends = _payloadIndexedList(payload, const <String>[
      'atividade_fim[]',
    ]);
    final commentsPt = _payloadIndexedList(payload, const <String>[
      'atividade_comentario_pt[]',
    ]);
    final commentsEn = _payloadIndexedList(payload, const <String>[
      'atividade_comentario_en[]',
    ]);
    var total = names.length;
    if (starts.length > total) {
      total = starts.length;
    }
    if (ends.length > total) {
      total = ends.length;
    }
    if (commentsPt.length > total) {
      total = commentsPt.length;
    }
    if (commentsEn.length > total) {
      total = commentsEn.length;
    }
    if (total <= 0) {
      return const <_LocalActivityExportRow>[];
    }
    final rows = <_LocalActivityExportRow>[];
    for (var index = 0; index < total; index++) {
      final name = _indexedValue(names, index);
      final start = _indexedValue(starts, index);
      final end = _indexedValue(ends, index);
      final commentPt = _indexedValue(commentsPt, index);
      final commentEn = _indexedValue(commentsEn, index);
      if (name.isEmpty &&
          start.isEmpty &&
          end.isEmpty &&
          commentPt.isEmpty &&
          commentEn.isEmpty) {
        continue;
      }
      rows.add(
        _LocalActivityExportRow(
          nome: name,
          inicio: start,
          fim: end,
          comentarioPt: commentPt,
          comentarioEn: commentEn,
        ),
      );
    }
    return rows;
  }

  List<_LocalTeamExportRow> _teamFromPayload(Map<String, dynamic> payload) {
    final names = _payloadIndexedList(payload, const <String>['equipe_nome[]']);
    final roles = _payloadIndexedList(payload, const <String>[
      'equipe_funcao[]',
    ]);
    final inServiceFlags = _payloadIndexedList(payload, const <String>[
      'equipe_em_servico[]',
    ]);
    var total = names.length;
    if (roles.length > total) {
      total = roles.length;
    }
    if (inServiceFlags.length > total) {
      total = inServiceFlags.length;
    }
    if (total <= 0) {
      return const <_LocalTeamExportRow>[];
    }
    final rows = <_LocalTeamExportRow>[];
    for (var index = 0; index < total; index++) {
      final name = _indexedValue(names, index);
      final role = _indexedValue(roles, index);
      final serviceFlag = _indexedValue(inServiceFlags, index);
      final inService =
          serviceFlag == '1' ||
          serviceFlag.toLowerCase() == 'sim' ||
          serviceFlag.toLowerCase() == 'true';
      if (name.isEmpty && role.isEmpty && serviceFlag.isEmpty) {
        continue;
      }
      rows.add(
        _LocalTeamExportRow(nome: name, funcao: role, emServico: inService),
      );
    }
    return rows;
  }

  List<_LocalEcExportRow> _ecRowsFromPayload(Map<String, dynamic> payload) {
    final entradas = _payloadIndexedList(payload, const <String>[
      'entrada_confinado[]',
    ]);
    final saidas = _payloadIndexedList(payload, const <String>[
      'saida_confinado[]',
    ]);
    var total = entradas.length;
    if (saidas.length > total) {
      total = saidas.length;
    }
    if (total <= 0) {
      return const <_LocalEcExportRow>[];
    }
    final rows = <_LocalEcExportRow>[];
    for (var index = 0; index < total; index++) {
      final entrada = _indexedValue(entradas, index);
      final saida = _indexedValue(saidas, index);
      if (entrada.isEmpty && saida.isEmpty) {
        continue;
      }
      rows.add(_LocalEcExportRow(entrada: entrada, saida: saida));
    }
    return rows;
  }

  _LocalTankExportRow? _tankFromPayload(Map<String, dynamic> payload) {
    final idRef = _payloadText(payload, const <String>['tanque_id', 'tank_id']);
    final codigo = _payloadText(payload, const <String>['tanque_codigo']);
    final nome = _payloadText(payload, const <String>[
      'tanque_nome',
      'nome_tanque',
    ]);
    final tipo = _payloadText(payload, const <String>['tipo_tanque']);
    final servico = _payloadText(payload, const <String>['servico_exec']);
    final metodo = _payloadText(payload, const <String>['metodo_exec']);
    if (idRef.isEmpty &&
        codigo.isEmpty &&
        nome.isEmpty &&
        tipo.isEmpty &&
        servico.isEmpty &&
        metodo.isEmpty) {
      return null;
    }
    return _LocalTankExportRow(
      idRef: idRef,
      codigo: codigo,
      nome: nome,
      tipo: tipo,
      servico: servico,
      metodo: metodo,
      espacoConfinado: _payloadText(payload, const <String>[
        'espaco_confinado',
      ]),
      operadores: _payloadText(payload, const <String>[
        'operadores_simultaneos',
      ]),
      h2s: _payloadText(payload, const <String>['h2s_ppm']),
      lel: _payloadText(payload, const <String>['lel']),
      co: _payloadText(payload, const <String>['co_ppm']),
      o2: _payloadText(payload, const <String>['o2_percent']),
      sentido: _payloadText(payload, const <String>[
        'sentido_limpeza',
        'sentido',
      ]),
    );
  }

  Future<List<_LocalRdoExportSnapshot>> _loadLocalRdoSnapshotsForOs(
    AssignedOsItem assigned,
  ) async {
    final queue = await widget.repository.listQueue();
    final normalizedOs = _normalizeOsNumber(assigned.osNumber);
    final grouped = <int, List<PendingSyncItem>>{};
    for (final item in queue) {
      if (_normalizeOsNumber(item.osNumber) != normalizedOs) {
        continue;
      }
      if (item.rdoSequence <= 0) {
        continue;
      }
      grouped
          .putIfAbsent(item.rdoSequence, () => <PendingSyncItem>[])
          .add(item);
    }
    if (grouped.isEmpty) {
      return const <_LocalRdoExportSnapshot>[];
    }

    final snapshots = <_LocalRdoExportSnapshot>[];
    for (final entry in grouped.entries) {
      final sequence = entry.key;
      final items = entry.value.toList(growable: false)
        ..sort((a, b) => _queueItemMoment(a).compareTo(_queueItemMoment(b)));
      if (items.isEmpty) {
        continue;
      }

      final tanks = <_LocalTankExportRow>[];
      var businessDate = items.first.businessDate;
      var state = _resolveGroupState(items);
      var turno = '';
      var observacoesPt = '';
      var observacoesEn = '';
      var planejamentoPt = '';
      var planejamentoEn = '';
      var ptAbertura = '';
      var ptNumManha = '';
      var ptNumTarde = '';
      var ptNumNoite = '';
      var ptTurnos = const <String>[];
      var ecRows = const <_LocalEcExportRow>[];
      var activities = const <_LocalActivityExportRow>[];
      var teamRows = const <_LocalTeamExportRow>[];
      var photoCount = 0;

      for (final item in items) {
        if (item.businessDate.isAfter(businessDate)) {
          businessDate = item.businessDate;
        }
        final payload = item.payload;
        final op = item.operation.toLowerCase();

        if (op == 'rdo.create') {
          final newTurno = _payloadText(payload, const <String>['turno']);
          if (newTurno.isNotEmpty) {
            turno = newTurno;
          }
          final createObsPt = _payloadText(payload, const <String>[
            'observacoes_pt',
            'observacoes',
          ]);
          if (createObsPt.isNotEmpty) {
            observacoesPt = createObsPt;
          }
          final createObsEn = _payloadText(payload, const <String>[
            'observacoes_en',
          ]);
          if (createObsEn.isNotEmpty) {
            observacoesEn = createObsEn;
          }
          final createPlanEn = _payloadText(payload, const <String>[
            'planejamento_en',
          ]);
          if (createPlanEn.isNotEmpty) {
            planejamentoEn = createPlanEn;
          }
          continue;
        }

        if (op == 'rdo.update') {
          final updateTurno = _payloadText(payload, const <String>['turno']);
          if (updateTurno.isNotEmpty) {
            turno = updateTurno;
          }
          final updateObsPt = _payloadText(payload, const <String>[
            'observacoes_pt',
            'observacoes',
          ]);
          if (updateObsPt.isNotEmpty) {
            observacoesPt = updateObsPt;
          }
          final updateObsEn = _payloadText(payload, const <String>[
            'observacoes_en',
          ]);
          if (updateObsEn.isNotEmpty) {
            observacoesEn = updateObsEn;
          }
          final updatePlanPt = _payloadText(payload, const <String>[
            'planejamento_pt',
            'planejamento',
          ]);
          if (updatePlanPt.isNotEmpty) {
            planejamentoPt = updatePlanPt;
          }
          final updatePlanEn = _payloadText(payload, const <String>[
            'planejamento_en',
          ]);
          if (updatePlanEn.isNotEmpty) {
            planejamentoEn = updatePlanEn;
          }
          final updatePtAbertura = _payloadText(payload, const <String>[
            'pt_abertura',
          ]);
          if (updatePtAbertura.isNotEmpty) {
            ptAbertura = updatePtAbertura;
          }
          final updatePtNumManha = _payloadText(payload, const <String>[
            'pt_num_manha',
          ]);
          if (updatePtNumManha.isNotEmpty) {
            ptNumManha = updatePtNumManha;
          }
          final updatePtNumTarde = _payloadText(payload, const <String>[
            'pt_num_tarde',
          ]);
          if (updatePtNumTarde.isNotEmpty) {
            ptNumTarde = updatePtNumTarde;
          }
          final updatePtNumNoite = _payloadText(payload, const <String>[
            'pt_num_noite',
          ]);
          if (updatePtNumNoite.isNotEmpty) {
            ptNumNoite = updatePtNumNoite;
          }

          final updatePtTurnos = _payloadIndexedList(payload, const <String>[
            'pt_turnos[]',
          ]).where((item) => item.trim().isNotEmpty).toList(growable: false);
          if (updatePtTurnos.isNotEmpty) {
            ptTurnos = updatePtTurnos;
          }

          final updateEcRows = _ecRowsFromPayload(payload);
          if (updateEcRows.isNotEmpty) {
            ecRows = updateEcRows;
          }
          final updateActivities = _activitiesFromPayload(payload);
          if (updateActivities.isNotEmpty) {
            activities = updateActivities;
          }
          final updateTeamRows = _teamFromPayload(payload);
          if (updateTeamRows.isNotEmpty) {
            teamRows = updateTeamRows;
          }
          continue;
        }

        if (op == 'rdo.tank.add' || op == 'rdo_add_tank' || op == 'add_tank') {
          final tank = _tankFromPayload(payload);
          if (tank != null) {
            tanks.add(tank);
          }
          continue;
        }

        if (op == 'rdo.photo.upload' || op == 'rdo_photo_upload') {
          photoCount += 1;
        }
      }

      final uniqueTanks = <String, _LocalTankExportRow>{};
      for (final tank in tanks) {
        final key =
            '${tank.idRef}|${tank.codigo.toLowerCase()}|${tank.nome.toLowerCase()}';
        uniqueTanks[key] = tank;
      }

      snapshots.add(
        _LocalRdoExportSnapshot(
          sequence: sequence,
          businessDate: businessDate,
          state: state,
          turno: turno,
          observacoesPt: observacoesPt,
          observacoesEn: observacoesEn,
          planejamentoPt: planejamentoPt,
          planejamentoEn: planejamentoEn,
          ptAbertura: ptAbertura,
          ptNumManha: ptNumManha,
          ptNumTarde: ptNumTarde,
          ptNumNoite: ptNumNoite,
          ptTurnos: ptTurnos,
          ecRows: ecRows,
          tanks: uniqueTanks.values.toList(growable: false),
          activities: activities,
          teamRows: teamRows,
          photoCount: photoCount,
        ),
      );
    }

    snapshots.sort((a, b) {
      if (b.sequence != a.sequence) {
        return b.sequence.compareTo(a.sequence);
      }
      return b.businessDate.compareTo(a.businessDate);
    });
    return snapshots;
  }

  Future<Uint8List> _buildOfflinePdfDocument(
    AssignedOsItem assigned,
    List<_LocalRdoExportSnapshot> snapshots,
  ) async {
    final document = pw.Document();
    final generatedAt = DateTime.now();

    pw.Widget sectionTitle(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
      );
    }

    pw.Widget labelValue(String label, String value) {
      final clean = value.trim().isEmpty ? '-' : value.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 10.2, color: PdfColors.black),
            children: <pw.TextSpan>[
              pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.TextSpan(text: clean),
            ],
          ),
        ),
      );
    }

    String formatDate(DateTime date) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }

    String formatDateTime(DateTime date) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }

    for (final snapshot in snapshots) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),
          build: (pdfContext) {
            final widgets = <pw.Widget>[
              pw.Text(
                'RDO - Exportação Offline',
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Gerado localmente no aplicativo',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.Divider(height: 14, thickness: .6),
              sectionTitle('Identificação'),
              labelValue('OS', assigned.osNumber),
              labelValue('RDO', '${snapshot.sequence}'),
              labelValue('Data', formatDate(snapshot.businessDate)),
              labelValue('Turno', snapshot.turno),
              labelValue('Status sincronização', _stateLabel(snapshot.state)),
              labelValue('Cliente', assigned.cliente),
              labelValue('Unidade', assigned.unidade),
              labelValue('Serviço', assigned.servico),
            ];

            final observacoes = snapshot.observacoesPt.isNotEmpty
                ? snapshot.observacoesPt
                : snapshot.observacoesEn;
            final planejamento = snapshot.planejamentoPt.isNotEmpty
                ? snapshot.planejamentoPt
                : snapshot.planejamentoEn;
            if (observacoes.isNotEmpty || planejamento.isNotEmpty) {
              widgets.add(sectionTitle('Observações e planejamento'));
              if (observacoes.isNotEmpty) {
                widgets.add(labelValue('Observações', observacoes));
              }
              if (planejamento.isNotEmpty) {
                widgets.add(labelValue('Planejamento', planejamento));
              }
            }

            if (snapshot.ptAbertura.isNotEmpty ||
                snapshot.ptTurnos.isNotEmpty ||
                snapshot.ptNumManha.isNotEmpty ||
                snapshot.ptNumTarde.isNotEmpty ||
                snapshot.ptNumNoite.isNotEmpty) {
              widgets.add(sectionTitle('Permissão de trabalho'));
              widgets.add(labelValue('Abertura PT', snapshot.ptAbertura));
              if (snapshot.ptTurnos.isNotEmpty) {
                widgets.add(
                  labelValue('Turnos PT', snapshot.ptTurnos.join(', ')),
                );
              }
              widgets.add(labelValue('PT manhã', snapshot.ptNumManha));
              widgets.add(labelValue('PT tarde', snapshot.ptNumTarde));
              widgets.add(labelValue('PT noite', snapshot.ptNumNoite));
            }

            if (snapshot.ecRows.isNotEmpty) {
              widgets.add(sectionTitle('Espaço confinado'));
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: const <String>['Entrada', 'Saída'],
                  data: snapshot.ecRows
                      .map(
                        (row) => <String>[
                          row.entrada.isEmpty ? '-' : row.entrada,
                          row.saida.isEmpty ? '-' : row.saida,
                        ],
                      )
                      .toList(growable: false),
                  cellStyle: const pw.TextStyle(fontSize: 9.4),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                ),
              );
            }

            if (snapshot.tanks.isNotEmpty) {
              widgets.add(sectionTitle('Tanques'));
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: const <String>[
                    'Código',
                    'Nome',
                    'Tipo',
                    'Serviço',
                    'Método',
                  ],
                  data: snapshot.tanks
                      .map(
                        (tank) => <String>[
                          tank.codigo.isEmpty ? '-' : tank.codigo,
                          tank.nome.isEmpty ? '-' : tank.nome,
                          tank.tipo.isEmpty ? '-' : tank.tipo,
                          tank.servico.isEmpty ? '-' : tank.servico,
                          tank.metodo.isEmpty ? '-' : tank.metodo,
                        ],
                      )
                      .toList(growable: false),
                  cellStyle: const pw.TextStyle(fontSize: 9.2),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                ),
              );
            }

            if (snapshot.activities.isNotEmpty) {
              widgets.add(sectionTitle('Atividades'));
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: const <String>[
                    'Atividade',
                    'Início',
                    'Fim',
                    'Comentário',
                  ],
                  data: snapshot.activities
                      .map(
                        (activity) => <String>[
                          activity.nome.isEmpty ? '-' : activity.nome,
                          activity.inicio.isEmpty ? '-' : activity.inicio,
                          activity.fim.isEmpty ? '-' : activity.fim,
                          activity.comentarioPt.isNotEmpty
                              ? activity.comentarioPt
                              : (activity.comentarioEn.isNotEmpty
                                    ? activity.comentarioEn
                                    : '-'),
                        ],
                      )
                      .toList(growable: false),
                  cellStyle: const pw.TextStyle(fontSize: 9.2),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                ),
              );
            }

            if (snapshot.teamRows.isNotEmpty) {
              widgets.add(sectionTitle('Equipe'));
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: const <String>['Nome', 'Função', 'Em serviço'],
                  data: snapshot.teamRows
                      .map(
                        (member) => <String>[
                          member.nome.isEmpty ? '-' : member.nome,
                          member.funcao.isEmpty ? '-' : member.funcao,
                          member.emServico ? 'Sim' : 'Não',
                        ],
                      )
                      .toList(growable: false),
                  cellStyle: const pw.TextStyle(fontSize: 9.2),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                ),
              );
            }

            widgets.add(sectionTitle('Resumo local'));
            widgets.add(
              labelValue('Fotos vinculadas', '${snapshot.photoCount}'),
            );
            widgets.add(labelValue('Gerado em', formatDateTime(generatedAt)));
            return widgets;
          },
        ),
      );
    }
    return document.save();
  }

  String _offlinePdfFileName(AssignedOsItem assigned) {
    final cleanOs = assigned.osNumber.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '');
    final safeOs = cleanOs.isEmpty ? 'OS' : cleanOs;
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'RDO_OS${safeOs}_offline_$stamp.pdf';
  }

  Future<void> _exportOfflinePdf(
    AssignedOsItem assigned,
    List<_LocalRdoExportSnapshot> snapshots,
  ) async {
    try {
      final pdfBytes = await _buildOfflinePdfDocument(assigned, snapshots);
      final fileName = _offlinePdfFileName(assigned);
      try {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF offline gerado para ${snapshots.length} RDO(s). Escolha onde salvar/compartilhar.',
            ),
          ),
        );
      } catch (_) {
        final docs = await getApplicationDocumentsDirectory();
        final filePath = p.join(docs.path, fileName);
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes, flush: true);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF offline salvo localmente em: $filePath')),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível gerar a exportação PDF offline.'),
        ),
      );
    }
  }

  Widget _buildAppUpdateCard(AppUpdateInfo update) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.supervisorLime.withValues(alpha: .7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.supervisorLime.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: _kInk,
                  size: 20,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Nova versão disponível',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 15.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Atual: ${_installedVersionLabel()} • Nova: ${_latestVersionLabel(update)}',
                      style: const TextStyle(
                        color: _kMutedInk,
                        fontSize: 12.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (update.releaseNotes.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              update.releaseNotes.trim(),
              style: const TextStyle(
                color: _kMutedInk,
                fontSize: 12.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _openAppUpdateDownload(update),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _kInk,
              foregroundColor: Colors.white,
            ),
            icon: Icon(_updateButtonIcon()),
            label: Text(_updateButtonLabel()),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundSyncIndicator() {
    final snapshot = _lastBackgroundSyncSnapshot;
    final Color accentColor;
    final IconData icon;

    if (snapshot == null) {
      accentColor = _kMutedInk;
      icon = Icons.schedule_rounded;
    } else if (snapshot.isError) {
      accentColor = _kError;
      icon = Icons.error_outline_rounded;
    } else if (snapshot.isPartial) {
      accentColor = _kWarning;
      icon = Icons.sync_problem_rounded;
    } else if (snapshot.isSkipped) {
      accentColor = _kMutedInk;
      icon = Icons.pause_circle_outline_rounded;
    } else {
      accentColor = const Color(0xFF4D6F00);
      icon = Icons.task_alt_rounded;
    }

    String title;
    String subtitle;

    if (snapshot == null) {
      title = 'Sincronização em background';
      subtitle = 'Aguardando primeira execução automática no Android.';
    } else {
      title = 'Background: ${snapshot.sourceLabel}';
      subtitle = '${_formatDateTime(snapshot.at)} • ${snapshot.outcome}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kSurfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _kMutedInk,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomologationCard() {
    final summary = _computeHomologationSummary(_homologationEntries);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.fact_check_outlined, size: 18, color: _kInk),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Checklist de homologação',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.done}/${_kHomologationCases.length} itens avaliados'
            ' • OK ${summary.ok} • NOK ${summary.nok} • NA ${summary.na}',
            style: const TextStyle(
              color: _kMutedInk,
              fontSize: 12.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _openHomologationChecklist,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              backgroundColor: AppTheme.supervisorDeep,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            label: const Text('Abrir checklist'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedOsCard(
    _AssignedOsSummary? summary, {
    required AssignedOsItem? activeAssignedOs,
    required List<AssignedOsItem> assignedItems,
  }) {
    Widget? cacheBanner;
    if (_assignedOsFromCache) {
      final subtitle = _assignedOsCachedAt == null
          ? 'Modo offline: usando OS salvas no aparelho.'
          : 'Modo offline: OS locais de ${_formatDateTime(_assignedOsCachedAt!)}.';
      cacheBanner = Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kCardBorder),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, size: 16, color: _kMutedInk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                style: const TextStyle(
                  color: _kMutedInk,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadingAssignedOs) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCardBorder),
        ),
        child: const Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kInk),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Carregando OS atribuídas...',
                style: TextStyle(
                  color: _kInk,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_assignedOsError != null && _assignedOsError!.trim().isNotEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.warning_amber_rounded, size: 18, color: _kWarning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Não foi possível carregar as OS atribuídas.',
                    style: TextStyle(
                      color: _kInk,
                      fontSize: 13.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _assignedOsError!,
              style: const TextStyle(
                color: _kMutedInk,
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadingAssignedOs ? null : _loadAssignedOs,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (summary == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            cacheBanner ?? const SizedBox.shrink(),
            const Row(
              children: <Widget>[
                Icon(Icons.assignment_outlined, size: 18, color: _kInk),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sem OS atribuída no momento.',
                    style: TextStyle(
                      color: _kInk,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final startBlockReason = activeAssignedOs == null
        ? null
        : _resolveStartBlockReason(activeAssignedOs, assignedItems);
    final canExportPdf = activeAssignedOs != null;
    final onlinePdfConfigured = _isOnlinePdfExportConfigured();
    final editRdoUnavailableReason = _editRdoUnavailableReason();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          cacheBanner ?? const SizedBox.shrink(),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.supervisorLime.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'OS #${summary.osNumber}',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1F4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  activeAssignedOs != null && activeAssignedOs.isFinalizada
                      ? 'Finalizada'
                      : 'Atribuída',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.anchor_rounded, size: 18, color: _kInk),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            summary.vessel,
            style: const TextStyle(
              color: _kInk,
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            summary.operationLabel,
            style: const TextStyle(
              color: _kMutedInk,
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (summary.tankLabel != null && summary.tankLabel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.supervisorLime.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.supervisorLime.withValues(alpha: .55),
                  ),
                ),
                child: Text(
                  'Tanque ${summary.tankLabel}',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (assignedItems.length > 1) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assignedItems
                  .map((item) {
                    final selected = item.id == _selectedAssignedOsId;
                    return ChoiceChip(
                      label: Text('OS ${item.osNumber}'),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedAssignedOsId = item.id;
                        });
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildAssignedMetric(
                  label: 'Próximo RDO',
                  value: summary.nextRdo.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAssignedMetric(
                  label: 'Pendentes',
                  value: summary.pendingCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAssignedMetric(
                  label: 'Lançados',
                  value: summary.filledCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Última atualização em ${_formatDate(summary.lastBusinessDate)}',
            style: const TextStyle(
              color: _kMutedInk,
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (activeAssignedOs != null) ...<Widget>[
            const SizedBox(height: 11),
            FilledButton.icon(
              onPressed: _controller.busy || startBlockReason != null
                  ? null
                  : () => _onStartRdoPressed(activeAssignedOs, summary),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: AppTheme.supervisorLime,
                foregroundColor: _kInk,
              ),
              icon: const Icon(Icons.note_add_rounded),
              label: const Text('Iniciar RDO'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _controller.busy || !canExportPdf
                  ? null
                  : () => _onExportRdoPdfPressed(activeAssignedOs),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                foregroundColor: _kInk,
                side: const BorderSide(color: _kCardBorder),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Exportar RDO em PDF'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _controller.busy || editRdoUnavailableReason != null
                  ? null
                  : () => _onEditRdoPressed(activeAssignedOs),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                foregroundColor: _kInk,
                side: const BorderSide(color: _kCardBorder),
              ),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Editar RDO'),
            ),
            if (editRdoUnavailableReason != null) ...<Widget>[
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 14,
                      color: _kMutedInk,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      editRdoUnavailableReason,
                      style: const TextStyle(
                        color: _kMutedInk,
                        fontSize: 11.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (startBlockReason != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                startBlockReason,
                style: const TextStyle(
                  color: _kMutedInk,
                  fontSize: 11.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (!canExportPdf) ...<Widget>[
              const SizedBox(height: 7),
              const Text(
                'Exportação indisponível: verifique sessão/configuração do app.',
                style: TextStyle(
                  color: _kMutedInk,
                  fontSize: 11.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (canExportPdf && !onlinePdfConfigured) ...<Widget>[
              const SizedBox(height: 7),
              const Text(
                'Sem sessão online: exportação será feita usando os RDOs locais do aparelho.',
                style: TextStyle(
                  color: _kMutedInk,
                  fontSize: 11.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: _kSurfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: _kInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _kMutedInk,
              fontSize: 11.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow() async {
    if (_controller.queuedCount <= 0) {
      _setSyncAttemptStatus(
        reason: 'manual',
        outcome: 'Nenhum item pendente para sincronizar.',
      );
      await _loadAssignedOs(showLoading: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum RDO pendente para sincronizar.')),
      );
      return;
    }
    await _triggerAutoSync(reason: 'manual', force: true);
  }

  Widget _buildActions() {
    if (!widget.showSeedAction) {
      return FilledButton.icon(
        onPressed: _controller.busy ? null : _syncNow,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.supervisorLime,
          foregroundColor: _kInk,
        ),
        icon: _controller.busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kInk),
              )
            : const Icon(Icons.sync_rounded),
        label: const Text('Sincronizar agora'),
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _controller.busy ? null : _controller.seedDemoQueue,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kInk,
              side: const BorderSide(color: Color(0xFFBFC5CC)),
            ),
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Gerar fila demo'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _controller.busy ? null : _syncNow,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.supervisorLime,
              foregroundColor: _kInk,
            ),
            icon: _controller.busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kInk,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            label: const Text('Sincronizar agora'),
          ),
        ),
      ],
    );
  }

  List<_QueueRdoGroup> _buildQueueGroups(List<PendingSyncItem> sourceItems) {
    if (sourceItems.isEmpty) {
      return const <_QueueRdoGroup>[];
    }

    final grouped = <String, List<PendingSyncItem>>{};
    for (final item in sourceItems) {
      final normalizedOs = _normalizeOsNumber(item.osNumber);
      final sequence = item.rdoSequence > 0 ? item.rdoSequence : 0;
      final key = sequence > 0
          ? '$normalizedOs::$sequence'
          : '${item.clientUuid.trim()}::fallback';
      grouped.putIfAbsent(key, () => <PendingSyncItem>[]).add(item);
    }

    final out = <_QueueRdoGroup>[];
    for (final entry in grouped.entries) {
      final items = entry.value;
      if (items.isEmpty) {
        continue;
      }

      PendingSyncItem representative = items.first;
      for (final item in items) {
        if (item.operation.toLowerCase() == 'rdo.create') {
          representative = item;
          break;
        }
      }

      var businessDate = representative.businessDate;
      var maxSequence = representative.rdoSequence;
      var retryCount = representative.retryCount;
      var syncedCount = 0;
      String? lastError;

      for (final item in items) {
        if (item.businessDate.isAfter(businessDate)) {
          businessDate = item.businessDate;
        }
        if (item.rdoSequence > maxSequence) {
          maxSequence = item.rdoSequence;
        }
        if (item.retryCount > retryCount) {
          retryCount = item.retryCount;
        }
        if (item.state == SyncState.synced) {
          syncedCount += 1;
        }
        final err = item.lastError?.trim();
        if (err != null && err.isNotEmpty) {
          lastError = err;
        }
      }

      out.add(
        _QueueRdoGroup(
          osNumber: representative.osNumber,
          rdoSequence: maxSequence > 0
              ? maxSequence
              : representative.rdoSequence,
          businessDate: businessDate,
          state: _resolveGroupState(items),
          operationCount: items.length,
          syncedOperationCount: syncedCount,
          retryCount: retryCount,
          lastError: lastError,
        ),
      );
    }

    out.sort((a, b) {
      final byDate = b.businessDate.compareTo(a.businessDate);
      if (byDate != 0) {
        return byDate;
      }
      final byOs = a.osNumber.toLowerCase().compareTo(b.osNumber.toLowerCase());
      if (byOs != 0) {
        return byOs;
      }
      return a.rdoSequence.compareTo(b.rdoSequence);
    });
    return out;
  }

  SyncState _resolveGroupState(List<PendingSyncItem> items) {
    var hasSynced = false;
    for (final item in items) {
      if (item.state == SyncState.syncing) {
        return SyncState.syncing;
      }
      if (item.state == SyncState.conflict) {
        return SyncState.conflict;
      }
      if (item.state == SyncState.error) {
        return SyncState.error;
      }
      if (item.state == SyncState.queued) {
        return SyncState.queued;
      }
      if (item.state == SyncState.draft) {
        return SyncState.draft;
      }
      if (item.state == SyncState.synced) {
        hasSynced = true;
      }
    }
    if (hasSynced) {
      return SyncState.synced;
    }
    return SyncState.queued;
  }

  String _groupProgressLabel(_QueueRdoGroup group) {
    if (group.state == SyncState.synced) {
      return '${group.syncedOperationCount}/${group.operationCount} etapas concluídas';
    }
    if (group.state == SyncState.syncing) {
      return 'Sincronizando ${group.operationCount} etapa(s)';
    }
    final pending = group.operationCount - group.syncedOperationCount;
    final pendingSafe = pending < 0 ? 0 : pending;
    if (pendingSafe <= 1) {
      return '1 etapa pendente';
    }
    return '$pendingSafe etapas pendentes';
  }

  Widget _buildQueueTitle(int groupedCount) {
    return Row(
      children: <Widget>[
        const Icon(Icons.inbox_rounded, size: 20, color: _kInk),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'RDOs no aparelho',
            style: TextStyle(
              color: _kInk,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.supervisorLime.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.supervisorLime.withValues(alpha: 0.8),
            ),
          ),
          child: Text(
            groupedCount.toString(),
            style: const TextStyle(
              color: _kInk,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.supervisorLime.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 30,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Nenhum RDO salvo no aparelho.',
            style: TextStyle(color: _kInk, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Os RDOs sincronizados e offline aparecem aqui para consulta e exportação.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .7),
              fontSize: 12.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueGroupCard(_QueueRdoGroup group) {
    final stateColor = _stateColor(group.state);
    final sequenceLabel = group.rdoSequence > 0 ? '${group.rdoSequence}' : '-';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'OS ${group.osNumber} • RDO $sequenceLabel',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _stateLabel(group.state),
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _MetaChip(
                icon: Icons.layers_outlined,
                text: _groupProgressLabel(group),
              ),
              _MetaChip(
                icon: Icons.calendar_today_outlined,
                text: _formatDate(group.businessDate),
              ),
              if (group.retryCount > 0)
                _MetaChip(
                  icon: Icons.refresh_rounded,
                  text: 'Tentativas ${group.retryCount}',
                ),
            ],
          ),
          if (group.lastError != null &&
              group.lastError!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                group.lastError!,
                style: const TextStyle(
                  color: Color(0xFF7F1D1D),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _stateLabel(SyncState state) {
    switch (state) {
      case SyncState.draft:
        return 'Rascunho';
      case SyncState.queued:
        return 'Na fila';
      case SyncState.syncing:
        return 'Sincronizando';
      case SyncState.synced:
        return 'Sincronizado';
      case SyncState.error:
        return 'Erro';
      case SyncState.conflict:
        return 'Conflito';
    }
  }

  Color _stateColor(SyncState state) {
    switch (state) {
      case SyncState.draft:
        return const Color(0xFF6B7280);
      case SyncState.queued:
        return _kInk;
      case SyncState.syncing:
        return _kInk;
      case SyncState.synced:
        return const Color(0xFF4D6F00);
      case SyncState.error:
        return _kError;
      case SyncState.conflict:
        return _kWarning;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  AssignedOsItem? _resolveActiveAssignedOs() {
    if (_assignedOsItems.isEmpty) {
      return null;
    }
    final selected = _selectedAssignedOsId;
    if (selected != null) {
      for (final item in _assignedOsItems) {
        if (item.id == selected) {
          return item;
        }
      }
    }
    return _assignedOsItems.first;
  }

  int? _resolvePrimaryStartOsId(List<AssignedOsItem> items) {
    if (items.isEmpty) {
      return null;
    }
    for (final item in items) {
      if (item.canStart == true && !item.isFinalizada) {
        return item.id;
      }
    }
    for (final item in items) {
      if (item.isEmAndamento && !item.isFinalizada) {
        return item.id;
      }
    }
    for (final item in items) {
      if (!item.isFinalizada) {
        return item.id;
      }
    }
    return null;
  }

  String? _resolveStartBlockReason(
    AssignedOsItem active,
    List<AssignedOsItem> allItems,
  ) {
    if (active.isFinalizada) {
      return 'OS finalizada. Não é possível iniciar novo RDO.';
    }

    final explicitCanStart = active.canStart;
    if (explicitCanStart == false) {
      final apiReason = active.startBlockReason.trim();
      if (apiReason.isNotEmpty) {
        return apiReason;
      }
    }

    final primaryId = _resolvePrimaryStartOsId(allItems);
    if (primaryId == null) {
      return 'Não há OS liberada para iniciar RDO no momento.';
    }
    if (active.id == primaryId) {
      return null;
    }

    AssignedOsItem? primary;
    for (final item in allItems) {
      if (item.id == primaryId) {
        primary = item;
        break;
      }
    }
    if (primary != null) {
      return 'Supervisor só pode iniciar uma OS por vez. Priorize a OS ${primary.osNumber}.';
    }
    return 'Supervisor só pode iniciar uma OS por vez.';
  }

  _AssignedOsSummary _buildSummaryFromAssigned(
    AssignedOsItem assigned,
    List<PendingSyncItem> items,
  ) {
    final normalizedOs = _normalizeOsNumber(assigned.osNumber);
    final matching = items
        .where((item) => _normalizeOsNumber(item.osNumber) == normalizedOs)
        .toList(growable: false);

    final pendingCount = matching
        .where((item) => _isPendingState(item.state))
        .length;
    final pendingCreateCount = matching
        .where(
          (item) =>
              item.operation.toLowerCase() == 'rdo.create' &&
              _isPendingState(item.state),
        )
        .length;

    var maxLocalRdo = 0;
    for (final item in matching) {
      if (item.rdoSequence > maxLocalRdo) {
        maxLocalRdo = item.rdoSequence;
      }
    }

    final serverNextRdo = assigned.nextRdo ?? 0;
    final serverBaseFromNext = serverNextRdo > 0 ? serverNextRdo - 1 : 0;
    final baseServerRdo = serverBaseFromNext > assigned.rdoCount
        ? serverBaseFromNext
        : assigned.rdoCount;
    final baseRdo = baseServerRdo > maxLocalRdo ? baseServerRdo : maxLocalRdo;
    final nextRdo = baseRdo + 1;

    final vessel = assigned.unidade.trim().isNotEmpty
        ? assigned.unidade.trim()
        : 'Unidade não informada';
    final operationLabel = _composeOperationLabel(assigned);
    var tankLabel = _pickPayloadValue(matching, const <String>[
      'tanque_nome',
      'nome_tanque',
      'tanque_codigo',
      'tanque',
    ]);
    if ((tankLabel == null || tankLabel.trim().isEmpty) &&
        assigned.availableTanks.isNotEmpty) {
      tankLabel = assigned.availableTanks.first.displayLabel;
    }
    final lastBusinessDate = matching.isNotEmpty
        ? _latestItem(matching).businessDate
        : (assigned.dataFim ?? assigned.dataInicio ?? DateTime.now());

    return _AssignedOsSummary(
      osNumber: assigned.osNumber,
      vessel: vessel,
      operationLabel: operationLabel,
      tankLabel: tankLabel,
      pendingCount: pendingCount,
      filledCount: baseServerRdo + pendingCreateCount,
      nextRdo: nextRdo,
      lastBusinessDate: lastBusinessDate,
    );
  }

  String _composeOperationLabel(AssignedOsItem assigned) {
    final cliente = assigned.cliente.trim();
    final servico = assigned.servico.trim();
    if (cliente.isNotEmpty && servico.isNotEmpty) {
      return '$cliente • $servico';
    }
    if (cliente.isNotEmpty) {
      return cliente;
    }
    if (servico.isNotEmpty) {
      return servico;
    }
    return 'Operação em andamento';
  }

  bool _isPendingState(SyncState state) {
    return state == SyncState.queued ||
        state == SyncState.syncing ||
        state == SyncState.error ||
        state == SyncState.conflict;
  }

  String _normalizeOsNumber(String value) {
    return value.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toLowerCase();
  }

  List<ActivityChoiceItem> _mergeChoiceLists(
    List<ActivityChoiceItem> primary,
    List<ActivityChoiceItem> fallback, {
    bool includeFallbackWhenPrimaryEmpty = false,
  }) {
    final merged = <ActivityChoiceItem>[];
    final seen = <String>{};

    void append(List<ActivityChoiceItem> rows) {
      for (final row in rows) {
        final value = row.value.trim();
        final label = row.label.trim();
        if (value.isEmpty && label.isEmpty) {
          continue;
        }
        final key = _normalizeChoiceKey(value.isEmpty ? label : value);
        if (key.isEmpty || seen.contains(key)) {
          continue;
        }
        seen.add(key);
        merged.add(
          ActivityChoiceItem(
            value: value.isEmpty ? label : value,
            label: label.isEmpty ? value : label,
          ),
        );
      }
    }

    append(primary);
    if (!includeFallbackWhenPrimaryEmpty || merged.isEmpty) {
      append(fallback);
    }

    merged.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return merged;
  }

  String _normalizeChoiceKey(String value) {
    return _normalizeTranslationKey(value).replaceAll(RegExp(r'\s+'), ' ');
  }

  String _extractChoicePtLabel(String label) {
    final text = label.trim();
    final slashIndex = text.indexOf('/');
    if (slashIndex <= 0) {
      return text;
    }
    return text.substring(0, slashIndex).trim();
  }

  String _extractChoiceEnLabel(String label) {
    final text = label.trim();
    final slashIndex = text.indexOf('/');
    if (slashIndex < 0 || slashIndex + 1 >= text.length) {
      return '';
    }
    return text.substring(slashIndex + 1).trim();
  }

  String _resolveChoiceEnglishLabel(
    String value,
    List<ActivityChoiceItem> choices,
  ) {
    final lookup = _normalizeChoiceKey(value);
    if (lookup.isEmpty) {
      return '';
    }
    for (final choice in choices) {
      final byValue = _normalizeChoiceKey(choice.value);
      final byPtLabel = _normalizeChoiceKey(
        _extractChoicePtLabel(choice.label),
      );
      if (lookup != byValue && lookup != byPtLabel) {
        continue;
      }
      final en = _extractChoiceEnLabel(choice.label);
      if (en.isNotEmpty) {
        return en;
      }
    }
    return '';
  }

  String _normalizeTranslationKey(String value) {
    var text = value.trim().toLowerCase();
    if (text.isEmpty) {
      return '';
    }
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    replacements.forEach((source, target) {
      text = text.replaceAll(source, target);
    });
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  String _translatePtToEnglishLite(
    String text, {
    required List<ActivityChoiceItem> activityChoices,
    String? activityValue,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) {
      return '';
    }

    final mergedActivities = _mergeChoiceLists(
      activityChoices,
      _kFallbackActivityChoices,
      includeFallbackWhenPrimaryEmpty: true,
    );

    final fromTextChoices = _resolveChoiceEnglishLabel(clean, mergedActivities);
    if (fromTextChoices.isNotEmpty) {
      return fromTextChoices;
    }

    final normalizedClean = _normalizeTranslationKey(clean);
    if (activityValue != null && activityValue.trim().isNotEmpty) {
      final normalizedActivity = _normalizeTranslationKey(activityValue);
      if (normalizedClean == normalizedActivity) {
        final fromActivity = _resolveChoiceEnglishLabel(
          activityValue,
          mergedActivities,
        );
        if (fromActivity.isNotEmpty) {
          return fromActivity;
        }
      }
    }

    for (final row in _kPtToEnKeywords.entries) {
      if (_normalizeTranslationKey(row.key) == normalizedClean &&
          row.value.trim().isNotEmpty) {
        return row.value.trim();
      }
    }

    var translated = clean;
    for (final row in _kPtToEnKeywords.entries) {
      final pattern = RegExp(
        '\\b${RegExp.escape(row.key)}\\b',
        caseSensitive: false,
      );
      translated = translated.replaceAll(pattern, row.value);
    }
    return translated.trim();
  }

  Future<void> _onStartRdoPressed(
    AssignedOsItem assigned,
    _AssignedOsSummary summary,
  ) async {
    final tankCatalog = _buildTankCatalog(assigned, _controller.items);
    final effectiveActivityChoices = _mergeChoiceLists(
      _activityChoices,
      _kFallbackActivityChoices,
      includeFallbackWhenPrimaryEmpty: true,
    );
    final effectiveServiceChoices = _mergeChoiceLists(
      _serviceChoices,
      _kFallbackServiceChoices,
      includeFallbackWhenPrimaryEmpty: true,
    );
    final effectiveMethodChoices = _mergeChoiceLists(
      _methodChoices,
      _kFallbackMethodChoices,
      includeFallbackWhenPrimaryEmpty: true,
    );
    final effectiveFunctionChoices = _mergeChoiceLists(
      _functionChoices,
      _kFallbackFunctionChoices,
      includeFallbackWhenPrimaryEmpty: true,
    );
    final effectivePersonChoices = _personChoices;

    final draft = await _showCreateRdoSheet(
      assigned,
      summary,
      tankCatalog: tankCatalog,
      activityChoices: effectiveActivityChoices,
      serviceChoices: effectiveServiceChoices,
      methodChoices: effectiveMethodChoices,
      personChoices: effectivePersonChoices,
      functionChoices: effectiveFunctionChoices,
      sentidoChoices: _sentidoChoices,
      ptTurnosChoices: _ptTurnosChoices,
    );
    if (draft == null) {
      return;
    }

    final nextRdo = summary.nextRdo;
    final rdoAlias =
        'rdo_os${assigned.id}_seq${nextRdo}_${DateTime.now().millisecondsSinceEpoch}';
    final payload = <String, dynamic>{
      'ordem_servico_id': assigned.id.toString(),
      'rdo_contagem': nextRdo.toString(),
      'data_inicio': _formatApiDate(draft.businessDate),
      'turno': draft.turno,
      _kMetaEntityAliasKey: rdoAlias,
    };
    if (draft.observacoes.trim().isNotEmpty) {
      payload['observacoes_pt'] = draft.observacoes.trim();
    }
    if (draft.observacoesEn.trim().isNotEmpty) {
      payload['observacoes_en'] = draft.observacoesEn.trim();
    }
    if (draft.planejamentoEn.trim().isNotEmpty) {
      payload['planejamento_en'] = draft.planejamentoEn.trim();
    }

    final createItem = PendingSyncItem(
      clientUuid: _uuid.v4(),
      operation: 'rdo.create',
      osNumber: assigned.osNumber,
      rdoSequence: nextRdo,
      businessDate: draft.businessDate,
      payload: payload,
      state: SyncState.queued,
    );
    await widget.repository.upsert(createItem);

    final activityRows = _normalizeActivities(draft.activities);
    final teamRows = _normalizeTeamMembers(draft.teamMembers);
    final tankDrafts = draft.tanks
        .where((item) => item.mode != _TankMode.none)
        .toList(growable: false);
    final includeTankInUpdate = tankDrafts.length == 1;
    final updateDependsOn = <String>{rdoAlias};
    String? updateTankReference;
    var updateTankOperationalPayload = <String, dynamic>{};
    final tankToastLabels = <String>[];

    for (var index = 0; index < tankDrafts.length; index++) {
      final tankDraft = tankDrafts[index];
      final tankOperationalPayload = tankDraft.toPayloadMap();
      switch (tankDraft.mode) {
        case _TankMode.none:
          break;
        case _TankMode.existing:
          final selected = tankDraft.existingTank;
          if (selected == null) {
            continue;
          }
          final tankPayload = <String, dynamic>{
            'rdo_id': '$_kLocalRefPrefix$rdoAlias',
            _kMetaDependsOnKey: <String>[
              rdoAlias,
              if (selected.localAlias != null) selected.localAlias!,
            ],
          };
          if (selected.serverTankId != null) {
            final serverId = selected.serverTankId!;
            tankPayload['tanque_id'] = '$serverId';
            tankPayload['tank_id'] = '$serverId';
            if (includeTankInUpdate) {
              updateTankReference = '$serverId';
            }
          } else if (selected.localAlias != null) {
            final localAlias = selected.localAlias!;
            final localRef = '$_kLocalRefPrefix$localAlias';
            tankPayload['tanque_id'] = localRef;
            tankPayload['tank_id'] = localRef;
            updateDependsOn.add(localAlias);
            if (includeTankInUpdate) {
              updateTankReference = localRef;
            }
          }
          for (final entry in tankOperationalPayload.entries) {
            tankPayload[entry.key] = entry.value;
          }
          if (selected.tanqueCodigo.trim().isNotEmpty) {
            tankPayload['tanque_codigo'] = selected.tanqueCodigo.trim();
          }
          if (selected.tanqueNome.trim().isNotEmpty) {
            tankPayload['tanque_nome'] = selected.tanqueNome.trim();
            tankPayload['nome_tanque'] = selected.tanqueNome.trim();
          }

          final tankItem = PendingSyncItem(
            clientUuid: _uuid.v4(),
            operation: 'rdo.tank.add',
            osNumber: assigned.osNumber,
            rdoSequence: nextRdo,
            businessDate: draft.businessDate,
            payload: tankPayload,
            state: SyncState.queued,
          );
          await widget.repository.upsert(tankItem);
          if (includeTankInUpdate) {
            updateTankOperationalPayload = tankOperationalPayload;
          }
          final label = selected.label.trim();
          if (label.isNotEmpty) {
            tankToastLabels.add(label);
          }
          break;
        case _TankMode.create:
          final tankAlias =
              'tank_${assigned.id}_${nextRdo}_${DateTime.now().microsecondsSinceEpoch}_$index';
          final tankPayload = <String, dynamic>{
            'rdo_id': '$_kLocalRefPrefix$rdoAlias',
            _kMetaEntityAliasKey: tankAlias,
            _kMetaDependsOnKey: <String>[rdoAlias],
          };
          for (final entry in tankOperationalPayload.entries) {
            tankPayload[entry.key] = entry.value;
          }

          final tankItem = PendingSyncItem(
            clientUuid: _uuid.v4(),
            operation: 'rdo.tank.add',
            osNumber: assigned.osNumber,
            rdoSequence: nextRdo,
            businessDate: draft.businessDate,
            payload: tankPayload,
            state: SyncState.queued,
          );
          await widget.repository.upsert(tankItem);
          updateDependsOn.add(tankAlias);
          if (includeTankInUpdate) {
            updateTankReference = '$_kLocalRefPrefix$tankAlias';
            updateTankOperationalPayload = tankOperationalPayload;
          }

          final code = tankDraft.tanqueCodigo.trim();
          final name = tankDraft.tanqueNome.trim();
          final label = code.isNotEmpty
              ? code
              : (name.isNotEmpty ? name : 'Tanque ${index + 1}');
          tankToastLabels.add(label);
          break;
      }
    }

    final updatePayload = <String, dynamic>{
      'rdo_id': '$_kLocalRefPrefix$rdoAlias',
      _kMetaDependsOnKey: updateDependsOn.toList(growable: false),
    };
    void putText(String key, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        updatePayload[key] = trimmed;
      }
    }

    putText('observacoes', draft.observacoes);
    putText('observacoes_pt', draft.observacoes);
    putText('observacoes_en', draft.observacoesEn);
    putText('planejamento', draft.planejamento);
    putText('planejamento_pt', draft.planejamento);
    putText('planejamento_en', draft.planejamentoEn);
    putText('pt_abertura', draft.ptAbertura);
    putText('pt_num_manha', draft.ptNumManha);
    putText('pt_num_tarde', draft.ptNumTarde);
    putText('pt_num_noite', draft.ptNumNoite);

    final ptTurnos = draft.ptTurnos
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (ptTurnos.isNotEmpty) {
      updatePayload['pt_turnos[]'] = ptTurnos;
    }

    final ecEntradas = draft.ecTimes
        .map((row) => row.entradaText)
        .toList(growable: false);
    final ecSaidas = draft.ecTimes
        .map((row) => row.saidaText)
        .toList(growable: false);
    if (ecEntradas.any((item) => item.isNotEmpty) ||
        ecSaidas.any((item) => item.isNotEmpty)) {
      updatePayload['entrada_confinado[]'] = ecEntradas;
      updatePayload['saida_confinado[]'] = ecSaidas;
    }

    if (activityRows.isNotEmpty) {
      updatePayload['atividade_nome[]'] = activityRows
          .map((row) => row.nome)
          .toList(growable: false);
      updatePayload['atividade_inicio[]'] = activityRows
          .map((row) => row.inicio)
          .toList(growable: false);
      updatePayload['atividade_fim[]'] = activityRows
          .map((row) => row.fim)
          .toList(growable: false);
      updatePayload['atividade_comentario_pt[]'] = activityRows
          .map((row) => row.comentarioPt)
          .toList(growable: false);
      updatePayload['atividade_comentario_en[]'] = activityRows
          .map((row) => row.comentarioEn)
          .toList(growable: false);
    }

    if (teamRows.isNotEmpty) {
      updatePayload['equipe_nome[]'] = teamRows
          .map((row) => row.nome)
          .toList(growable: false);
      updatePayload['equipe_funcao[]'] = teamRows
          .map((row) => row.funcao)
          .toList(growable: false);
      updatePayload['equipe_em_servico[]'] = teamRows
          .map((row) => row.emServico ? '1' : '0')
          .toList(growable: false);
      updatePayload['equipe_pessoa_id[]'] = teamRows
          .map((row) => row.pessoaId)
          .toList(growable: false);
      updatePayload['pob'] = '${teamRows.length}';
    }

    if (updateTankOperationalPayload.isNotEmpty) {
      for (final entry in updateTankOperationalPayload.entries) {
        updatePayload[entry.key] = entry.value;
      }
    }

    final normalizedTankRef = updateTankReference?.trim() ?? '';
    if (normalizedTankRef.isNotEmpty) {
      updatePayload['tanque_id'] = normalizedTankRef;
      updatePayload['tank_id'] = normalizedTankRef;
    }

    final hasMeaningfulUpdate = updatePayload.keys.any((key) {
      return key != 'rdo_id' &&
          key != _kMetaDependsOnKey &&
          key != 'tanque_id' &&
          key != 'tank_id';
    });
    if (hasMeaningfulUpdate) {
      final updateItem = PendingSyncItem(
        clientUuid: _uuid.v4(),
        operation: 'rdo.update',
        osNumber: assigned.osNumber,
        rdoSequence: nextRdo,
        businessDate: draft.businessDate,
        payload: updatePayload,
        state: SyncState.queued,
      );
      await widget.repository.upsert(updateItem);
    }

    var queuedPhotoCount = 0;
    for (final photo in draft.photos) {
      final photoPath = photo.path.trim();
      if (photoPath.isEmpty) {
        continue;
      }
      final photoPayload = <String, dynamic>{
        'rdo_id': '$_kLocalRefPrefix$rdoAlias',
        'file_path': photoPath,
        'filename': photo.name.trim(),
        _kMetaDependsOnKey: <String>[rdoAlias],
      };
      final photoItem = PendingSyncItem(
        clientUuid: _uuid.v4(),
        operation: 'rdo.photo.upload',
        osNumber: assigned.osNumber,
        rdoSequence: nextRdo,
        businessDate: draft.businessDate,
        payload: photoPayload,
        state: SyncState.queued,
      );
      await widget.repository.upsert(photoItem);
      queuedPhotoCount += 1;
    }

    await _refreshAll();
    if (!mounted) {
      return;
    }
    final withTankLabel = tankToastLabels.isEmpty
        ? ''
        : tankToastLabels.length == 1
        ? ' com tanque ${tankToastLabels.first}'
        : ' com ${tankToastLabels.length} tanques';
    final withActivityLabel = activityRows.isEmpty
        ? ''
        : ' e ${activityRows.length} atividade(s)';
    final withTeamLabel = teamRows.isEmpty
        ? ''
        : ' e ${teamRows.length} membro(s)';
    final withPhotoLabel = queuedPhotoCount <= 0
        ? ''
        : ' e $queuedPhotoCount foto(s)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'RDO $nextRdo da OS ${assigned.osNumber} salvo offline$withTankLabel$withActivityLabel$withTeamLabel$withPhotoLabel.',
        ),
      ),
    );
    unawaited(
      BackgroundSyncService.scheduleImmediateSync(reason: 'after_save'),
    );
    unawaited(_triggerAutoSync(reason: 'after_save'));
  }

  Future<_CreateRdoDraft?> _showCreateRdoSheet(
    AssignedOsItem assigned,
    _AssignedOsSummary summary, {
    required List<_TankCatalogOption> tankCatalog,
    required List<ActivityChoiceItem> activityChoices,
    required List<ActivityChoiceItem> serviceChoices,
    required List<ActivityChoiceItem> methodChoices,
    required List<ActivityChoiceItem> personChoices,
    required List<ActivityChoiceItem> functionChoices,
    required List<ActivityChoiceItem> sentidoChoices,
    required List<ActivityChoiceItem> ptTurnosChoices,
  }) async {
    DateTime businessDate = DateTime.now();
    String turno = 'Diurno';
    String ptAbertura = '';
    final ptTurnos = <String>{};
    String espacoConfinado = '';
    String sentidoLimpeza = '';
    String tipoTanque = '';
    String? error;
    var isSheetOpen = true;
    final translationTimers = <String, Timer>{};
    final translationVersions = <String, int>{};

    _TankMode tankMode = _TankMode.existing;
    String? selectedTankKey;
    final osTankLimit = _resolveTankCreationLimit(assigned);
    final knownOsTankKeys = _collectKnownTankIdentityKeys(
      assigned,
      tankCatalog,
    );
    final baseOsTankCount = _resolveCurrentOsTankCount(assigned, tankCatalog);

    final observacoesController = TextEditingController();
    final planejamentoController = TextEditingController();
    final observacoesEnController = TextEditingController();
    final planejamentoEnController = TextEditingController();

    final ptManhaController = TextEditingController();
    final ptTardeController = TextEditingController();
    final ptNoiteController = TextEditingController();

    final tanqueCodigoController = TextEditingController();
    final tanqueNomeController = TextEditingController();
    final tanqueCompartimentosController = TextEditingController();
    final tanqueGavetasController = TextEditingController();
    final tanquePatamarController = TextEditingController();
    final tanqueVolumeController = TextEditingController();
    final tanqueServicoController = TextEditingController();
    final tanqueMetodoController = TextEditingController();

    final operadoresController = TextEditingController();
    final efetivoConfinadoController = TextEditingController();
    final h2sController = TextEditingController();
    final lelController = TextEditingController();
    final coController = TextEditingController();
    final o2Controller = TextEditingController();

    final ensacamentoPrevController = TextEditingController();
    final icamentoPrevController = TextEditingController();
    final cambagemPrevController = TextEditingController();

    final tempoBombaController = TextEditingController();
    final bombeioController = TextEditingController();
    final totalLiquidoController = TextEditingController();

    final ensacamentoDiaController = TextEditingController();
    final icamentoDiaController = TextEditingController();
    final cambagemDiaController = TextEditingController();
    final tamboresDiaController = TextEditingController();

    final residuosSolidosController = TextEditingController();
    final residuosTotaisController = TextEditingController();

    final ensacamentoAcuController = TextEditingController();
    final icamentoAcuController = TextEditingController();
    final cambagemAcuController = TextEditingController();
    final tamboresAcuController = TextEditingController();
    final totalLiquidoAcuController = TextEditingController();
    final residuosSolidosAcuController = TextEditingController();

    final limpezaDiariaController = TextEditingController();
    final limpezaFinaDiariaController = TextEditingController();
    final limpezaAcuController = TextEditingController();
    final limpezaFinaAcuController = TextEditingController();

    final activities = <_ActivityDraft>[const _ActivityDraft()];
    final teamMembers = <_TeamMemberDraft>[const _TeamMemberDraft()];
    final ecTimes = List<_EcTimeDraft>.generate(6, (_) => const _EcTimeDraft());
    final photos = <_DraftPhoto>[];
    final imagePicker = ImagePicker();

    final selectedCompartimentos = <int>{};
    final compartmentProgress = <int, _CompartmentProgressDraft>{};
    final previousCompartimentos = <int, _CompartmentProgressDraft>{};
    final stagedTankDrafts = <_TankDraft>[];
    final modalScrollController = ScrollController();
    final tankSectionKey = GlobalKey();
    String compartimentosAvancoJson = '{}';

    double baseEnsacamentoAcu = 0;
    double baseIcamentoAcu = 0;
    double baseCambagemAcu = 0;
    double baseTamboresAcu = 0;
    double baseTotalLiquidoAcu = 0;
    double baseResiduosSolidosAcu = 0;
    double baseLimpezaAcu = 0;
    double baseLimpezaFinaAcu = 0;

    String cleanText(dynamic value) => value == null ? '' : '$value'.trim();

    Set<String> stagedCreatedTankKeys() {
      if (stagedTankDrafts.isEmpty) {
        return const <String>{};
      }
      final keys = <String>{};
      for (final draft in stagedTankDrafts) {
        if (draft.mode != _TankMode.create) {
          continue;
        }
        final key = _buildTankIdentityKey(draft.tanqueCodigo, draft.tanqueNome);
        if (key == null || knownOsTankKeys.contains(key)) {
          continue;
        }
        keys.add(key);
      }
      return keys;
    }

    bool currentDraftConsumesNewTankSlot(String codigo, String nome) {
      final key = _buildTankIdentityKey(codigo, nome);
      if (key == null || knownOsTankKeys.contains(key)) {
        return false;
      }
      return !stagedCreatedTankKeys().contains(key);
    }

    int usedTankCountWithoutCurrentDraft() {
      return baseOsTankCount + stagedCreatedTankKeys().length;
    }

    bool isTankCreationLocked() {
      if (osTankLimit <= 0) {
        return false;
      }
      return usedTankCountWithoutCurrentDraft() >= osTankLimit;
    }

    String tankLimitReachedMessage() {
      final used = usedTankCountWithoutCurrentDraft();
      if (osTankLimit <= 0) {
        return 'Limite de tanques da OS atingido.';
      }
      return 'Limite de $osTankLimit tanque(s) para esta OS atingido ($used/$osTankLimit).';
    }

    Set<String> stagedSelectedTankKeys() {
      if (stagedTankDrafts.isEmpty) {
        return const <String>{};
      }
      final keys = <String>{};
      for (final draft in stagedTankDrafts) {
        final existing = draft.existingTank;
        if (existing != null) {
          keys.add(existing.key);
          continue;
        }
        final logicalKey = _buildTankIdentityKey(
          draft.tanqueCodigo,
          draft.tanqueNome,
        );
        if (logicalKey != null) {
          keys.add(logicalKey);
        }
      }
      return keys;
    }

    List<_TankCatalogOption> availableTankSelectionOptions() {
      if (tankCatalog.isEmpty) {
        return const <_TankCatalogOption>[];
      }
      final stagedKeys = stagedSelectedTankKeys();
      return tankCatalog
          .where((item) => !stagedKeys.contains(item.key))
          .toList(growable: false);
    }

    double parseNumber(dynamic value) {
      final raw = cleanText(
        value,
      ).replaceAll('%', '').replaceAll(',', '.').trim();
      if (raw.isEmpty) {
        return 0;
      }
      return double.tryParse(raw) ?? 0;
    }

    int parseIntValue(dynamic value) {
      final parsed = parseNumber(value);
      if (!parsed.isFinite) {
        return 0;
      }
      return parsed.round();
    }

    double clampPercentDouble(double value) {
      if (!value.isFinite) {
        return 0;
      }
      if (value < 0) {
        return 0;
      }
      if (value > 100) {
        return 100;
      }
      return value;
    }

    String formatDecimal(
      double value, {
      int precision = 2,
      bool trimTrailing = true,
    }) {
      if (!value.isFinite) {
        return '';
      }
      var out = value.toStringAsFixed(precision);
      if (trimTrailing) {
        out = out.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      return out;
    }

    void setControllerText(TextEditingController controller, String value) {
      final normalized = value.trim();
      if (controller.text != normalized) {
        controller.text = normalized;
      }
    }

    void syncForecastFields() {
      setControllerText(icamentoPrevController, ensacamentoPrevController.text);
    }

    TimeOfDay? parseTimeValue(String raw) {
      final input = raw.trim();
      if (input.isEmpty) {
        return null;
      }
      final match = RegExp(r'^([0-1]?\d|2[0-3]):([0-5]\d)$').firstMatch(input);
      if (match == null) {
        return null;
      }
      final hour = int.tryParse(match.group(1) ?? '');
      final minute = int.tryParse(match.group(2) ?? '');
      if (hour == null || minute == null) {
        return null;
      }
      return TimeOfDay(hour: hour, minute: minute);
    }

    bool isSalao() {
      final low = tipoTanque.trim().toLowerCase();
      return low == 'salão' || low == 'salao';
    }

    int resolveNumeroCompartimentos() {
      if (isSalao()) {
        return 1;
      }
      final parsed = parseIntValue(tanqueCompartimentosController.text);
      if (parsed <= 0) {
        return 0;
      }
      if (parsed > 100) {
        return 100;
      }
      return parsed;
    }

    List<ActivityChoiceItem> effectivePtChoices() {
      if (ptTurnosChoices.isNotEmpty) {
        return ptTurnosChoices;
      }
      return const <ActivityChoiceItem>[
        ActivityChoiceItem(value: 'manha', label: 'Manhã'),
        ActivityChoiceItem(value: 'tarde', label: 'Tarde'),
        ActivityChoiceItem(value: 'noite', label: 'Noite'),
      ];
    }

    List<ActivityChoiceItem> ensureChoiceContains(
      List<ActivityChoiceItem> source,
      String current,
    ) {
      final normalized = current.trim();
      if (normalized.isEmpty) {
        return source;
      }
      for (final row in source) {
        if (row.value.trim().toLowerCase() == normalized.toLowerCase()) {
          return source;
        }
      }
      return <ActivityChoiceItem>[
        ActivityChoiceItem(value: normalized, label: normalized),
        ...source,
      ];
    }

    String translateActivityLabelToEn(String value) {
      final fromChoices = _resolveChoiceEnglishLabel(value, activityChoices);
      if (fromChoices.isNotEmpty) {
        return fromChoices;
      }
      return _translatePtToEnglishLite(
        value,
        activityChoices: activityChoices,
        activityValue: value,
      );
    }

    String autoTranslateTextToEn(String value, {String? activityValue}) {
      return _translatePtToEnglishLite(
        value,
        activityChoices: activityChoices,
        activityValue: activityValue,
      );
    }

    void cancelTranslationTimer(String key) {
      final timer = translationTimers.remove(key);
      timer?.cancel();
    }

    void cancelAllTranslationTimers() {
      for (final timer in translationTimers.values) {
        timer.cancel();
      }
      translationTimers.clear();
      translationVersions.clear();
    }

    void scrollToTankSection() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tankContext = tankSectionKey.currentContext;
        if (tankContext == null || !modalScrollController.hasClients) {
          return;
        }
        Scrollable.ensureVisible(
          tankContext,
          alignment: 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    }

    void cancelActivityTranslationTimers() {
      final keys = translationTimers.keys
          .where((key) => key.startsWith('activity_comment_'))
          .toList(growable: false);
      for (final key in keys) {
        cancelTranslationTimer(key);
      }
    }

    int nextTranslationVersion(String key) {
      final next = (translationVersions[key] ?? 0) + 1;
      translationVersions[key] = next;
      return next;
    }

    void scheduleRemoteTranslation({
      required String key,
      required String Function() sourceText,
      String? Function()? activityValue,
      required void Function(String translated) applyTranslatedValue,
      Duration debounce = const Duration(milliseconds: 520),
    }) {
      final localText = sourceText().trim();
      applyTranslatedValue(
        autoTranslateTextToEn(localText, activityValue: activityValue?.call()),
      );

      cancelTranslationTimer(key);

      final gateway = widget.translationGateway;
      if (gateway == null || localText.length < 3) {
        return;
      }

      final version = nextTranslationVersion(key);
      translationTimers[key] = Timer(debounce, () async {
        final snapshot = sourceText().trim();
        if (snapshot.length < 3) {
          return;
        }
        try {
          final translated = (await gateway.translatePtToEn(snapshot)).trim();
          if (!isSheetOpen) {
            return;
          }
          if ((translationVersions[key] ?? 0) != version) {
            return;
          }
          if (sourceText().trim() != snapshot) {
            return;
          }
          final resolved = translated.isNotEmpty
              ? translated
              : autoTranslateTextToEn(
                  snapshot,
                  activityValue: activityValue?.call(),
                );
          applyTranslatedValue(resolved);
        } catch (_) {
          // Mantém fallback local quando não houver tradução remota disponível.
        }
      });
    }

    void syncMainTranslationPreviews() {
      scheduleRemoteTranslation(
        key: 'observacoes',
        sourceText: () => observacoesController.text,
        applyTranslatedValue: (translated) {
          setControllerText(observacoesEnController, translated);
        },
      );
      scheduleRemoteTranslation(
        key: 'planejamento',
        sourceText: () => planejamentoController.text,
        applyTranslatedValue: (translated) {
          setControllerText(planejamentoEnController, translated);
        },
      );
    }

    void scheduleActivityCommentTranslation(
      int index,
      StateSetter setModalState,
    ) {
      scheduleRemoteTranslation(
        key: 'activity_comment_$index',
        sourceText: () {
          if (index < 0 || index >= activities.length) {
            return '';
          }
          return activities[index].comentarioPt;
        },
        activityValue: () {
          if (index < 0 || index >= activities.length) {
            return '';
          }
          return activities[index].nome;
        },
        applyTranslatedValue: (translated) {
          if (!isSheetOpen || index < 0 || index >= activities.length) {
            return;
          }
          final current = activities[index];
          final currentAutoTranslation = autoTranslateTextToEn(
            current.comentarioPt,
            activityValue: current.nome,
          );
          final shouldAutoFillEn =
              current.comentarioEn.trim().isEmpty ||
              current.comentarioEn.trim() == currentAutoTranslation.trim();
          if (!shouldAutoFillEn) {
            return;
          }
          setModalState(() {
            if (index < 0 || index >= activities.length) {
              return;
            }
            final latest = activities[index];
            final latestAutoTranslation = autoTranslateTextToEn(
              latest.comentarioPt,
              activityValue: latest.nome,
            );
            final stillAutoFill =
                latest.comentarioEn.trim().isEmpty ||
                latest.comentarioEn.trim() == latestAutoTranslation.trim();
            if (!stillAutoFill) {
              return;
            }
            activities[index] = latest.copyWith(comentarioEn: translated);
          });
        },
      );
    }

    String sanitizePhotoName(String rawPath, String rawName) {
      final name = rawName.trim();
      if (name.isNotEmpty) {
        return name;
      }
      final normalized = rawPath.replaceAll('\\', '/').trim();
      if (normalized.isEmpty) {
        return 'foto.jpg';
      }
      final parts = normalized.split('/');
      final last = parts.isEmpty ? '' : parts.last.trim();
      return last.isEmpty ? 'foto.jpg' : last;
    }

    String sanitizePhotoFileNameForStorage(String rawName) {
      final base = rawName.trim().isEmpty ? 'foto.jpg' : rawName.trim();
      final normalized = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      if (normalized.isEmpty) {
        return 'foto.jpg';
      }
      return normalized;
    }

    Future<String> resolvePersistentPhotoPath(
      XFile file,
      String photoName,
    ) async {
      final originalPath = file.path.trim();
      if (originalPath.isEmpty) {
        return '';
      }

      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final safeName = sanitizePhotoFileNameForStorage(photoName);
        final persistedPath = p.join(
          docsDir.path,
          'rdo_${DateTime.now().microsecondsSinceEpoch}_$safeName',
        );
        await file.saveTo(persistedPath);
        return persistedPath;
      } catch (_) {
        return originalPath;
      }
    }

    void showPhotoFeedback(String message) {
      if (!mounted || message.trim().isEmpty) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message.trim())));
    }

    Future<void> appendPickedPhotos(
      List<XFile> picked,
      StateSetter setModalState,
    ) async {
      if (picked.isEmpty) {
        return;
      }

      var added = 0;
      var duplicates = 0;
      var skippedNoPath = 0;
      var skippedRead = 0;
      var limitReached = false;

      for (final file in picked) {
        if (!isSheetOpen) {
          return;
        }

        final rawPath = file.path.trim();
        if (rawPath.isEmpty) {
          skippedNoPath += 1;
          continue;
        }

        final name = sanitizePhotoName(rawPath, file.name);
        final path = await resolvePersistentPhotoPath(file, name);
        if (path.trim().isEmpty) {
          skippedNoPath += 1;
          continue;
        }

        Uint8List bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (_) {
          skippedRead += 1;
          continue;
        }
        if (bytes.isEmpty) {
          skippedRead += 1;
          continue;
        }

        final exists = photos.any((item) => item.path == path);
        if (exists) {
          duplicates += 1;
          continue;
        }

        if (photos.length >= _kMaxRdoPhotos) {
          limitReached = true;
          break;
        }

        setModalState(() {
          photos.add(_DraftPhoto(path: path, name: name, bytes: bytes));
        });
        added += 1;
      }

      if (added > 0) {
        showPhotoFeedback(
          added == 1
              ? '1 foto adicionada ao RDO.'
              : '$added fotos adicionadas ao RDO.',
        );
      }
      if (duplicates > 0) {
        showPhotoFeedback(
          duplicates == 1
              ? '1 foto já estava selecionada.'
              : '$duplicates fotos já estavam selecionadas.',
        );
      }
      if (skippedNoPath > 0 || skippedRead > 0) {
        showPhotoFeedback(
          'Algumas fotos não puderam ser carregadas no aparelho.',
        );
      }
      if (limitReached) {
        showPhotoFeedback('Limite de $_kMaxRdoPhotos fotos por RDO atingido.');
      }
    }

    _CompartmentProgressDraft previousCompartmentState(int index) {
      return previousCompartimentos[index] ?? const _CompartmentProgressDraft();
    }

    int previousCompartmentPercent(int index, {required bool fina}) {
      final state = previousCompartmentState(index);
      return fina ? state.fina : state.mecanizada;
    }

    int remainingCompartmentPercent(int index, {required bool fina}) {
      return ((100 - previousCompartmentPercent(index, fina: fina)).clamp(
                0,
                100,
              )
              as num)
          .toInt();
    }

    bool compartmentFrontCompleted(int index, {required bool fina}) {
      return remainingCompartmentPercent(index, fina: fina) <= 0;
    }

    bool compartmentCompleted(int index) {
      return compartmentFrontCompleted(index, fina: false) &&
          compartmentFrontCompleted(index, fina: true);
    }

    String? compartmentAvailabilityLabel(int index) {
      final mecanizadaDone = compartmentFrontCompleted(index, fina: false);
      final finaDone = compartmentFrontCompleted(index, fina: true);
      if (mecanizadaDone && !finaDone) {
        return 'Fina';
      }
      if (!mecanizadaDone && finaDone) {
        return 'Mec.';
      }
      return null;
    }

    ({int previous, int today, int finalValue, int remaining, bool blocked})
    compartmentPhaseSnapshot(int index, {required bool fina}) {
      final previous = previousCompartmentPercent(index, fina: fina);
      final remaining = remainingCompartmentPercent(index, fina: fina);
      final current =
          compartmentProgress[index] ?? const _CompartmentProgressDraft();
      var today = fina ? current.fina : current.mecanizada;
      if (!selectedCompartimentos.contains(index)) {
        today = 0;
      }
      today = ((today).clamp(0, remaining) as num).toInt();
      final finalValue = ((previous + today).clamp(0, 100) as num).toInt();
      return (
        previous: previous,
        today: today,
        finalValue: finalValue,
        remaining: remaining,
        blocked: remaining <= 0,
      );
    }

    ({
      double dailyM,
      double dailyF,
      double cumulativeM,
      double cumulativeF,
      int doneM,
      int doneF,
      int doneBoth,
      int total,
      bool hasPerCompHistory,
    })
    compartmentMetricsSnapshot() {
      final total = resolveNumeroCompartimentos();
      if (total <= 0) {
        return (
          dailyM: 0,
          dailyF: 0,
          cumulativeM: 0,
          cumulativeF: 0,
          doneM: 0,
          doneF: 0,
          doneBoth: 0,
          total: 0,
          hasPerCompHistory: false,
        );
      }

      double sumDayM = 0;
      double sumDayF = 0;
      double sumCumM = 0;
      double sumCumF = 0;
      var doneM = 0;
      var doneF = 0;
      var doneBoth = 0;
      var hasPerCompHistory = false;

      for (var i = 1; i <= total; i++) {
        final prev = previousCompartmentState(i);
        if (prev.mecanizada > 0 || prev.fina > 0) {
          hasPerCompHistory = true;
        }
        final mecanizada = compartmentPhaseSnapshot(i, fina: false);
        final fina = compartmentPhaseSnapshot(i, fina: true);
        sumDayM += mecanizada.today;
        sumDayF += fina.today;
        sumCumM += mecanizada.finalValue;
        sumCumF += fina.finalValue;
        if (mecanizada.finalValue >= 100) {
          doneM += 1;
        }
        if (fina.finalValue >= 100) {
          doneF += 1;
        }
        if (mecanizada.finalValue >= 100 && fina.finalValue >= 100) {
          doneBoth += 1;
        }
      }

      final dailyM = sumDayM / total;
      final dailyF = sumDayF / total;
      final cumulativeM = hasPerCompHistory
          ? (sumCumM / total)
          : clampPercentDouble(baseLimpezaAcu + dailyM);
      final cumulativeF = hasPerCompHistory
          ? (sumCumF / total)
          : clampPercentDouble(baseLimpezaFinaAcu + dailyF);

      return (
        dailyM: dailyM,
        dailyF: dailyF,
        cumulativeM: cumulativeM,
        cumulativeF: cumulativeF,
        doneM: doneM,
        doneF: doneF,
        doneBoth: doneBoth,
        total: total,
        hasPerCompHistory: hasPerCompHistory,
      );
    }

    Future<void> pickPhotosFromGallery(StateSetter setModalState) async {
      if (photos.length >= _kMaxRdoPhotos) {
        showPhotoFeedback('Limite de $_kMaxRdoPhotos fotos por RDO atingido.');
        return;
      }
      try {
        final picked = await imagePicker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1920,
        );
        await appendPickedPhotos(picked, setModalState);
      } catch (_) {
        showPhotoFeedback('Falha ao selecionar foto(s) da galeria.');
      }
    }

    Future<void> pickPhotoFromCamera(StateSetter setModalState) async {
      if (photos.length >= _kMaxRdoPhotos) {
        showPhotoFeedback('Limite de $_kMaxRdoPhotos fotos por RDO atingido.');
        return;
      }
      try {
        final picked = await imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
        );
        if (picked == null) {
          return;
        }
        await appendPickedPhotos(<XFile>[picked], setModalState);
      } catch (_) {
        showPhotoFeedback('Falha ao capturar foto pela câmera.');
      }
    }

    void ensureCompartmentState() {
      final total = resolveNumeroCompartimentos();
      if (total <= 0) {
        selectedCompartimentos.clear();
        compartmentProgress.clear();
        previousCompartimentos.clear();
        return;
      }

      selectedCompartimentos.removeWhere(
        (idx) => idx < 1 || idx > total || compartmentCompleted(idx),
      );
      final stale = compartmentProgress.keys
          .where((idx) => idx < 1 || idx > total)
          .toList(growable: false);
      for (final key in stale) {
        compartmentProgress.remove(key);
      }
      final stalePrevious = previousCompartimentos.keys
          .where((idx) => idx < 1 || idx > total)
          .toList(growable: false);
      for (final key in stalePrevious) {
        previousCompartimentos.remove(key);
      }

      for (var i = 1; i <= total; i++) {
        compartmentProgress.putIfAbsent(
          i,
          () => const _CompartmentProgressDraft(),
        );
        previousCompartimentos.putIfAbsent(
          i,
          () => const _CompartmentProgressDraft(),
        );
      }

      if (isSalao()) {
        selectedCompartimentos
          ..clear()
          ..add(1);
      }
    }

    void recomputeCompartimentos() {
      ensureCompartmentState();
      final metrics = compartmentMetricsSnapshot();
      final total = metrics.total;
      if (total <= 0) {
        compartimentosAvancoJson = '{}';
        setControllerText(limpezaDiariaController, '');
        setControllerText(limpezaFinaDiariaController, '');
        setControllerText(
          limpezaAcuController,
          baseLimpezaAcu > 0
              ? '${clampPercentDouble(baseLimpezaAcu).round()}'
              : '',
        );
        setControllerText(
          limpezaFinaAcuController,
          baseLimpezaFinaAcu > 0
              ? '${clampPercentDouble(baseLimpezaFinaAcu).round()}'
              : '',
        );
        return;
      }

      final payload = <String, Map<String, int>>{};
      for (var i = 1; i <= total; i++) {
        final mecanizada = compartmentPhaseSnapshot(i, fina: false);
        final fina = compartmentPhaseSnapshot(i, fina: true);
        final sanitized = _CompartmentProgressDraft(
          mecanizada: mecanizada.today,
          fina: fina.today,
        );
        final existing = compartmentProgress[i];
        if (existing == null ||
            existing.mecanizada != sanitized.mecanizada ||
            existing.fina != sanitized.fina) {
          compartmentProgress[i] = sanitized;
        }
        payload['$i'] = <String, int>{
          'mecanizada': sanitized.mecanizada,
          'fina': sanitized.fina,
        };
      }

      compartimentosAvancoJson = jsonEncode(payload);
      setControllerText(
        limpezaDiariaController,
        formatDecimal(metrics.dailyM, precision: 2),
      );
      setControllerText(
        limpezaFinaDiariaController,
        formatDecimal(metrics.dailyF, precision: 2),
      );
      setControllerText(
        limpezaAcuController,
        formatDecimal(metrics.cumulativeM, precision: 2),
      );
      setControllerText(
        limpezaFinaAcuController,
        formatDecimal(metrics.cumulativeF, precision: 2),
      );
    }

    void recomputeOperational() {
      final tempoBomba = parseNumber(tempoBombaController.text);
      final ensDia = parseNumber(ensacamentoDiaController.text);
      final icaDia = parseNumber(icamentoDiaController.text);
      final cambDia = parseNumber(cambagemDiaController.text);
      final tamDia = parseNumber(tamboresDiaController.text);

      const vazaoPadrao = 36.0;
      final bombeio = tempoBomba > 0 ? tempoBomba * vazaoPadrao : 0.0;
      final totalLiquido = bombeio;
      final residuosSolidos = ensDia * 0.008;
      final residuosTotais = totalLiquido + residuosSolidos;

      setControllerText(
        bombeioController,
        bombeio <= 0 ? '' : formatDecimal(bombeio),
      );
      setControllerText(
        totalLiquidoController,
        totalLiquido <= 0 ? '' : formatDecimal(totalLiquido),
      );
      setControllerText(
        residuosSolidosController,
        residuosSolidos <= 0
            ? ''
            : formatDecimal(residuosSolidos, precision: 3),
      );
      setControllerText(
        residuosTotaisController,
        residuosTotais <= 0 ? '' : formatDecimal(residuosTotais),
      );

      final ensAcu = baseEnsacamentoAcu + ensDia;
      final icaAcu = baseIcamentoAcu + icaDia;
      final cambAcu = baseCambagemAcu + cambDia;
      final tamAcu = baseTamboresAcu + tamDia;
      final liqAcu = baseTotalLiquidoAcu + totalLiquido;
      final solAcu = baseResiduosSolidosAcu + residuosSolidos;

      setControllerText(
        ensacamentoAcuController,
        ensAcu <= 0 ? '' : '${ensAcu.round()}',
      );
      setControllerText(
        icamentoAcuController,
        icaAcu <= 0 ? '' : '${icaAcu.round()}',
      );
      setControllerText(
        cambagemAcuController,
        cambAcu <= 0 ? '' : '${cambAcu.round()}',
      );
      setControllerText(
        tamboresAcuController,
        tamAcu <= 0 ? '' : '${tamAcu.round()}',
      );
      setControllerText(
        totalLiquidoAcuController,
        liqAcu <= 0 ? '' : formatDecimal(liqAcu),
      );
      setControllerText(
        residuosSolidosAcuController,
        solAcu <= 0 ? '' : formatDecimal(solAcu, precision: 3),
      );
    }

    void clearEcTimes() {
      for (var i = 0; i < ecTimes.length; i++) {
        ecTimes[i] = const _EcTimeDraft();
      }
    }

    void applyPtLock() {
      if (ptAbertura == 'nao') {
        ptTurnos.clear();
        setControllerText(ptManhaController, '');
        setControllerText(ptTardeController, '');
        setControllerText(ptNoiteController, '');
      }
    }

    void applyEcLock() {
      if (espacoConfinado == 'nao') {
        clearEcTimes();
      }
    }

    void applyTipoTanqueLock() {
      if (isSalao()) {
        setControllerText(tanqueCompartimentosController, '1');
      }
      recomputeCompartimentos();
    }

    void resetTankBases() {
      baseEnsacamentoAcu = 0;
      baseIcamentoAcu = 0;
      baseCambagemAcu = 0;
      baseTamboresAcu = 0;
      baseTotalLiquidoAcu = 0;
      baseResiduosSolidosAcu = 0;
      baseLimpezaAcu = 0;
      baseLimpezaFinaAcu = 0;
    }

    ({double mecanizada, double fina}) compartimentosAverageSnapshot() {
      final metrics = compartmentMetricsSnapshot();
      return (mecanizada: metrics.cumulativeM, fina: metrics.cumulativeF);
    }

    _TankCatalogOption? selectedTankOption() {
      final key = selectedTankKey?.trim() ?? '';
      if (key.isEmpty) {
        return null;
      }
      for (final option in tankCatalog) {
        if (option.key == key) {
          return option;
        }
      }
      return null;
    }

    bool hasDefinedPrediction(String rawValue) {
      return rawValue.trim().isNotEmpty;
    }

    bool predictionsLockedForSelectedTank() {
      if (tankMode != _TankMode.existing) {
        return false;
      }
      final selected = selectedTankOption();
      if (selected == null) {
        return false;
      }
      return hasDefinedPrediction(selected.ensacamentoPrev) ||
          hasDefinedPrediction(selected.icamentoPrev) ||
          hasDefinedPrediction(selected.cambagemPrev);
    }

    bool fixedFieldsLockedForSelectedTank() {
      return false;
    }

    List<int> sortedSelectedCompartimentos() {
      return selectedCompartimentos
          .where((idx) => idx > 0)
          .toList(growable: false)
        ..sort();
    }

    _TankDraft buildExistingTankDraft({
      required _TankCatalogOption selected,
      required String codigo,
      required String nome,
    }) {
      return _TankDraft.existing(
        tank: selected,
        tanqueCodigo: selected.tanqueCodigo,
        tanqueNome: selected.tanqueNome,
        tipoTanque: tipoTanque,
        numeroCompartimentos: tanqueCompartimentosController.text,
        gavetas: tanqueGavetasController.text,
        patamares: tanquePatamarController.text,
        volumeTanqueExec: tanqueVolumeController.text,
        servicoExec: tanqueServicoController.text,
        metodoExec: tanqueMetodoController.text,
        espacoConfinado: espacoConfinado,
        operadoresSimultaneos: operadoresController.text,
        h2sPpm: h2sController.text,
        lel: lelController.text,
        coPpm: coController.text,
        o2Percent: o2Controller.text,
        totalNEfetivoConfinado: efetivoConfinadoController.text,
        sentidoLimpeza: sentidoLimpeza,
        tempoBomba: tempoBombaController.text,
        ensacamentoPrev: ensacamentoPrevController.text,
        icamentoPrev: icamentoPrevController.text,
        cambagemPrev: cambagemPrevController.text,
        ensacamentoDia: ensacamentoDiaController.text,
        icamentoDia: icamentoDiaController.text,
        cambagemDia: cambagemDiaController.text,
        tamboresDia: tamboresDiaController.text,
        bombeio: bombeioController.text,
        totalLiquido: totalLiquidoController.text,
        residuosSolidos: residuosSolidosController.text,
        residuosTotais: residuosTotaisController.text,
        ensacamentoCumulativo: ensacamentoAcuController.text,
        icamentoCumulativo: icamentoAcuController.text,
        cambagemCumulativo: cambagemAcuController.text,
        tamboresCumulativo: tamboresAcuController.text,
        totalLiquidoCumulativo: totalLiquidoAcuController.text,
        residuosSolidosCumulativo: residuosSolidosAcuController.text,
        percentualLimpezaDiario: limpezaDiariaController.text,
        percentualLimpezaFinaDiario: limpezaFinaDiariaController.text,
        percentualLimpezaCumulativo: limpezaAcuController.text,
        percentualLimpezaFinaCumulativo: limpezaFinaAcuController.text,
        compartimentosAvanco: sortedSelectedCompartimentos(),
        compartimentosAvancoJson: compartimentosAvancoJson,
      );
    }

    _TankDraft buildNewTankDraft({
      required String codigo,
      required String nome,
    }) {
      return _TankDraft.newTank(
        tanqueCodigo: codigo,
        tanqueNome: nome,
        tipoTanque: tipoTanque,
        numeroCompartimentos: tanqueCompartimentosController.text,
        gavetas: tanqueGavetasController.text,
        patamares: tanquePatamarController.text,
        volumeTanqueExec: tanqueVolumeController.text,
        servicoExec: tanqueServicoController.text,
        metodoExec: tanqueMetodoController.text,
        espacoConfinado: espacoConfinado,
        operadoresSimultaneos: operadoresController.text,
        h2sPpm: h2sController.text,
        lel: lelController.text,
        coPpm: coController.text,
        o2Percent: o2Controller.text,
        totalNEfetivoConfinado: efetivoConfinadoController.text,
        sentidoLimpeza: sentidoLimpeza,
        tempoBomba: tempoBombaController.text,
        ensacamentoPrev: ensacamentoPrevController.text,
        icamentoPrev: icamentoPrevController.text,
        cambagemPrev: cambagemPrevController.text,
        ensacamentoDia: ensacamentoDiaController.text,
        icamentoDia: icamentoDiaController.text,
        cambagemDia: cambagemDiaController.text,
        tamboresDia: tamboresDiaController.text,
        bombeio: bombeioController.text,
        totalLiquido: totalLiquidoController.text,
        residuosSolidos: residuosSolidosController.text,
        residuosTotais: residuosTotaisController.text,
        ensacamentoCumulativo: ensacamentoAcuController.text,
        icamentoCumulativo: icamentoAcuController.text,
        cambagemCumulativo: cambagemAcuController.text,
        tamboresCumulativo: tamboresAcuController.text,
        totalLiquidoCumulativo: totalLiquidoAcuController.text,
        residuosSolidosCumulativo: residuosSolidosAcuController.text,
        percentualLimpezaDiario: limpezaDiariaController.text,
        percentualLimpezaFinaDiario: limpezaFinaDiariaController.text,
        percentualLimpezaCumulativo: limpezaAcuController.text,
        percentualLimpezaFinaCumulativo: limpezaFinaAcuController.text,
        compartimentosAvanco: sortedSelectedCompartimentos(),
        compartimentosAvancoJson: compartimentosAvancoJson,
      );
    }

    String describeTankDraft(_TankDraft tankDraft) {
      switch (tankDraft.mode) {
        case _TankMode.none:
          return '';
        case _TankMode.existing:
          final selected = tankDraft.existingTank;
          if (selected != null && selected.label.trim().isNotEmpty) {
            return selected.label.trim();
          }
          break;
        case _TankMode.create:
          break;
      }
      final code = tankDraft.tanqueCodigo.trim();
      final name = tankDraft.tanqueNome.trim();
      if (code.isNotEmpty && name.isNotEmpty) {
        return '$code • $name';
      }
      if (code.isNotEmpty) {
        return code;
      }
      if (name.isNotEmpty) {
        return name;
      }
      return 'Tanque';
    }

    void clearTankFieldsForNew() {
      setControllerText(tanqueCodigoController, '');
      setControllerText(tanqueNomeController, '');
      tipoTanque = '';
      setControllerText(tanqueCompartimentosController, '');
      setControllerText(tanqueGavetasController, '');
      setControllerText(tanquePatamarController, '');
      setControllerText(tanqueVolumeController, '');
      setControllerText(tanqueServicoController, '');
      setControllerText(tanqueMetodoController, '');
      espacoConfinado = '';
      setControllerText(operadoresController, '');
      setControllerText(efetivoConfinadoController, '');
      setControllerText(h2sController, '');
      setControllerText(lelController, '');
      setControllerText(coController, '');
      setControllerText(o2Controller, '');
      setControllerText(ensacamentoPrevController, '');
      syncForecastFields();
      setControllerText(cambagemPrevController, '');
      setControllerText(tempoBombaController, '');
      sentidoLimpeza = '';
      setControllerText(ensacamentoDiaController, '');
      setControllerText(icamentoDiaController, '');
      setControllerText(cambagemDiaController, '');
      setControllerText(tamboresDiaController, '');
      setControllerText(bombeioController, '');
      setControllerText(totalLiquidoController, '');
      setControllerText(residuosSolidosController, '');
      setControllerText(residuosTotaisController, '');
      setControllerText(ensacamentoAcuController, '');
      setControllerText(icamentoAcuController, '');
      setControllerText(cambagemAcuController, '');
      setControllerText(tamboresAcuController, '');
      setControllerText(totalLiquidoAcuController, '');
      setControllerText(residuosSolidosAcuController, '');
      setControllerText(limpezaDiariaController, '');
      setControllerText(limpezaFinaDiariaController, '');
      setControllerText(limpezaAcuController, '');
      setControllerText(limpezaFinaAcuController, '');
      selectedCompartimentos.clear();
      compartmentProgress.clear();
      previousCompartimentos.clear();
      compartimentosAvancoJson = '{}';
      resetTankBases();
    }

    void applyTankSnapshot(_TankCatalogOption? tank) {
      if (tank == null) {
        return;
      }

      final resolvedCompartimentos =
          parseIntValue(tank.numeroCompartimentos) > 0
          ? tank.numeroCompartimentos
          : (() {
              final inferred = _inferCompartimentosTotalFromPayloadJsons(
                <String?>[
                  tank.compartimentosCumulativoJson,
                  tank.compartimentosAvancoJson,
                ],
              );
              return inferred > 0 ? '$inferred' : '';
            })();

      setControllerText(tanqueCodigoController, tank.tanqueCodigo);
      setControllerText(tanqueNomeController, tank.tanqueNome);
      tipoTanque = tank.tipoTanque;
      setControllerText(tanqueCompartimentosController, resolvedCompartimentos);
      setControllerText(tanqueGavetasController, tank.gavetas);
      setControllerText(tanquePatamarController, tank.patamares);
      setControllerText(tanqueVolumeController, tank.volumeTanqueExec);
      setControllerText(tanqueServicoController, tank.servicoExec);
      setControllerText(tanqueMetodoController, tank.metodoExec);

      // Campos diários não devem vir preenchidos do RDO anterior.
      espacoConfinado = '';
      setControllerText(operadoresController, '');
      setControllerText(efetivoConfinadoController, '');
      setControllerText(h2sController, '');
      setControllerText(lelController, '');
      setControllerText(coController, '');
      setControllerText(o2Controller, '');
      clearEcTimes();

      final normalizedEnsacamentoPrev = tank.ensacamentoPrev.trim().isNotEmpty
          ? tank.ensacamentoPrev
          : tank.icamentoPrev;
      setControllerText(ensacamentoPrevController, normalizedEnsacamentoPrev);
      syncForecastFields();
      setControllerText(cambagemPrevController, tank.cambagemPrev);

      sentidoLimpeza = '';
      setControllerText(tempoBombaController, '');
      setControllerText(ensacamentoDiaController, '');
      setControllerText(icamentoDiaController, '');
      setControllerText(cambagemDiaController, '');
      setControllerText(tamboresDiaController, '');
      setControllerText(bombeioController, '');
      setControllerText(totalLiquidoController, '');
      setControllerText(residuosSolidosController, '');
      setControllerText(residuosTotaisController, '');

      baseEnsacamentoAcu = parseNumber(tank.ensacamentoCumulativo);
      baseIcamentoAcu = parseNumber(tank.icamentoCumulativo);
      baseCambagemAcu = parseNumber(tank.cambagemCumulativo);
      baseTamboresAcu = parseNumber(tank.tamboresCumulativo);
      baseTotalLiquidoAcu = parseNumber(tank.totalLiquidoCumulativo);
      baseResiduosSolidosAcu = parseNumber(tank.residuosSolidosCumulativo);
      baseLimpezaAcu = parseNumber(tank.percentualLimpezaCumulativo);
      baseLimpezaFinaAcu = parseNumber(tank.percentualLimpezaFinaCumulativo);

      if (baseEnsacamentoAcu <= 0) {
        baseEnsacamentoAcu = parseNumber(tank.ensacamentoPrev);
      }
      if (baseIcamentoAcu <= 0) {
        baseIcamentoAcu = parseNumber(tank.icamentoPrev);
      }
      if (baseCambagemAcu <= 0) {
        baseCambagemAcu = parseNumber(tank.cambagemPrev);
      }
      previousCompartimentos
        ..clear()
        ..addAll(
          _buildTankPreviousCompartimentos(
            assigned,
            _controller.items,
            tanqueCodigo: tank.tanqueCodigo,
            tanqueNome: tank.tanqueNome,
            totalCompartimentos: parseIntValue(resolvedCompartimentos),
          ),
        );
      setControllerText(limpezaDiariaController, '');
      setControllerText(limpezaFinaDiariaController, '');

      applyTipoTanqueLock();
      selectedCompartimentos.clear();
      compartmentProgress.clear();
      recomputeCompartimentos();
      final snapshot = compartimentosAverageSnapshot();
      if (baseLimpezaAcu <= 0 && snapshot.mecanizada > 0) {
        baseLimpezaAcu = snapshot.mecanizada;
      }
      if (baseLimpezaFinaAcu <= 0 && snapshot.fina > 0) {
        baseLimpezaFinaAcu = snapshot.fina;
      }
      recomputeOperational();
    }

    bool currentSelectedTankAlreadyAdded() {
      final selected = selectedTankOption();
      if (selected == null) {
        return false;
      }
      return stagedSelectedTankKeys().contains(selected.key);
    }

    String noConfiguredTankMessage() {
      return 'Esta OS não possui tanque configurado pelo Coordenador..';
    }

    String noRemainingTankMessage() {
      return 'Todos os tanques configurados desta OS já foram adicionados neste RDO.';
    }

    void selectNextAvailableTankOrClear() {
      selectedTankKey = null;
      clearTankFieldsForNew();
    }

    bool hasCurrentTankInput() {
      if (tankMode == _TankMode.none) {
        return false;
      }
      if (tankMode == _TankMode.existing) {
        if ((selectedTankKey?.trim().isNotEmpty ?? false)) {
          return true;
        }
      }

      final textValues = <String>[
        tanqueCodigoController.text,
        tanqueNomeController.text,
        tipoTanque,
        tanqueCompartimentosController.text,
        tanqueGavetasController.text,
        tanquePatamarController.text,
        tanqueVolumeController.text,
        tanqueServicoController.text,
        tanqueMetodoController.text,
        espacoConfinado,
        operadoresController.text,
        efetivoConfinadoController.text,
        h2sController.text,
        lelController.text,
        coController.text,
        o2Controller.text,
        ensacamentoPrevController.text,
        icamentoPrevController.text,
        cambagemPrevController.text,
        tempoBombaController.text,
        sentidoLimpeza,
        ensacamentoDiaController.text,
        icamentoDiaController.text,
        cambagemDiaController.text,
        tamboresDiaController.text,
        bombeioController.text,
        totalLiquidoController.text,
        residuosSolidosController.text,
        residuosTotaisController.text,
        ensacamentoAcuController.text,
        icamentoAcuController.text,
        cambagemAcuController.text,
        tamboresAcuController.text,
        totalLiquidoAcuController.text,
        residuosSolidosAcuController.text,
        limpezaDiariaController.text,
        limpezaFinaDiariaController.text,
        limpezaAcuController.text,
        limpezaFinaAcuController.text,
      ];
      if (textValues.any((value) => value.trim().isNotEmpty)) {
        return true;
      }
      if (selectedCompartimentos.isNotEmpty) {
        return true;
      }
      return false;
    }

    bool validateActivities(StateSetter setModalState) {
      for (var i = 0; i < activities.length; i++) {
        final row = activities[i];
        final hasAnyValue =
            row.nome.trim().isNotEmpty ||
            row.inicio != null ||
            row.fim != null ||
            row.comentarioPt.trim().isNotEmpty ||
            row.comentarioEn.trim().isNotEmpty;
        if (!hasAnyValue) {
          continue;
        }
        if (row.nome.trim().isEmpty) {
          setModalState(() {
            error = 'Informe o nome da atividade ${i + 1}.';
          });
          return false;
        }
        if (row.inicio != null && row.fim != null) {
          final ini = row.inicio!;
          final fim = row.fim!;
          final iniMinutes = ini.hour * 60 + ini.minute;
          final fimMinutes = fim.hour * 60 + fim.minute;
          if (iniMinutes == fimMinutes) {
            setModalState(() {
              error = 'A atividade ${i + 1} não pode ter início e fim iguais.';
            });
            return false;
          }
        }
      }
      return true;
    }

    _TankDraft? resolveCurrentTankDraft(
      StateSetter setModalState, {
      required bool requireTank,
    }) {
      final hasInput = hasCurrentTankInput();
      final codigo = tanqueCodigoController.text.trim();
      final nome = tanqueNomeController.text.trim();

      if (ptAbertura == 'nao') {
        ptTurnos.clear();
      }
      if (espacoConfinado == 'nao') {
        clearEcTimes();
      }
      recomputeOperational();
      recomputeCompartimentos();

      if (tankMode == _TankMode.existing) {
        final availableOptions = availableTankSelectionOptions();
        if (tankCatalog.isEmpty) {
          return const _TankDraft.none();
        }
        final selected = selectedTankOption();
        if (selected == null) {
          if (!requireTank && !hasInput) {
            return const _TankDraft.none();
          }
          setModalState(() {
            error = availableOptions.isEmpty
                ? noRemainingTankMessage()
                : 'Selecione um tanque configurado na Home.';
          });
          return null;
        }
        if (currentSelectedTankAlreadyAdded()) {
          setModalState(() {
            error =
                'Este tanque já foi adicionado neste RDO. Selecione outro tanque configurado.';
          });
          return null;
        }
        return buildExistingTankDraft(
          selected: selected,
          codigo: codigo,
          nome: nome,
        );
      }

      if (codigo.isEmpty && nome.isEmpty) {
        if (osTankLimit > 0 && isTankCreationLocked()) {
          if (!requireTank && !hasInput) {
            return const _TankDraft.none();
          }
          setModalState(() {
            error = tankLimitReachedMessage();
          });
          return null;
        }
        if (!requireTank && !hasInput) {
          return const _TankDraft.none();
        }
        setModalState(() {
          error = 'Informe o código ou o nome do tanque.';
        });
        return null;
      }

      if (osTankLimit > 0 &&
          currentDraftConsumesNewTankSlot(codigo, nome) &&
          isTankCreationLocked()) {
        setModalState(() {
          error = tankLimitReachedMessage();
        });
        return null;
      }

      return buildNewTankDraft(codigo: codigo, nome: nome);
    }

    ensacamentoPrevController.addListener(syncForecastFields);
    syncForecastFields();
    recomputeOperational();
    recomputeCompartimentos();
    observacoesController.addListener(syncMainTranslationPreviews);
    planejamentoController.addListener(syncMainTranslationPreviews);
    syncMainTranslationPreviews();

    try {
      return await showModalBottomSheet<_CreateRdoDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (modalContext, setModalState) {
              final totalCompartimentos = resolveNumeroCompartimentos();
              final sortedSelectedCompartimentos =
                  selectedCompartimentos.toList(growable: false)..sort();
              final ptChoices = effectivePtChoices();

              final localSentidoChoices = sentidoChoices.isNotEmpty
                  ? sentidoChoices
                  : const <ActivityChoiceItem>[
                      ActivityChoiceItem(
                        value: 'vante > ré',
                        label: 'Vante → Ré',
                      ),
                      ActivityChoiceItem(
                        value: 'ré > vante',
                        label: 'Ré → Vante',
                      ),
                      ActivityChoiceItem(
                        value: 'bombordo > boreste',
                        label: 'Bombordo → Boreste',
                      ),
                      ActivityChoiceItem(
                        value: 'boreste < bombordo',
                        label: 'Boreste ← Bombordo',
                      ),
                    ];
              final predictionsLocked = predictionsLockedForSelectedTank();
              final availableSelectionTanks = availableTankSelectionOptions();
              Widget sectionTitle(String value, {String? subtitle}) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.supervisorLime,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          value,
                          style: const TextStyle(
                            color: _kInk,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null &&
                        subtitle.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle.trim(),
                        style: const TextStyle(
                          color: _kMutedInk,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                );
              }

              Widget readonlyField({
                required TextEditingController controller,
                required String label,
              }) {
                return TextField(
                  controller: controller,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                  ),
                );
              }

              Widget subsectionLabel(String label, {IconData? icon}) {
                return Row(
                  children: <Widget>[
                    Icon(
                      icon ?? Icons.label_rounded,
                      size: 15,
                      color: _kMutedInk,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              }

              Widget tankMetaChip({
                required IconData icon,
                required String label,
                Color background = const Color(0xFFF3F4F6),
                Color foreground = _kInk,
              }) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 13, color: foreground),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget tankSelectionStatusCard() {
                final currentTank = selectedTankOption();
                if (tankCatalog.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kCardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.layers_clear_rounded,
                            color: _kInk,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'RDO sem tanque',
                                style: TextStyle(
                                  color: _kInk,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Esta OS não possui tanque configurado na Home. O preenchimento continua normalmente sem tanque.',
                                style: TextStyle(
                                  color: _kMutedInk,
                                  fontSize: 12.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (currentTank == null) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDEA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.supervisorLime.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.supervisorLime,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.touch_app_rounded,
                            color: _kInk,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Selecione o tanque se precisar',
                                style: TextStyle(
                                  color: _kInk,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Se este RDO não tiver lançamento por tanque, continue normalmente sem selecionar.',
                                style: TextStyle(
                                  color: _kMutedInk,
                                  fontSize: 12.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final metaWidgets = <Widget>[];
                if (currentTank.tipoTanque.trim().isNotEmpty) {
                  metaWidgets.add(
                    tankMetaChip(
                      icon: Icons.category_rounded,
                      label: currentTank.tipoTanque.trim(),
                      background: const Color(0xFF1F2937),
                      foreground: Colors.white,
                    ),
                  );
                }
                if (currentTank.numeroCompartimentos.trim().isNotEmpty) {
                  metaWidgets.add(
                    tankMetaChip(
                      icon: Icons.view_week_rounded,
                      label:
                          '${currentTank.numeroCompartimentos.trim()} compart.',
                      background: const Color(0xFF1F2937),
                      foreground: Colors.white,
                    ),
                  );
                }
                if (currentTank.metodoExec.trim().isNotEmpty) {
                  metaWidgets.add(
                    tankMetaChip(
                      icon: Icons.settings_suggest_rounded,
                      label: currentTank.metodoExec.trim(),
                      background: const Color(0xFF1F2937),
                      foreground: Colors.white,
                    ),
                  );
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.supervisorLime.withValues(alpha: 0.45),
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.supervisorLime,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: _kInk,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Tanque em preenchimento',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 11.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  currentTank.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.4,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (metaWidgets.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: metaWidgets),
                      ],
                    ],
                  ),
                );
              }

              Widget searchableChoiceDecorator({
                required String labelText,
                required String hintText,
                required String selectedLabel,
              }) {
                final resolvedLabel = selectedLabel.trim();
                final hasValue = resolvedLabel.isNotEmpty;
                return InputDecorator(
                  isEmpty: !hasValue,
                  decoration: InputDecoration(
                    labelText: labelText,
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: _kMutedInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.search_rounded),
                  ),
                  child: hasValue
                      ? Text(
                          resolvedLabel,
                          style: const TextStyle(
                            color: _kInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              }

              ActivityChoiceItem? findChoiceByValue(
                String rawValue,
                List<ActivityChoiceItem> source,
              ) {
                final lookup = _normalizeChoiceKey(rawValue);
                if (lookup.isEmpty) {
                  return null;
                }
                for (final item in source) {
                  final byValue = _normalizeChoiceKey(item.value);
                  final byLabel = _normalizeChoiceKey(item.label);
                  if (lookup == byValue || lookup == byLabel) {
                    return item;
                  }
                }
                return null;
              }

              Future<ActivityChoiceItem?> openChoicePicker({
                required String title,
                required List<ActivityChoiceItem> options,
                String initialValue = '',
                bool allowManualValue = true,
              }) async {
                final searchController = TextEditingController(
                  text: initialValue.trim(),
                );
                var query = initialValue.trim();

                List<ActivityChoiceItem> filterOptions(String raw) {
                  final normalizedQuery = _normalizeChoiceKey(raw);
                  if (normalizedQuery.isEmpty) {
                    return options;
                  }
                  return options
                      .where((item) {
                        final inValue = _normalizeChoiceKey(
                          item.value,
                        ).contains(normalizedQuery);
                        final inLabel = _normalizeChoiceKey(
                          item.label,
                        ).contains(normalizedQuery);
                        return inValue || inLabel;
                      })
                      .toList(growable: false);
                }

                bool queryMatchesAny(String raw) {
                  final normalizedQuery = _normalizeChoiceKey(raw);
                  if (normalizedQuery.isEmpty) {
                    return false;
                  }
                  for (final item in options) {
                    if (_normalizeChoiceKey(item.value) == normalizedQuery ||
                        _normalizeChoiceKey(item.label) == normalizedQuery) {
                      return true;
                    }
                  }
                  return false;
                }

                try {
                  return await showModalBottomSheet<ActivityChoiceItem>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.white,
                    builder: (pickerContext) {
                      return StatefulBuilder(
                        builder: (pickerContext, setPickerState) {
                          final filtered = filterOptions(query);
                          final trimmedQuery = query.trim();
                          final canUseManual =
                              allowManualValue &&
                              trimmedQuery.isNotEmpty &&
                              !queryMatchesAny(trimmedQuery);

                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              14,
                              16,
                              MediaQuery.of(pickerContext).viewInsets.bottom +
                                  14,
                            ),
                            child: SizedBox(
                              height:
                                  MediaQuery.of(pickerContext).size.height *
                                  0.72,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            color: _kInk,
                                            fontSize: 16.2,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Fechar',
                                        onPressed: () {
                                          Navigator.of(pickerContext).pop();
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: searchController,
                                    autofocus: true,
                                    textInputAction: TextInputAction.search,
                                    onChanged: (value) {
                                      setPickerState(() {
                                        query = value;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Buscar',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                      ),
                                      suffixIcon: query.trim().isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Limpar',
                                              onPressed: () {
                                                searchController.clear();
                                                setPickerState(() {
                                                  query = '';
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.close_rounded,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (canUseManual)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _kCardBorder),
                                        color: const Color(0xFFF9FAFB),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.edit_rounded,
                                          size: 20,
                                          color: _kMutedInk,
                                        ),
                                        title: Text(
                                          trimmedQuery,
                                          style: const TextStyle(
                                            color: _kInk,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: const Text(
                                          'Usar texto digitado',
                                          style: TextStyle(
                                            color: _kMutedInk,
                                            fontSize: 11.8,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.of(pickerContext).pop(
                                            ActivityChoiceItem(
                                              value: trimmedQuery,
                                              label: trimmedQuery,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  Expanded(
                                    child: filtered.isEmpty
                                        ? Container(
                                            width: double.infinity,
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _kCardBorder,
                                              ),
                                              color: const Color(0xFFF9FAFB),
                                            ),
                                            child: const Text(
                                              'Nenhum resultado para esta busca.',
                                              style: TextStyle(
                                                color: _kMutedInk,
                                                fontSize: 12.4,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            itemCount: filtered.length,
                                            separatorBuilder: (_, index) =>
                                                const Divider(height: 1),
                                            itemBuilder: (ctx, index) {
                                              final item = filtered[index];
                                              final subtitle =
                                                  item.value.trim() ==
                                                      item.label.trim()
                                                  ? ''
                                                  : item.value.trim();
                                              return ListTile(
                                                dense: true,
                                                title: Text(
                                                  item.label,
                                                  style: const TextStyle(
                                                    color: _kInk,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                subtitle: subtitle.isEmpty
                                                    ? null
                                                    : Text(
                                                        subtitle,
                                                        style: const TextStyle(
                                                          color: _kMutedInk,
                                                          fontSize: 11.6,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                onTap: () {
                                                  Navigator.of(
                                                    pickerContext,
                                                  ).pop(item);
                                                },
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                } finally {
                  searchController.dispose();
                }
              }

              return FractionallySizedBox(
                heightFactor: 0.94,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SingleChildScrollView(
                    controller: modalScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Iniciar RDO ${summary.nextRdo} • OS ${assigned.osNumber}',
                          style: const TextStyle(
                            color: _kInk,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.operationLabel,
                          style: const TextStyle(
                            color: _kMutedInk,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        tankSelectionStatusCard(),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: modalContext,
                              initialDate: businessDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked == null) {
                              return;
                            }
                            setModalState(() {
                              businessDate = picked;
                            });
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data do RDO',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                            child: Text(
                              _formatDate(businessDate),
                              style: const TextStyle(
                                color: _kInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        sectionTitle(
                          'Turno e PT',
                          subtitle:
                              'Defina o turno e as permissões de trabalho do dia.',
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kCardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              subsectionLabel(
                                '1) Turno do RDO',
                                icon: Icons.dark_mode_rounded,
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 8,
                                children: <Widget>[
                                  ChoiceChip(
                                    label: const Text('Diurno'),
                                    selected: turno == 'Diurno',
                                    onSelected: (_) {
                                      setModalState(() {
                                        turno = 'Diurno';
                                      });
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Noturno'),
                                    selected: turno == 'Noturno',
                                    onSelected: (_) {
                                      setModalState(() {
                                        turno = 'Noturno';
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              subsectionLabel(
                                '2) Permissão de Trabalho (PT)',
                                icon: Icons.assignment_turned_in_rounded,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: ptAbertura.isEmpty
                                    ? null
                                    : ptAbertura,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Houve abertura de PT neste turno?',
                                  border: OutlineInputBorder(),
                                ),
                                items: const <DropdownMenuItem<String>>[
                                  DropdownMenuItem<String>(
                                    value: 'sim',
                                    child: Text('Sim'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'nao',
                                    child: Text('Não'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    ptAbertura = value ?? '';
                                    applyPtLock();
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              IgnorePointer(
                                ignoring: ptAbertura == 'nao',
                                child: Opacity(
                                  opacity: ptAbertura == 'nao' ? 0.55 : 1,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: ptChoices
                                        .map((choice) {
                                          final selected = ptTurnos.contains(
                                            choice.value,
                                          );
                                          return FilterChip(
                                            label: Text(choice.label),
                                            selected: selected,
                                            onSelected: (checked) {
                                              setModalState(() {
                                                if (checked) {
                                                  ptTurnos.add(choice.value);
                                                } else {
                                                  ptTurnos.remove(choice.value);
                                                }
                                              });
                                            },
                                          );
                                        })
                                        .toList(growable: false),
                                  ),
                                ),
                              ),
                              if (ptAbertura == 'nao') ...<Widget>[
                                const SizedBox(height: 8),
                                const Text(
                                  'Sem abertura de PT: os números abaixo ficam bloqueados.',
                                  style: TextStyle(
                                    color: _kMutedInk,
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: TextField(
                                      controller: ptManhaController,
                                      readOnly: ptAbertura == 'nao',
                                      decoration: const InputDecoration(
                                        labelText: 'PT manhã (nº)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: ptTardeController,
                                      readOnly: ptAbertura == 'nao',
                                      decoration: const InputDecoration(
                                        labelText: 'PT tarde (nº)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: ptNoiteController,
                                      readOnly: ptAbertura == 'nao',
                                      decoration: const InputDecoration(
                                        labelText: 'PT noite (nº)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        sectionTitle(
                          'Atividades',
                          subtitle:
                              'Registre as etapas executadas no dia, com horários e comentários. O campo EN é preenchido automaticamente.',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Text(
                              '${activities.length}/20 atividades',
                              style: const TextStyle(
                                color: _kMutedInk,
                                fontSize: 12.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: activities.length >= 20
                                  ? null
                                  : () {
                                      setModalState(() {
                                        cancelActivityTranslationTimers();
                                        activities.add(const _ActivityDraft());
                                        if (activities.length >= 2) {
                                          final prev =
                                              activities[activities.length - 2];
                                          final current = activities.last;
                                          if (current.inicio == null &&
                                              prev.fim != null) {
                                            activities[activities.length -
                                                1] = current.copyWith(
                                              inicio: prev.fim,
                                            );
                                          }
                                        }
                                      });
                                    },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Adicionar'),
                            ),
                          ],
                        ),
                        ...activities.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          final hasValues =
                              row.nome.trim().isNotEmpty ||
                              row.inicio != null ||
                              row.fim != null ||
                              row.comentarioPt.trim().isNotEmpty ||
                              row.comentarioEn.trim().isNotEmpty;
                          final activityOptions = ensureChoiceContains(
                            activityChoices,
                            row.nome,
                          );
                          final atividadeEn = translateActivityLabelToEn(
                            row.nome,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasValues
                                    ? AppTheme.supervisorLime.withValues(
                                        alpha: .5,
                                      )
                                    : _kCardBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        'Atividade ${index + 1}',
                                        style: const TextStyle(
                                          color: _kInk,
                                          fontSize: 12.4,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: activities.length <= 1
                                          ? null
                                          : () {
                                              setModalState(() {
                                                cancelActivityTranslationTimers();
                                                activities.removeAt(index);
                                              });
                                            },
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                      ),
                                      tooltip: 'Remover atividade',
                                    ),
                                  ],
                                ),
                                if (activityOptions.isEmpty)
                                  TextFormField(
                                    initialValue: row.nome,
                                    decoration: const InputDecoration(
                                      labelText: 'Atividade (PT)',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      setModalState(() {
                                        final current = activities[index];
                                        final previousAutoCommentEn =
                                            autoTranslateTextToEn(
                                              current.comentarioPt,
                                              activityValue: current.nome,
                                            );
                                        final shouldAutoFillEn =
                                            current.comentarioEn
                                                .trim()
                                                .isEmpty ||
                                            current.comentarioEn.trim() ==
                                                previousAutoCommentEn.trim();
                                        activities[index] = current.copyWith(
                                          nome: value,
                                          comentarioEn: shouldAutoFillEn
                                              ? autoTranslateTextToEn(
                                                  current.comentarioPt,
                                                  activityValue: value,
                                                )
                                              : current.comentarioEn,
                                        );
                                      });
                                      if (index >= 0 &&
                                          index < activities.length) {
                                        final updated = activities[index];
                                        final updatedAutoCommentEn =
                                            autoTranslateTextToEn(
                                              updated.comentarioPt,
                                              activityValue: updated.nome,
                                            );
                                        final shouldAutoFillEn =
                                            updated.comentarioEn
                                                .trim()
                                                .isEmpty ||
                                            updated.comentarioEn.trim() ==
                                                updatedAutoCommentEn.trim();
                                        if (shouldAutoFillEn &&
                                            updated.comentarioPt
                                                    .trim()
                                                    .length >=
                                                3) {
                                          scheduleActivityCommentTranslation(
                                            index,
                                            setModalState,
                                          );
                                        } else {
                                          cancelTranslationTimer(
                                            'activity_comment_$index',
                                          );
                                        }
                                      }
                                    },
                                  )
                                else
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () async {
                                      final picked = await openChoicePicker(
                                        title: 'Selecionar atividade',
                                        options: activityOptions,
                                        initialValue: row.nome,
                                        allowManualValue: true,
                                      );
                                      if (picked == null) {
                                        return;
                                      }

                                      final nextNome = picked.value.trim();
                                      setModalState(() {
                                        final current = activities[index];
                                        final previousAutoCommentEn =
                                            autoTranslateTextToEn(
                                              current.comentarioPt,
                                              activityValue: current.nome,
                                            );
                                        final shouldAutoFillEn =
                                            current.comentarioEn
                                                .trim()
                                                .isEmpty ||
                                            current.comentarioEn.trim() ==
                                                previousAutoCommentEn.trim();
                                        activities[index] = current.copyWith(
                                          nome: nextNome,
                                          comentarioEn: shouldAutoFillEn
                                              ? autoTranslateTextToEn(
                                                  current.comentarioPt,
                                                  activityValue: nextNome,
                                                )
                                              : current.comentarioEn,
                                        );
                                      });
                                      if (index >= 0 &&
                                          index < activities.length) {
                                        final updated = activities[index];
                                        final updatedAutoCommentEn =
                                            autoTranslateTextToEn(
                                              updated.comentarioPt,
                                              activityValue: updated.nome,
                                            );
                                        final shouldAutoFillEn =
                                            updated.comentarioEn
                                                .trim()
                                                .isEmpty ||
                                            updated.comentarioEn.trim() ==
                                                updatedAutoCommentEn.trim();
                                        if (shouldAutoFillEn &&
                                            updated.comentarioPt
                                                    .trim()
                                                    .length >=
                                                3) {
                                          scheduleActivityCommentTranslation(
                                            index,
                                            setModalState,
                                          );
                                        } else {
                                          cancelTranslationTimer(
                                            'activity_comment_$index',
                                          );
                                        }
                                      }
                                    },
                                    child: IgnorePointer(
                                      child: searchableChoiceDecorator(
                                        labelText: 'Atividade (PT)',
                                        hintText: 'Toque para buscar atividade',
                                        selectedLabel: row.nome.trim().isEmpty
                                            ? ''
                                            : (findChoiceByValue(
                                                    row.nome,
                                                    activityOptions,
                                                  )?.label ??
                                                  row.nome),
                                      ),
                                    ),
                                  ),
                                if (atividadeEn.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tradução EN: $atividadeEn',
                                    style: const TextStyle(
                                      color: _kMutedInk,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey<String>(
                                          'activity-start-$index-${row.inicio == null ? 'empty' : _formatTimeOfDay(row.inicio!)}',
                                        ),
                                        initialValue: row.inicio == null
                                            ? ''
                                            : _formatTimeOfDay(row.inicio!),
                                        keyboardType: TextInputType.datetime,
                                        decoration: InputDecoration(
                                          labelText: 'Início da atividade',
                                          hintText: '08:00',
                                          border: const OutlineInputBorder(),
                                          suffixIcon: IconButton(
                                            icon: const Icon(
                                              Icons.schedule_rounded,
                                            ),
                                            tooltip: 'Selecionar horário',
                                            onPressed: () async {
                                              final picked =
                                                  await showTimePicker(
                                                    context: modalContext,
                                                    initialTime:
                                                        row.inicio ??
                                                        TimeOfDay.now(),
                                                  );
                                              if (picked == null) {
                                                return;
                                              }
                                              setModalState(() {
                                                activities[index] = row
                                                    .copyWith(inicio: picked);
                                                if (index > 0 &&
                                                    activities[index - 1].fim ==
                                                        null) {
                                                  activities[index -
                                                      1] = activities[index - 1]
                                                      .copyWith(fim: picked);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        onChanged: (value) {
                                          final parsed = parseTimeValue(value);
                                          setModalState(() {
                                            if (value.trim().isEmpty) {
                                              activities[index] = row.copyWith(
                                                clearInicio: true,
                                              );
                                            } else if (parsed != null) {
                                              activities[index] = row.copyWith(
                                                inicio: parsed,
                                              );
                                              if (index > 0 &&
                                                  activities[index - 1].fim ==
                                                      null) {
                                                activities[index -
                                                    1] = activities[index - 1]
                                                    .copyWith(fim: parsed);
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey<String>(
                                          'activity-end-$index-${row.fim == null ? 'empty' : _formatTimeOfDay(row.fim!)}',
                                        ),
                                        initialValue: row.fim == null
                                            ? ''
                                            : _formatTimeOfDay(row.fim!),
                                        keyboardType: TextInputType.datetime,
                                        decoration: InputDecoration(
                                          labelText: 'Fim da atividade',
                                          hintText: '17:30',
                                          border: const OutlineInputBorder(),
                                          suffixIcon: IconButton(
                                            icon: const Icon(
                                              Icons.schedule_rounded,
                                            ),
                                            tooltip: 'Selecionar horário',
                                            onPressed: () async {
                                              final picked =
                                                  await showTimePicker(
                                                    context: modalContext,
                                                    initialTime:
                                                        row.fim ??
                                                        TimeOfDay.now(),
                                                  );
                                              if (picked == null) {
                                                return;
                                              }
                                              setModalState(() {
                                                activities[index] = row
                                                    .copyWith(fim: picked);
                                                if (index + 1 <
                                                        activities.length &&
                                                    activities[index + 1]
                                                            .inicio ==
                                                        null) {
                                                  activities[index +
                                                      1] = activities[index + 1]
                                                      .copyWith(inicio: picked);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        onChanged: (value) {
                                          final parsed = parseTimeValue(value);
                                          setModalState(() {
                                            if (value.trim().isEmpty) {
                                              activities[index] = row.copyWith(
                                                clearFim: true,
                                              );
                                            } else if (parsed != null) {
                                              activities[index] = row.copyWith(
                                                fim: parsed,
                                              );
                                              if (index + 1 <
                                                      activities.length &&
                                                  activities[index + 1]
                                                          .inicio ==
                                                      null) {
                                                activities[index +
                                                    1] = activities[index + 1]
                                                    .copyWith(inicio: parsed);
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: row.comentarioPt,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Comentário da atividade (PT)',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    var shouldAutoFillEn = false;
                                    setModalState(() {
                                      final current = activities[index];
                                      final previousAutoCommentEn =
                                          autoTranslateTextToEn(
                                            current.comentarioPt,
                                            activityValue: current.nome,
                                          );
                                      shouldAutoFillEn =
                                          current.comentarioEn.trim().isEmpty ||
                                          current.comentarioEn.trim() ==
                                              previousAutoCommentEn.trim();
                                      activities[index] = current.copyWith(
                                        comentarioPt: value,
                                        comentarioEn: shouldAutoFillEn
                                            ? autoTranslateTextToEn(
                                                value,
                                                activityValue: current.nome,
                                              )
                                            : current.comentarioEn,
                                      );
                                    });
                                    if (shouldAutoFillEn &&
                                        value.trim().length >= 3) {
                                      scheduleActivityCommentTranslation(
                                        index,
                                        setModalState,
                                      );
                                    } else {
                                      cancelTranslationTimer(
                                        'activity_comment_$index',
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: row.comentarioEn,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Comentário da atividade (EN)',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    cancelTranslationTimer(
                                      'activity_comment_$index',
                                    );
                                    setModalState(() {
                                      final current = activities[index];
                                      activities[index] = current.copyWith(
                                        comentarioEn: value,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        const Divider(height: 20),
                        const SizedBox(height: 4),
                        Container(
                          key: tankSectionKey,
                          child: sectionTitle(
                            'Tanque',
                            subtitle:
                                'Selecione apenas se este RDO tiver lançamento por tanque.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (stagedTankDrafts.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _kCardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.playlist_add_check_rounded,
                                      size: 16,
                                      color: _kInk,
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'Tanques adicionados neste RDO',
                                        style: TextStyle(
                                          color: _kInk,
                                          fontSize: 12.7,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '${stagedTankDrafts.length}',
                                        style: const TextStyle(
                                          color: _kInk,
                                          fontSize: 11.8,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List<Widget>.generate(
                                    stagedTankDrafts.length,
                                    (index) {
                                      final label = describeTankDraft(
                                        stagedTankDrafts[index],
                                      );
                                      return InputChip(
                                        label: Text(
                                          label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        onDeleted: () {
                                          setModalState(() {
                                            stagedTankDrafts.removeAt(index);
                                            error = null;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (tankCatalog.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFED7AA),
                              ),
                            ),
                            child: Text(
                              noConfiguredTankMessage(),
                              style: const TextStyle(
                                color: Color(0xFF9A3412),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else ...<Widget>[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _kCardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Escolha o tanque',
                                  style: TextStyle(
                                    color: _kInk,
                                    fontSize: 12.6,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (availableSelectionTanks.isEmpty)
                                  Text(
                                    stagedTankDrafts.isNotEmpty
                                        ? noRemainingTankMessage()
                                        : 'Nenhum tanque disponível para seleção nesta OS.',
                                    style: const TextStyle(
                                      color: _kMutedInk,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  Column(
                                    children: availableSelectionTanks
                                        .map((item) {
                                          final selected =
                                              (selectedTankKey ?? '') ==
                                              item.key;
                                          final subtitleParts = <String>[
                                            if (item.servicoExec
                                                .trim()
                                                .isNotEmpty)
                                              item.servicoExec.trim(),
                                            if (item.metodoExec
                                                .trim()
                                                .isNotEmpty)
                                              item.metodoExec.trim(),
                                          ];
                                          final specs = <Widget>[
                                            if (item.tipoTanque
                                                .trim()
                                                .isNotEmpty)
                                              tankMetaChip(
                                                icon: Icons.category_rounded,
                                                label: item.tipoTanque.trim(),
                                                background: selected
                                                    ? const Color(0xFF1F2937)
                                                    : const Color(0xFFF3F4F6),
                                                foreground: selected
                                                    ? Colors.white
                                                    : _kInk,
                                              ),
                                            if (item.numeroCompartimentos
                                                .trim()
                                                .isNotEmpty)
                                              tankMetaChip(
                                                icon: Icons.view_week_rounded,
                                                label:
                                                    '${item.numeroCompartimentos.trim()} compart.',
                                                background: selected
                                                    ? const Color(0xFF1F2937)
                                                    : const Color(0xFFF3F4F6),
                                                foreground: selected
                                                    ? Colors.white
                                                    : _kInk,
                                              ),
                                          ];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Material(
                                              color: selected
                                                  ? const Color(0xFF111827)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                onTap: () {
                                                  var feedback =
                                                      'Tanque selecionado.';
                                                  setModalState(() {
                                                    if (selected) {
                                                      selectedTankKey = null;
                                                      clearTankFieldsForNew();
                                                      feedback =
                                                          'Tanque desmarcado.';
                                                    } else {
                                                      selectedTankKey =
                                                          item.key;
                                                      applyTankSnapshot(item);
                                                      feedback =
                                                          'Tanque ${item.label} selecionado.';
                                                    }
                                                    error = null;
                                                  });
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).hideCurrentSnackBar();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(feedback),
                                                      duration:
                                                          const Duration(
                                                            seconds: 2,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: Border.all(
                                                      color: selected
                                                          ? AppTheme
                                                                .supervisorLime
                                                          : _kCardBorder,
                                                      width: selected ? 1.6 : 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                          color: selected
                                                              ? AppTheme
                                                                    .supervisorLime
                                                              : const Color(
                                                                  0xFFF3F4F6,
                                                                ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          selected
                                                              ? Icons
                                                                    .check_rounded
                                                              : Icons
                                                                    .anchor_rounded,
                                                          color: _kInk,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: <Widget>[
                                                            Text(
                                                              item.label,
                                                              style: TextStyle(
                                                                color: selected
                                                                    ? Colors
                                                                          .white
                                                                    : _kInk,
                                                                fontSize: 13.8,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                            if (subtitleParts
                                                                .isNotEmpty) ...<
                                                              Widget
                                                            >[
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Text(
                                                                subtitleParts
                                                                    .join(
                                                                      ' • ',
                                                                    ),
                                                                style: TextStyle(
                                                                  color:
                                                                      selected
                                                                      ? Colors.white.withValues(
                                                                          alpha:
                                                                              0.78,
                                                                        )
                                                                      : _kMutedInk,
                                                                  fontSize:
                                                                      12.1,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                            if (specs
                                                                .isNotEmpty) ...<
                                                              Widget
                                                            >[
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              Wrap(
                                                                spacing: 8,
                                                                runSpacing: 8,
                                                                children: specs,
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        selected
                                                            ? Icons
                                                                  .radio_button_checked_rounded
                                                            : Icons
                                                                  .radio_button_off_rounded,
                                                        color: selected
                                                            ? AppTheme
                                                                  .supervisorLime
                                                            : _kMutedInk,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(growable: false),
                                  ),
                              ],
                            ),
                          ),
                          if (selectedTankOption() != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.supervisorLime.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Você está preenchendo agora',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                      fontSize: 11.4,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedTankOption()!.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      if (selectedTankOption()!.tanqueCodigo
                                          .trim()
                                          .isNotEmpty)
                                        tankMetaChip(
                                          icon: Icons.tag_rounded,
                                          label: selectedTankOption()!
                                              .tanqueCodigo
                                              .trim(),
                                          background: const Color(0xFF1F2937),
                                          foreground: Colors.white,
                                        ),
                                      if (selectedTankOption()!.servicoExec
                                          .trim()
                                          .isNotEmpty)
                                        tankMetaChip(
                                          icon: Icons.build_circle_rounded,
                                          label: selectedTankOption()!
                                              .servicoExec
                                              .trim(),
                                          background: const Color(0xFF1F2937),
                                          foreground: Colors.white,
                                        ),
                                      if (selectedTankOption()!.metodoExec
                                          .trim()
                                          .isNotEmpty)
                                        tankMetaChip(
                                          icon: Icons.settings_rounded,
                                          label: selectedTankOption()!
                                              .metodoExec
                                              .trim(),
                                          background: const Color(0xFF1F2937),
                                          foreground: Colors.white,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        if (selectedTankOption() != null) ...<Widget>[
                          const SizedBox(height: 8),
                          subsectionLabel(
                            'Identificação e características do tanque',
                            icon: Icons.inventory_2_rounded,
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'O nome e o código do tanque são preenchidos pelo Coordenador. Os demais campos abaixo podem ser completados pelo supervisor no app.',
                              style: TextStyle(
                                color: _kMutedInk,
                                fontSize: 12.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _kCardBorder),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.visibility_rounded,
                                  size: 16,
                                  color: _kMutedInk,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Confira abaixo os dados do tanque ${selectedTankOption()!.label}.',
                                    style: const TextStyle(
                                      color: _kMutedInk,
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: tipoTanque.isEmpty
                                ? null
                                : tipoTanque,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de tanque',
                              border: OutlineInputBorder(),
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'Salão',
                                child: Text('Salão'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Compartimento',
                                child: Text('Compartimento'),
                              ),
                            ],
                            onChanged: fixedFieldsLockedForSelectedTank()
                                ? null
                                : (value) {
                                    setModalState(() {
                                      tipoTanque = value ?? '';
                                      applyTipoTanqueLock();
                                    });
                                  },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: tanqueCompartimentosController,
                                  keyboardType: TextInputType.number,
                                  readOnly: fixedFieldsLockedForSelectedTank(),
                                  onChanged: fixedFieldsLockedForSelectedTank()
                                      ? null
                                      : (_) {
                                          setModalState(() {
                                            applyTipoTanqueLock();
                                          });
                                        },
                                  decoration: const InputDecoration(
                                    labelText: 'Nº de compartimentos',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: tanqueGavetasController,
                                  keyboardType: TextInputType.number,
                                  readOnly:
                                      fixedFieldsLockedForSelectedTank() ||
                                      isSalao(),
                                  decoration: const InputDecoration(
                                    labelText: 'Gavetas',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: tanquePatamarController,
                                  keyboardType: TextInputType.number,
                                  readOnly:
                                      fixedFieldsLockedForSelectedTank() ||
                                      isSalao(),
                                  decoration: const InputDecoration(
                                    labelText: 'Patamares',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: tanqueVolumeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  readOnly: fixedFieldsLockedForSelectedTank(),
                                  decoration: const InputDecoration(
                                    labelText: 'Volume executado (m³)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          subsectionLabel(
                            'Serviço e método de execução',
                            icon: Icons.build_circle_rounded,
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final serviceOptions = ensureChoiceContains(
                                serviceChoices,
                                tanqueServicoController.text,
                              );
                              if (serviceOptions.isEmpty) {
                                return TextField(
                                  controller: tanqueServicoController,
                                  readOnly: fixedFieldsLockedForSelectedTank(),
                                  decoration: const InputDecoration(
                                    labelText: 'Serviço executado',
                                    border: OutlineInputBorder(),
                                  ),
                                );
                              }
                              return InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: fixedFieldsLockedForSelectedTank()
                                    ? null
                                    : () async {
                                        final picked = await openChoicePicker(
                                          title: 'Selecionar serviço executado',
                                          options: serviceOptions,
                                          initialValue:
                                              tanqueServicoController.text,
                                          allowManualValue: true,
                                        );
                                        if (picked == null) {
                                          return;
                                        }
                                        setModalState(() {
                                          setControllerText(
                                            tanqueServicoController,
                                            picked.value,
                                          );
                                        });
                                      },
                                child: IgnorePointer(
                                  child: searchableChoiceDecorator(
                                    labelText: 'Serviço executado',
                                    hintText: 'Toque para buscar serviço',
                                    selectedLabel:
                                        tanqueServicoController.text
                                            .trim()
                                            .isEmpty
                                        ? ''
                                        : (findChoiceByValue(
                                                tanqueServicoController.text,
                                                serviceOptions,
                                              )?.label ??
                                              tanqueServicoController.text),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final methodOptions = ensureChoiceContains(
                                methodChoices,
                                tanqueMetodoController.text,
                              );
                              if (methodOptions.isEmpty) {
                                return TextField(
                                  controller: tanqueMetodoController,
                                  readOnly: fixedFieldsLockedForSelectedTank(),
                                  decoration: const InputDecoration(
                                    labelText: 'Método executado',
                                    border: OutlineInputBorder(),
                                  ),
                                );
                              }
                              return InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: fixedFieldsLockedForSelectedTank()
                                    ? null
                                    : () async {
                                        final picked = await openChoicePicker(
                                          title: 'Selecionar método executado',
                                          options: methodOptions,
                                          initialValue:
                                              tanqueMetodoController.text,
                                          allowManualValue: true,
                                        );
                                        if (picked == null) {
                                          return;
                                        }
                                        setModalState(() {
                                          setControllerText(
                                            tanqueMetodoController,
                                            picked.value,
                                          );
                                        });
                                      },
                                child: IgnorePointer(
                                  child: searchableChoiceDecorator(
                                    labelText: 'Método executado',
                                    hintText: 'Toque para buscar método',
                                    selectedLabel:
                                        tanqueMetodoController.text
                                            .trim()
                                            .isEmpty
                                        ? ''
                                        : (findChoiceByValue(
                                                tanqueMetodoController.text,
                                                methodOptions,
                                              )?.label ??
                                              tanqueMetodoController.text),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          sectionTitle(
                            'Espaço confinado',
                            subtitle:
                                'Preencha somente quando houver atividade em área confinada neste RDO.',
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: espacoConfinado.isEmpty
                                ? null
                                : espacoConfinado,
                            decoration: const InputDecoration(
                              labelText:
                                  'Houve acesso em espaço confinado neste dia?',
                              border: OutlineInputBorder(),
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'sim',
                                child: Text('Sim'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'nao',
                                child: Text('Não'),
                              ),
                            ],
                            onChanged: (value) {
                              setModalState(() {
                                espacoConfinado = value ?? '';
                                applyEcLock();
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: operadoresController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Operadores simultâneos',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: efetivoConfinadoController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Efetivo no confinado (nº)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: h2sController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'H2S (ppm)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: lelController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'LEL',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: coController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'CO (ppm)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: o2Controller,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'O2 (%)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          sectionTitle(
                            'Entradas e saídas no confinado',
                            subtitle:
                                'Registre os intervalos de entrada/saída da equipe no espaço confinado.',
                          ),
                          const SizedBox(height: 6),
                          IgnorePointer(
                            ignoring: espacoConfinado == 'nao',
                            child: Opacity(
                              opacity: espacoConfinado == 'nao' ? 0.55 : 1,
                              child: Column(
                                children: List<Widget>.generate(6, (index) {
                                  final row = ecTimes[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _kCardBorder),
                                      borderRadius: BorderRadius.circular(10),
                                      color: const Color(0xFFF9FAFB),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: TextFormField(
                                            key: ValueKey<String>(
                                              'ec-entry-$index-${row.entrada == null ? 'empty' : _formatTimeOfDay(row.entrada!)}',
                                            ),
                                            initialValue: row.entrada == null
                                                ? ''
                                                : _formatTimeOfDay(
                                                    row.entrada!,
                                                  ),
                                            keyboardType:
                                                TextInputType.datetime,
                                            decoration: InputDecoration(
                                              labelText:
                                                  'Entrada ${index + 1} (hora)',
                                              hintText: '08:00',
                                              border:
                                                  const OutlineInputBorder(),
                                              suffixIcon: IconButton(
                                                icon: const Icon(
                                                  Icons.schedule_rounded,
                                                ),
                                                onPressed: () async {
                                                  final picked =
                                                      await showTimePicker(
                                                        context: modalContext,
                                                        initialTime:
                                                            row.entrada ??
                                                            TimeOfDay.now(),
                                                      );
                                                  if (picked == null) {
                                                    return;
                                                  }
                                                  setModalState(() {
                                                    ecTimes[index] = row
                                                        .copyWith(
                                                          entrada: picked,
                                                        );
                                                  });
                                                },
                                              ),
                                            ),
                                            onChanged: (value) {
                                              final parsed = parseTimeValue(
                                                value,
                                              );
                                              setModalState(() {
                                                if (value.trim().isEmpty) {
                                                  ecTimes[index] = row.copyWith(
                                                    entrada: null,
                                                  );
                                                } else if (parsed != null) {
                                                  ecTimes[index] = row.copyWith(
                                                    entrada: parsed,
                                                  );
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            key: ValueKey<String>(
                                              'ec-exit-$index-${row.saida == null ? 'empty' : _formatTimeOfDay(row.saida!)}',
                                            ),
                                            initialValue: row.saida == null
                                                ? ''
                                                : _formatTimeOfDay(row.saida!),
                                            keyboardType:
                                                TextInputType.datetime,
                                            decoration: InputDecoration(
                                              labelText:
                                                  'Saída ${index + 1} (hora)',
                                              hintText: '12:00',
                                              border:
                                                  const OutlineInputBorder(),
                                              suffixIcon: IconButton(
                                                icon: const Icon(
                                                  Icons.schedule_rounded,
                                                ),
                                                onPressed: () async {
                                                  final picked =
                                                      await showTimePicker(
                                                        context: modalContext,
                                                        initialTime:
                                                            row.saida ??
                                                            TimeOfDay.now(),
                                                      );
                                                  if (picked == null) {
                                                    return;
                                                  }
                                                  setModalState(() {
                                                    ecTimes[index] = row
                                                        .copyWith(
                                                          saida: picked,
                                                        );
                                                  });
                                                },
                                              ),
                                            ),
                                            onChanged: (value) {
                                              final parsed = parseTimeValue(
                                                value,
                                              );
                                              setModalState(() {
                                                if (value.trim().isEmpty) {
                                                  ecTimes[index] = row.copyWith(
                                                    saida: null,
                                                  );
                                                } else if (parsed != null) {
                                                  ecTimes[index] = row.copyWith(
                                                    saida: parsed,
                                                  );
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Limpar intervalo',
                                          onPressed: () {
                                            setModalState(() {
                                              ecTimes[index] =
                                                  const _EcTimeDraft();
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          sectionTitle(
                            'Dados operacionais',
                            subtitle:
                                'Preencha os campos diários. Os campos acumulados são calculados automaticamente.',
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _kCardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kGreenSoft,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.supervisorLime.withValues(
                                        alpha: .55,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Organização dos dados: Previsão inicial, Produção diária (RDO atual) e Acumulado da operação.',
                                    style: TextStyle(
                                      color: _kInk,
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                subsectionLabel(
                                  '1) Previsão inicial',
                                  icon: Icons.event_note_rounded,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: ensacamentoPrevController,
                                        keyboardType: TextInputType.number,
                                        readOnly: predictionsLocked,
                                        decoration: InputDecoration(
                                          labelText: 'Ensacamento previsto',
                                          border: const OutlineInputBorder(),
                                          filled: predictionsLocked,
                                          fillColor: predictionsLocked
                                              ? const Color(0xFFF3F4F6)
                                              : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller: icamentoPrevController,
                                        label: 'Içamento previsto',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: cambagemPrevController,
                                        keyboardType: TextInputType.number,
                                        readOnly: predictionsLocked,
                                        decoration: InputDecoration(
                                          labelText: 'Cambagem prevista',
                                          border: const OutlineInputBorder(),
                                          filled: predictionsLocked,
                                          fillColor: predictionsLocked
                                              ? const Color(0xFFF3F4F6)
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (predictionsLocked) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _kCardBorder),
                                    ),
                                    child: const Text(
                                      'Previsoes deste tanque ja foram definidas no primeiro RDO e estao bloqueadas.',
                                      style: TextStyle(
                                        color: _kMutedInk,
                                        fontSize: 11.8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                subsectionLabel(
                                  '2) Produção diária (RDO atual)',
                                  icon: Icons.today_rounded,
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () async {
                                    final sentidoOptions = ensureChoiceContains(
                                      localSentidoChoices,
                                      sentidoLimpeza,
                                    );
                                    final picked = await openChoicePicker(
                                      title: 'Selecionar sentido da limpeza',
                                      options: sentidoOptions,
                                      initialValue: sentidoLimpeza,
                                      allowManualValue: true,
                                    );
                                    if (picked == null) {
                                      return;
                                    }
                                    setModalState(() {
                                      sentidoLimpeza = picked.value;
                                    });
                                  },
                                  child: IgnorePointer(
                                    child: searchableChoiceDecorator(
                                      labelText: 'Sentido da limpeza (dia)',
                                      hintText: 'Toque para buscar sentido',
                                      selectedLabel:
                                          sentidoLimpeza.trim().isEmpty
                                          ? ''
                                          : (findChoiceByValue(
                                                  sentidoLimpeza,
                                                  ensureChoiceContains(
                                                    localSentidoChoices,
                                                    sentidoLimpeza,
                                                  ),
                                                )?.label ??
                                                sentidoLimpeza),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: tempoBombaController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (_) {
                                          setModalState(recomputeOperational);
                                        },
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Tempo de bomba diário (h)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller: bombeioController,
                                        label: 'Bombeio diário (auto)',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller: totalLiquidoController,
                                        label: 'Resíduo líquido diário (auto)',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: ensacamentoDiaController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setModalState(recomputeOperational);
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Ensacamento diário',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: icamentoDiaController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setModalState(recomputeOperational);
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Içamento diário',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: cambagemDiaController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setModalState(recomputeOperational);
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Cambagem diária',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: tamboresDiaController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setModalState(recomputeOperational);
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Tambores diários',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller: residuosSolidosController,
                                        label: 'Resíduo sólido diário (auto)',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller: residuosTotaisController,
                                        label: 'Resíduo total diário (auto)',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                subsectionLabel(
                                  '3) Acumulado da operação',
                                  icon: Icons.summarize_rounded,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: readonlyField(
                                        controller: ensacamentoAcuController,
                                        label: 'Ensacamento acumulado',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller: icamentoAcuController,
                                        label: 'Içamento acumulado',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller: cambagemAcuController,
                                        label: 'Cambagem acumulada',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: readonlyField(
                                        controller: tamboresAcuController,
                                        label: 'Tambores acumulados',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller: totalLiquidoAcuController,
                                        label: 'Resíduo líquido acumulado',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: readonlyField(
                                        controller:
                                            residuosSolidosAcuController,
                                        label: 'Resíduo sólido acumulado',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final metrics = compartmentMetricsSnapshot();

                              Widget metaPill(
                                String label, {
                                Color background = const Color(0xFFFFFFFF),
                                Color foreground = _kMutedInk,
                              }) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: background,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: _kCardBorder),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: foreground,
                                      fontSize: 11.4,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }

                              Widget phaseCard({
                                required int comp,
                                required String title,
                                required bool fina,
                              }) {
                                final snapshot = compartmentPhaseSnapshot(
                                  comp,
                                  fina: fina,
                                );
                                final otherSnapshot = compartmentPhaseSnapshot(
                                  comp,
                                  fina: !fina,
                                );
                                final selected = selectedCompartimentos
                                    .contains(comp);
                                final enabled = selected && !snapshot.blocked;
                                final maxFinalValue =
                                    ((snapshot.previous + snapshot.remaining)
                                                .clamp(snapshot.previous, 100)
                                            as num)
                                        .toDouble();
                                final currentFinalValue =
                                    (snapshot.finalValue.toDouble().clamp(
                                              snapshot.previous.toDouble(),
                                              maxFinalValue,
                                            )
                                            as num)
                                        .toDouble();
                                final divisions =
                                    maxFinalValue > snapshot.previous.toDouble()
                                    ? (maxFinalValue -
                                              snapshot.previous.toDouble())
                                          .round()
                                    : null;
                                final stateLabel = snapshot.blocked
                                    ? 'Concluída'
                                    : (!selected ? 'Selecionar' : 'Disponível');
                                final stateBg = snapshot.blocked
                                    ? const Color(0xFFDFF7E8)
                                    : (!selected
                                          ? const Color(0xFFFFF4D6)
                                          : const Color(0xFFE2F0FF));
                                final stateFg = snapshot.blocked
                                    ? const Color(0xFF166534)
                                    : (!selected
                                          ? const Color(0xFF8A6100)
                                          : const Color(0xFF1D4ED8));
                                var helpText = '';
                                if (snapshot.blocked) {
                                  helpText = otherSnapshot.blocked
                                      ? 'Frente concluída neste compartimento.'
                                      : (fina
                                            ? 'Limpeza fina concluída.'
                                            : 'Mecanizada/manual concluída.');
                                } else if (!selected) {
                                  helpText =
                                      'Selecione o compartimento acima para lançar avanço hoje.';
                                } else if (otherSnapshot.blocked) {
                                  helpText =
                                      'A outra frente já está concluída.';
                                }

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _kCardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                color: _kInk,
                                                fontSize: 12.4,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: stateBg,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              stateLabel,
                                              style: TextStyle(
                                                color: stateFg,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 12,
                                          inactiveTrackColor: const Color(
                                            0xFFDCE3EA,
                                          ),
                                          activeTrackColor: const Color(
                                            0xFF3BA55C,
                                          ),
                                          thumbColor: const Color(0xFF0A5A2F),
                                          overlayShape:
                                              SliderComponentShape.noOverlay,
                                        ),
                                        child: Slider(
                                          min: snapshot.previous.toDouble(),
                                          max: maxFinalValue,
                                          divisions: divisions,
                                          value: currentFinalValue,
                                          onChanged: enabled
                                              ? (value) {
                                                  setModalState(() {
                                                    final accepted =
                                                        (((value.round() -
                                                                        snapshot
                                                                            .previous)
                                                                    .clamp(
                                                                      0,
                                                                      snapshot
                                                                          .remaining,
                                                                    ))
                                                                as num)
                                                            .toInt();
                                                    final current =
                                                        compartmentProgress[comp] ??
                                                        const _CompartmentProgressDraft();
                                                    compartmentProgress[comp] =
                                                        fina
                                                        ? current.copyWith(
                                                            fina: accepted,
                                                          )
                                                        : current.copyWith(
                                                            mecanizada:
                                                                accepted,
                                                          );
                                                    recomputeCompartimentos();
                                                  });
                                                }
                                              : null,
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          '${snapshot.finalValue}%',
                                          style: const TextStyle(
                                            color: _kInk,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: <Widget>[
                                          metaPill(
                                            'Acumulado: ${snapshot.finalValue}%',
                                          ),
                                          metaPill(
                                            'Disponível hoje: ${snapshot.remaining}%',
                                          ),
                                        ],
                                      ),
                                      if (helpText.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 8),
                                        Text(
                                          helpText,
                                          style: const TextStyle(
                                            color: _kMutedInk,
                                            fontSize: 11.6,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  sectionTitle(
                                    'Avanço por compartimento',
                                    subtitle:
                                        'Selecione os compartimentos trabalhados no dia. A barra mostra o acumulado do compartimento; o envio continua sendo apenas o avanço de hoje.',
                                  ),
                                  const SizedBox(height: 6),
                                  if (totalCompartimentos <= 0)
                                    const Text(
                                      'Informe o número de compartimentos para liberar os controles de avanço.',
                                      style: TextStyle(
                                        color: _kMutedInk,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else ...<Widget>[
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: List<Widget>.generate(
                                        totalCompartimentos,
                                        (idx) {
                                          final comp = idx + 1;
                                          final selected =
                                              selectedCompartimentos.contains(
                                                comp,
                                              );
                                          final blocked = compartmentCompleted(
                                            comp,
                                          );
                                          final availability =
                                              compartmentAvailabilityLabel(
                                                comp,
                                              );
                                          final bgColor = blocked
                                              ? const Color(0xFFDFF7E8)
                                              : (availability == 'Fina'
                                                    ? const Color(0xFFFFF4D6)
                                                    : availability == 'Mec.'
                                                    ? const Color(0xFFE2F0FF)
                                                    : selected
                                                    ? const Color(0xFFE8FBF0)
                                                    : const Color(0xFFF8FAFC));
                                          final borderColor = blocked
                                              ? const Color(0xFFBBF7D0)
                                              : (availability == 'Fina'
                                                    ? const Color(0xFFFED7AA)
                                                    : availability == 'Mec.'
                                                    ? const Color(0xFFBFDBFE)
                                                    : selected
                                                    ? const Color(0xFFB7E4C7)
                                                    : _kCardBorder);
                                          final fgColor = blocked
                                              ? const Color(0xFF166534)
                                              : (availability == 'Fina'
                                                    ? const Color(0xFF8A6100)
                                                    : availability == 'Mec.'
                                                    ? const Color(0xFF1D4ED8)
                                                    : _kInk);
                                          return InkWell(
                                            onTap: blocked
                                                ? null
                                                : () {
                                                    setModalState(() {
                                                      if (selected) {
                                                        selectedCompartimentos
                                                            .remove(comp);
                                                        compartmentProgress[comp] =
                                                            const _CompartmentProgressDraft();
                                                      } else {
                                                        selectedCompartimentos
                                                            .add(comp);
                                                        compartmentProgress
                                                            .putIfAbsent(
                                                              comp,
                                                              () =>
                                                                  const _CompartmentProgressDraft(),
                                                            );
                                                      }
                                                      recomputeCompartimentos();
                                                    });
                                                  },
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 160,
                                              ),
                                              width: 74,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: borderColor,
                                                ),
                                              ),
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: <Widget>[
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: <Widget>[
                                                      Text(
                                                        '$comp',
                                                        style: TextStyle(
                                                          color: fgColor,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                      if (availability !=
                                                          null) ...<Widget>[
                                                        const SizedBox(
                                                          height: 3,
                                                        ),
                                                        Text(
                                                          availability,
                                                          style: TextStyle(
                                                            color: fgColor,
                                                            fontSize: 9.8,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (selected)
                                                    Positioned(
                                                      top: -2,
                                                      right: -2,
                                                      child: Container(
                                                        width: 18,
                                                        height: 18,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          border: Border.all(
                                                            color: borderColor,
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.check_rounded,
                                                          size: 12,
                                                          color: Color(
                                                            0xFF0A5A2F,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Diário mec.: ${formatDecimal(metrics.dailyM, precision: 2)}%  •  Cumulativo mec.: ${formatDecimal(metrics.cumulativeM, precision: 2)}%\nDiário fina: ${formatDecimal(metrics.dailyF, precision: 2)}%  •  Cumulativo fina: ${formatDecimal(metrics.cumulativeF, precision: 2)}%',
                                      style: const TextStyle(
                                        color: _kMutedInk,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (sortedSelectedCompartimentos
                                        .isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 8),
                                      ...sortedSelectedCompartimentos.map((
                                        comp,
                                      ) {
                                        final mecanizada =
                                            compartmentPhaseSnapshot(
                                              comp,
                                              fina: false,
                                            );
                                        final fina = compartmentPhaseSnapshot(
                                          comp,
                                          fina: true,
                                        );
                                        final rowStatus =
                                            mecanizada.blocked && fina.blocked
                                            ? 'Compartimento concluído'
                                            : (mecanizada.blocked
                                                  ? 'Mecanizada concluída; avance só fina'
                                                  : (fina.blocked
                                                        ? 'Fina concluída; avance só mecanizada'
                                                        : 'Lançamento ativo'));
                                        final rowStatusColor =
                                            mecanizada.blocked && fina.blocked
                                            ? const Color(0xFF166534)
                                            : (mecanizada.blocked ||
                                                      fina.blocked
                                                  ? const Color(0xFF8A6100)
                                                  : const Color(0xFF1D4ED8));
                                        final rowStatusBg =
                                            mecanizada.blocked && fina.blocked
                                            ? const Color(0xFFDFF7E8)
                                            : (mecanizada.blocked ||
                                                      fina.blocked
                                                  ? const Color(0xFFFFF4D6)
                                                  : const Color(0xFFE2F0FF));
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: _kCardBorder,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: Colors.white,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Text(
                                                      'Compartimento $comp',
                                                      style: const TextStyle(
                                                        color: _kInk,
                                                        fontSize: 12.8,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: rowStatusBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      rowStatus,
                                                      style: TextStyle(
                                                        color: rowStatusColor,
                                                        fontSize: 10.8,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              phaseCard(
                                                comp: comp,
                                                title:
                                                    'Mecanizada / Manual / Robotizada',
                                                fina: false,
                                              ),
                                              const SizedBox(height: 8),
                                              phaseCard(
                                                comp: comp,
                                                title: 'Limpeza fina',
                                                fina: true,
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ] else ...<Widget>[
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Selecione os compartimentos acima para lançar o avanço do dia.',
                                        style: TextStyle(
                                          color: _kMutedInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: readonlyField(
                                  controller: limpezaDiariaController,
                                  label: 'Limpeza diária média (%)',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: readonlyField(
                                  controller: limpezaFinaDiariaController,
                                  label: 'Limpeza fina diária média (%)',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: readonlyField(
                                  controller: limpezaAcuController,
                                  label: 'Limpeza acumulada (%)',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: readonlyField(
                                  controller: limpezaFinaAcuController,
                                  label: 'Limpeza fina acumulada (%)',
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        sectionTitle(
                          'Observações e equipe',
                          subtitle:
                              'Texto em PT com tradução automática para EN e cadastro da equipe em serviço.',
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: observacoesController,
                          minLines: 2,
                          maxLines: 4,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Observações do dia (PT)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: observacoesEnController,
                          minLines: 2,
                          maxLines: 4,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Observações do dia (EN)',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFFF3F4F6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: planejamentoController,
                          minLines: 2,
                          maxLines: 4,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Planejamento próximo turno (PT)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: planejamentoEnController,
                          minLines: 2,
                          maxLines: 4,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Planejamento próximo turno (EN)',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFFF3F4F6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Membros da equipe (${teamMembers.length})',
                                    style: const TextStyle(
                                      color: _kMutedInk,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Inclua apenas quem atuou neste RDO.',
                                    style: TextStyle(
                                      color: _kMutedInk,
                                      fontSize: 11.8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: teamMembers.length >= 20
                                  ? null
                                  : () {
                                      setModalState(() {
                                        teamMembers.add(
                                          const _TeamMemberDraft(),
                                        );
                                      });
                                    },
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Adicionar'),
                            ),
                          ],
                        ),
                        ...teamMembers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          final personOptions = ensureChoiceContains(
                            personChoices,
                            row.nome,
                          );
                          final functionOptions = ensureChoiceContains(
                            functionChoices,
                            row.funcao,
                          );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: _kCardBorder),
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF9FAFB),
                            ),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        'Membro ${index + 1}',
                                        style: const TextStyle(
                                          color: _kInk,
                                          fontSize: 12.6,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remover membro',
                                      onPressed: teamMembers.length <= 1
                                          ? null
                                          : () {
                                              setModalState(() {
                                                teamMembers.removeAt(index);
                                              });
                                            },
                                      icon: const Icon(
                                        Icons.person_remove_alt_1_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                if (personOptions.isEmpty)
                                  TextFormField(
                                    initialValue: row.nome,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome da pessoa (manual)',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      setModalState(() {
                                        teamMembers[index] = row.copyWith(
                                          nome: value,
                                          pessoaId: '',
                                        );
                                      });
                                    },
                                  )
                                else
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () async {
                                      final picked = await openChoicePicker(
                                        title: 'Selecionar membro da equipe',
                                        options: personOptions,
                                        initialValue: row.nome,
                                        allowManualValue: true,
                                      );
                                      if (picked == null) {
                                        return;
                                      }
                                      final matched = findChoiceByValue(
                                        picked.value,
                                        personOptions,
                                      );
                                      setModalState(() {
                                        teamMembers[index] = row.copyWith(
                                          nome:
                                              matched?.label
                                                      .trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? matched!.label.trim()
                                              : picked.value.trim(),
                                          pessoaId: matched?.value ?? '',
                                        );
                                      });
                                    },
                                    child: IgnorePointer(
                                      child: searchableChoiceDecorator(
                                        labelText: 'Nome da pessoa',
                                        hintText: 'Toque para buscar pessoa',
                                        selectedLabel: row.nome.trim().isEmpty
                                            ? ''
                                            : (findChoiceByValue(
                                                    row.nome,
                                                    personOptions,
                                                  )?.label ??
                                                  row.nome),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (functionOptions.isEmpty)
                                  TextFormField(
                                    initialValue: row.funcao,
                                    decoration: const InputDecoration(
                                      labelText: 'Função',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      setModalState(() {
                                        teamMembers[index] = row.copyWith(
                                          funcao: value,
                                        );
                                      });
                                    },
                                  )
                                else
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () async {
                                      final picked = await openChoicePicker(
                                        title: 'Selecionar função',
                                        options: functionOptions,
                                        initialValue: row.funcao,
                                        allowManualValue: true,
                                      );
                                      if (picked == null) {
                                        return;
                                      }
                                      final matched = findChoiceByValue(
                                        picked.value,
                                        functionOptions,
                                      );
                                      setModalState(() {
                                        teamMembers[index] = row.copyWith(
                                          funcao:
                                              matched?.value ?? picked.value,
                                        );
                                      });
                                    },
                                    child: IgnorePointer(
                                      child: searchableChoiceDecorator(
                                        labelText: 'Função',
                                        hintText: 'Toque para buscar função',
                                        selectedLabel: row.funcao.trim().isEmpty
                                            ? ''
                                            : (findChoiceByValue(
                                                    row.funcao,
                                                    functionOptions,
                                                  )?.label ??
                                                  row.funcao),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    const Expanded(
                                      child: Text(
                                        'Em serviço neste RDO',
                                        style: TextStyle(
                                          color: _kMutedInk,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: row.emServico,
                                      onChanged: (checked) {
                                        setModalState(() {
                                          teamMembers[index] = row.copyWith(
                                            emServico: checked,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        sectionTitle(
                          'Fotos',
                          subtitle:
                              'Anexe até $_kMaxRdoPhotos fotos. Elas serão enviadas na sincronização.',
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: _kCardBorder),
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      '${photos.length}/$_kMaxRdoPhotos foto(s) carregada(s)',
                                      style: const TextStyle(
                                        color: _kMutedInk,
                                        fontSize: 12.3,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: photos.length >= _kMaxRdoPhotos
                                          ? const Color(0xFFFFF4D8)
                                          : const Color(0xFFEAF4FF),
                                      border: Border.all(
                                        color: photos.length >= _kMaxRdoPhotos
                                            ? const Color(0xFFF2B648)
                                            : const Color(0xFFB6D7FF),
                                      ),
                                    ),
                                    child: Text(
                                      photos.length >= _kMaxRdoPhotos
                                          ? 'Limite atingido'
                                          : 'Restam ${_kMaxRdoPhotos - photos.length}',
                                      style: TextStyle(
                                        color: photos.length >= _kMaxRdoPhotos
                                            ? const Color(0xFF8A5A00)
                                            : const Color(0xFF1F4D8A),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: photos.length / _kMaxRdoPhotos,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(999),
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  photos.length >= _kMaxRdoPhotos
                                      ? const Color(0xFFF2B648)
                                      : const Color(0xFF4D6F00),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  OutlinedButton.icon(
                                    onPressed: photos.length >= _kMaxRdoPhotos
                                        ? null
                                        : () async {
                                            await pickPhotoFromCamera(
                                              setModalState,
                                            );
                                          },
                                    icon: const Icon(Icons.camera_alt_rounded),
                                    label: const Text('Câmera'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: photos.length >= _kMaxRdoPhotos
                                        ? null
                                        : () async {
                                            await pickPhotosFromGallery(
                                              setModalState,
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.photo_library_rounded,
                                    ),
                                    label: const Text('Galeria'),
                                  ),
                                ],
                              ),
                              if (photos.isEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                const Text(
                                  'Nenhuma foto adicionada neste RDO.',
                                  style: TextStyle(
                                    color: _kMutedInk,
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...<Widget>[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: photos
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final index = entry.key;
                                        final photo = entry.value;
                                        return Container(
                                          width: 86,
                                          height: 86,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: _kCardBorder,
                                            ),
                                            image: DecorationImage(
                                              image: MemoryImage(photo.bytes),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          child: Stack(
                                            children: <Widget>[
                                              Positioned(
                                                left: 4,
                                                bottom: 4,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xCC1F7A1F,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: <Widget>[
                                                      Icon(
                                                        Icons.check_circle,
                                                        size: 11,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'Carregada',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 4,
                                                top: 4,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setModalState(() {
                                                      photos.removeAt(index);
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xCC111111,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.close_rounded,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (error != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: Color(0xFF7F1D1D),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (availableSelectionTanks.length > 1) ...<Widget>[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final tankDraft = resolveCurrentTankDraft(
                                  setModalState,
                                  requireTank: true,
                                );
                                if (tankDraft == null ||
                                    tankDraft.mode == _TankMode.none) {
                                  return;
                                }

                                final tankLabel = describeTankDraft(tankDraft);
                                var hasNextTank = false;
                                setModalState(() {
                                  stagedTankDrafts.add(tankDraft);
                                  error = null;
                                  selectNextAvailableTankOrClear();
                                  hasNextTank = availableTankSelectionOptions()
                                      .isNotEmpty;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tankLabel.trim().isEmpty
                                          ? hasNextTank
                                                ? 'Tanque adicionado. Continue preenchendo o próximo tanque.'
                                                : 'Último tanque adicionado. Agora finalize o RDO.'
                                          : hasNextTank
                                          ? 'Tanque $tankLabel adicionado. Continue preenchendo o próximo tanque.'
                                          : 'Tanque $tankLabel adicionado. Agora finalize o RDO.',
                                    ),
                                  ),
                                );
                                scrollToTankSection();
                              },
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              label: const Text(
                                'Salvar e adicionar outro tanque',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(modalContext).pop();
                                },
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.supervisorLime,
                                  foregroundColor: _kInk,
                                ),
                                onPressed: () {
                                  if (!validateActivities(setModalState)) {
                                    return;
                                  }

                                  final currentTankDraft =
                                      resolveCurrentTankDraft(
                                        setModalState,
                                        requireTank: false,
                                      );
                                  if (currentTankDraft == null) {
                                    return;
                                  }

                                  final allTankDrafts = <_TankDraft>[
                                    ...stagedTankDrafts,
                                  ];
                                  if (currentTankDraft.mode != _TankMode.none) {
                                    allTankDrafts.add(currentTankDraft);
                                  }
                                  if (allTankDrafts.isEmpty) {
                                    allTankDrafts.add(const _TankDraft.none());
                                  }

                                  Navigator.of(modalContext).pop(
                                    _CreateRdoDraft(
                                      businessDate: businessDate,
                                      turno: turno,
                                      observacoes: observacoesController.text,
                                      observacoesEn:
                                          observacoesEnController.text,
                                      planejamento: planejamentoController.text,
                                      planejamentoEn:
                                          planejamentoEnController.text,
                                      ptAbertura: ptAbertura,
                                      ptTurnos: ptTurnos.toList(
                                        growable: false,
                                      ),
                                      ptNumManha: ptManhaController.text,
                                      ptNumTarde: ptTardeController.text,
                                      ptNumNoite: ptNoiteController.text,
                                      ecTimes: ecTimes
                                          .map((item) => item.copyWith())
                                          .toList(growable: false),
                                      teamMembers: teamMembers
                                          .map((item) => item.copyWith())
                                          .toList(growable: false),
                                      tank: allTankDrafts.first,
                                      tanks: allTankDrafts,
                                      activities: activities
                                          .map((item) => item.copyWith())
                                          .toList(growable: false),
                                      photos: photos
                                          .map((item) => item.copyWith())
                                          .toList(growable: false),
                                    ),
                                  );
                                },
                                child: const Text('Enviar RDO'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      isSheetOpen = false;
      cancelAllTranslationTimers();
      observacoesController.removeListener(syncMainTranslationPreviews);
      planejamentoController.removeListener(syncMainTranslationPreviews);
      observacoesController.dispose();
      planejamentoController.dispose();
      observacoesEnController.dispose();
      planejamentoEnController.dispose();

      ptManhaController.dispose();
      ptTardeController.dispose();
      ptNoiteController.dispose();

      tanqueCodigoController.dispose();
      tanqueNomeController.dispose();
      tanqueCompartimentosController.dispose();
      tanqueGavetasController.dispose();
      tanquePatamarController.dispose();
      tanqueVolumeController.dispose();
      tanqueServicoController.dispose();
      tanqueMetodoController.dispose();

      operadoresController.dispose();
      efetivoConfinadoController.dispose();
      h2sController.dispose();
      lelController.dispose();
      coController.dispose();
      o2Controller.dispose();

      ensacamentoPrevController.dispose();
      icamentoPrevController.dispose();
      cambagemPrevController.dispose();

      tempoBombaController.dispose();
      bombeioController.dispose();
      totalLiquidoController.dispose();

      ensacamentoDiaController.dispose();
      icamentoDiaController.dispose();
      cambagemDiaController.dispose();
      tamboresDiaController.dispose();

      residuosSolidosController.dispose();
      residuosTotaisController.dispose();

      ensacamentoAcuController.dispose();
      icamentoAcuController.dispose();
      cambagemAcuController.dispose();
      tamboresAcuController.dispose();
      totalLiquidoAcuController.dispose();
      residuosSolidosAcuController.dispose();

      limpezaDiariaController.dispose();
      limpezaFinaDiariaController.dispose();
      limpezaAcuController.dispose();
      limpezaFinaAcuController.dispose();
      modalScrollController.dispose();
    }
  }

  String _normalizeTankIdentityToken(String raw) {
    var text = raw.trim().toLowerCase();
    if (text.isEmpty) {
      return '';
    }

    const accentMap = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    accentMap.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    text = text.replaceAll(RegExp(r'\b(tanque|tank)\b'), ' ');
    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return text.trim();
  }

  String? _buildTankIdentityKey(String code, String name) {
    final normalizedCode = _normalizeTankIdentityToken(code);
    final normalizedName = _normalizeTankIdentityToken(name);

    if (normalizedCode.isNotEmpty && normalizedName.isNotEmpty) {
      if (normalizedCode == normalizedName) {
        return 'tank:$normalizedCode';
      }
      if (normalizedName.contains(normalizedCode)) {
        return 'tank:$normalizedCode';
      }
      if (normalizedCode.contains(normalizedName)) {
        return 'tank:$normalizedName';
      }
      return 'tank:$normalizedCode';
    }
    if (normalizedCode.isNotEmpty) {
      return 'tank:$normalizedCode';
    }
    if (normalizedName.isNotEmpty) {
      return 'tank:$normalizedName';
    }
    return null;
  }

  int _resolveTankCreationLimit(AssignedOsItem assigned) {
    final explicitLimit = assigned.maxTanquesServicos;
    if (explicitLimit != null && explicitLimit > 0) {
      return explicitLimit;
    }
    if (assigned.servicosCount > 0) {
      return assigned.servicosCount;
    }
    return 0;
  }

  Set<String> _collectKnownTankIdentityKeys(
    AssignedOsItem assigned,
    List<_TankCatalogOption> tankCatalog,
  ) {
    final keys = <String>{};

    void append(String code, String name) {
      final key = _buildTankIdentityKey(code, name);
      if (key != null) {
        keys.add(key);
      }
    }

    for (final tank in assigned.availableTanks) {
      append(tank.tanqueCodigo, tank.nomeTanque);
    }
    for (final option in tankCatalog) {
      append(option.tanqueCodigo, option.tanqueNome);
    }
    return keys;
  }

  int _resolveCurrentOsTankCount(
    AssignedOsItem assigned,
    List<_TankCatalogOption> tankCatalog,
  ) {
    var count = assigned.totalTanquesOs;
    if (assigned.availableTanks.length > count) {
      count = assigned.availableTanks.length;
    }
    if (tankCatalog.length > count) {
      count = tankCatalog.length;
    }
    if (count < 0) {
      return 0;
    }
    return count;
  }

  int _coerceCompartmentPercent(dynamic rawValue) {
    if (rawValue == null) {
      return 0;
    }
    final normalized = '$rawValue'
        .trim()
        .replaceAll('%', '')
        .replaceAll(',', '.');
    if (normalized.isEmpty) {
      return 0;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite) {
      return 0;
    }
    return ((parsed.round()).clamp(0, 100) as num).toInt();
  }

  Map<int, _CompartmentProgressDraft> _parseCompartimentosPayloadJson(
    String raw, {
    int totalCompartimentos = 0,
  }) {
    final payload = <int, _CompartmentProgressDraft>{};
    if (totalCompartimentos > 0) {
      for (var i = 1; i <= totalCompartimentos; i++) {
        payload[i] = const _CompartmentProgressDraft();
      }
    }

    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return payload;
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return payload;
      }
      decoded.forEach((key, value) {
        final idx = int.tryParse('$key');
        if (idx == null || idx <= 0) {
          return;
        }
        if (value is! Map) {
          payload.putIfAbsent(idx, () => const _CompartmentProgressDraft());
          return;
        }
        final entry = Map<String, dynamic>.from(value);
        payload[idx] = _CompartmentProgressDraft(
          mecanizada: _coerceCompartmentPercent(
            entry['mecanizada'] ?? entry['m'] ?? entry['manual'],
          ),
          fina: _coerceCompartmentPercent(entry['fina'] ?? entry['f']),
        );
      });
    } catch (_) {
      return payload;
    }

    return payload;
  }

  int _inferCompartimentosTotalFromPayloadJsons(List<String?> raws) {
    var maxIndex = 0;
    for (final raw in raws) {
      final normalized = (raw ?? '').trim();
      if (normalized.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(normalized);
        if (decoded is! Map) {
          continue;
        }
        for (final key in decoded.keys) {
          final idx = int.tryParse('$key') ?? 0;
          if (idx > maxIndex) {
            maxIndex = idx;
          }
        }
      } catch (_) {
        continue;
      }
    }
    return maxIndex;
  }

  Map<int, _CompartmentProgressDraft> _buildTankPreviousCompartimentos(
    AssignedOsItem assigned,
    List<PendingSyncItem> queueItems, {
    required String tanqueCodigo,
    required String tanqueNome,
    int totalCompartimentos = 0,
  }) {
    final logicalKey = _buildTankIdentityKey(tanqueCodigo, tanqueNome);
    if (logicalKey == null) {
      return <int, _CompartmentProgressDraft>{};
    }

    void ensureCompartimentoSlots(
      Map<int, _CompartmentProgressDraft> target,
      int desiredTotal,
    ) {
      if (desiredTotal <= 0) {
        return;
      }
      for (var i = 1; i <= desiredTotal; i++) {
        target.putIfAbsent(i, () => const _CompartmentProgressDraft());
      }
    }

    void applyPayloadEntry(
      Map<int, _CompartmentProgressDraft> target,
      int idx,
      _CompartmentProgressDraft progress,
    ) {
      final current = target[idx] ?? const _CompartmentProgressDraft();
      target[idx] = _CompartmentProgressDraft(
        mecanizada:
            (((current.mecanizada + progress.mecanizada).clamp(0, 100)) as num)
                .toInt(),
        fina: (((current.fina + progress.fina).clamp(0, 100)) as num).toInt(),
      );
    }

    bool isAfterServerBase(
      DateTime candidateDate,
      int candidateSequence,
      DateTime baseDate,
      int baseSequence,
    ) {
      final byDate = candidateDate.compareTo(baseDate);
      if (byDate != 0) {
        return byDate > 0;
      }
      if (candidateSequence <= 0 || baseSequence <= 0) {
        return true;
      }
      return candidateSequence > baseSequence;
    }

    final aggregated = <int, _CompartmentProgressDraft>{};
    ensureCompartimentoSlots(aggregated, totalCompartimentos);

    final serverBaseEntries =
        <
          ({
            DateTime businessDate,
            int sequence,
            int totalCompartimentos,
            String payloadJson,
          })
        >[];
    final entries =
        <
          ({
            DateTime businessDate,
            int sequence,
            int totalCompartimentos,
            String payloadJson,
          })
        >[];
    final normalizedOs = _normalizeOsNumber(assigned.osNumber);
    var hasServerCumulativeBase = false;
    var serverBaseDate = DateTime.fromMillisecondsSinceEpoch(0, isUtc: false);
    var serverBaseSequence = -1;

    for (final tank in assigned.availableTanks) {
      final tankKey = _buildTankIdentityKey(tank.tanqueCodigo, tank.nomeTanque);
      if (tankKey != logicalKey) {
        continue;
      }
      final effectiveTotal = tank.numeroCompartimentos ?? totalCompartimentos;
      final cumulativeRaw = (tank.compartimentosCumulativoJson ?? '').trim();
      final candidateDate =
          tank.rdoDate ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: false);
      final candidateSequence = tank.rdoSequence ?? 0;
      if (cumulativeRaw.isNotEmpty) {
        serverBaseEntries.add((
          businessDate: candidateDate,
          sequence: candidateSequence,
          totalCompartimentos: effectiveTotal,
          payloadJson: cumulativeRaw,
        ));
        continue;
      }
      entries.add((
        businessDate: candidateDate,
        sequence: candidateSequence,
        totalCompartimentos: effectiveTotal,
        payloadJson: (tank.compartimentosAvancoJson ?? '').trim(),
      ));
    }

    serverBaseEntries.sort((a, b) {
      final byDate = a.businessDate.compareTo(b.businessDate);
      if (byDate != 0) {
        return byDate;
      }
      return a.sequence.compareTo(b.sequence);
    });

    if (serverBaseEntries.isNotEmpty) {
      final latestBase = serverBaseEntries.last;
      final effectiveTotal = latestBase.totalCompartimentos > 0
          ? latestBase.totalCompartimentos
          : totalCompartimentos;
      aggregated
        ..clear()
        ..addAll(
          _parseCompartimentosPayloadJson(
            latestBase.payloadJson,
            totalCompartimentos: effectiveTotal,
          ),
        );
      ensureCompartimentoSlots(aggregated, effectiveTotal);
      hasServerCumulativeBase = true;
      serverBaseDate = latestBase.businessDate;
      serverBaseSequence = latestBase.sequence;
    }

    for (final item in queueItems) {
      final op = item.operation.toLowerCase();
      if (op != 'rdo.tank.add' && op != 'rdo_add_tank' && op != 'add_tank') {
        continue;
      }
      if (_normalizeOsNumber(item.osNumber) != normalizedOs) {
        continue;
      }
      // Itens sincronizados ainda precisam valer como histórico local até o
      // bootstrap do servidor refletir aquele mesmo RDO.
      if (item.state == SyncState.draft) {
        continue;
      }

      final payload = item.payload;
      String pickPayloadValue(List<String> keys) {
        for (final key in keys) {
          final value = '${payload[key] ?? ''}'.trim();
          if (value.isNotEmpty) {
            return value;
          }
        }
        return '';
      }

      final code = pickPayloadValue(const <String>['tanque_codigo']);
      final name = pickPayloadValue(const <String>[
        'tanque_nome',
        'nome_tanque',
      ]);
      final itemKey = _buildTankIdentityKey(code, name);
      if (itemKey != logicalKey) {
        continue;
      }

      if (hasServerCumulativeBase &&
          !isAfterServerBase(
            item.businessDate,
            item.rdoSequence,
            serverBaseDate,
            serverBaseSequence,
          )) {
        continue;
      }

      entries.add((
        businessDate: item.businessDate,
        sequence: item.rdoSequence,
        totalCompartimentos: _coerceCompartmentPercent(
          pickPayloadValue(const <String>[
            'numero_compartimentos',
            'numero_compartimento',
          ]),
        ),
        payloadJson: pickPayloadValue(const <String>[
          'compartimentos_avanco_json',
        ]),
      ));
    }

    entries.sort((a, b) {
      final byDate = a.businessDate.compareTo(b.businessDate);
      if (byDate != 0) {
        return byDate;
      }
      return a.sequence.compareTo(b.sequence);
    });

    for (final entry in entries) {
      final effectiveTotal = entry.totalCompartimentos > 0
          ? entry.totalCompartimentos
          : totalCompartimentos;
      ensureCompartimentoSlots(aggregated, effectiveTotal);
      final parsed = _parseCompartimentosPayloadJson(
        entry.payloadJson,
        totalCompartimentos: effectiveTotal,
      );
      parsed.forEach((idx, progress) {
        applyPayloadEntry(aggregated, idx, progress);
      });
    }

    return aggregated;
  }

  List<_TankCatalogOption> _buildTankCatalog(
    AssignedOsItem assigned,
    List<PendingSyncItem> queueItems,
  ) {
    final optionsByLogical = <String, _TankCatalogOption>{};

    String cleanText(dynamic value) => value == null ? '' : '$value'.trim();

    String buildLogicalKey(String code, String name, String fallback) {
      return _buildTankIdentityKey(code, name) ?? fallback;
    }

    String buildLabel(String code, String name, String fallback) {
      final cleanedCode = cleanText(code);
      final cleanedName = cleanText(name);
      if (cleanedCode.isNotEmpty && cleanedName.isNotEmpty) {
        return '$cleanedCode • $cleanedName';
      }
      if (cleanedCode.isNotEmpty) {
        return cleanedCode;
      }
      if (cleanedName.isNotEmpty) {
        return cleanedName;
      }
      return fallback;
    }

    String pickPayloadValue(Map<String, dynamic> payload, List<String> keys) {
      for (final key in keys) {
        final value = cleanText(payload[key]);
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    String preferFilled(String current, String incoming) {
      final currentClean = cleanText(current);
      if (currentClean.isNotEmpty) {
        return currentClean;
      }
      return cleanText(incoming);
    }

    void addOption(_TankCatalogOption option) {
      final logicalKey = buildLogicalKey(
        option.tanqueCodigo,
        option.tanqueNome,
        option.key,
      );
      final existing = optionsByLogical[logicalKey];
      if (existing == null) {
        optionsByLogical[logicalKey] = option;
        return;
      }
      optionsByLogical[logicalKey] = existing.copyWith(
        numeroCompartimentos: preferFilled(
          existing.numeroCompartimentos,
          option.numeroCompartimentos,
        ),
        ensacamentoPrev: preferFilled(
          existing.ensacamentoPrev,
          option.ensacamentoPrev,
        ),
        icamentoPrev: preferFilled(existing.icamentoPrev, option.icamentoPrev),
        cambagemPrev: preferFilled(existing.cambagemPrev, option.cambagemPrev),
        ensacamentoCumulativo: preferFilled(
          existing.ensacamentoCumulativo,
          option.ensacamentoCumulativo,
        ),
        icamentoCumulativo: preferFilled(
          existing.icamentoCumulativo,
          option.icamentoCumulativo,
        ),
        cambagemCumulativo: preferFilled(
          existing.cambagemCumulativo,
          option.cambagemCumulativo,
        ),
        percentualLimpezaCumulativo: preferFilled(
          existing.percentualLimpezaCumulativo,
          option.percentualLimpezaCumulativo,
        ),
        percentualLimpezaFinaCumulativo: preferFilled(
          existing.percentualLimpezaFinaCumulativo,
          option.percentualLimpezaFinaCumulativo,
        ),
        compartimentosAvancoJson: preferFilled(
          existing.compartimentosAvancoJson,
          option.compartimentosAvancoJson,
        ),
        compartimentosCumulativoJson: preferFilled(
          existing.compartimentosCumulativoJson,
          option.compartimentosCumulativoJson,
        ),
      );
    }

    for (final tank in assigned.availableTanks) {
      final code = cleanText(tank.tanqueCodigo);
      final name = cleanText(tank.nomeTanque);
      addOption(
        _TankCatalogOption(
          key: 'server:${tank.id}',
          label: buildLabel(code, name, 'Tanque #${tank.id}'),
          serverTankId: tank.id > 0 ? tank.id : null,
          tanqueCodigo: code,
          tanqueNome: name,
          tipoTanque: cleanText(tank.tipoTanque),
          numeroCompartimentos: cleanText(tank.numeroCompartimentos),
          gavetas: cleanText(tank.gavetas),
          patamares: cleanText(tank.patamares),
          volumeTanqueExec: cleanText(tank.volumeTanqueExec),
          servicoExec: cleanText(tank.servicoExec),
          metodoExec: cleanText(tank.metodoExec),
          espacoConfinado: cleanText(tank.espacoConfinado),
          operadoresSimultaneos: cleanText(tank.operadoresSimultaneos),
          h2sPpm: cleanText(tank.h2sPpm),
          lel: cleanText(tank.lel),
          coPpm: cleanText(tank.coPpm),
          o2Percent: cleanText(tank.o2Percent),
          totalNEfetivoConfinado: cleanText(tank.totalNEfetivoConfinado),
          tempoBomba: cleanText(tank.tempoBomba),
          sentidoLimpeza: cleanText(tank.sentidoLimpeza),
          ensacamentoPrev: cleanText(tank.ensacamentoPrev),
          icamentoPrev: cleanText(tank.icamentoPrev),
          cambagemPrev: cleanText(tank.cambagemPrev),
          ensacamentoDia: cleanText(tank.ensacamentoDia),
          icamentoDia: cleanText(tank.icamentoDia),
          cambagemDia: cleanText(tank.cambagemDia),
          tamboresDia: cleanText(tank.tamboresDia),
          bombeio: cleanText(tank.bombeio),
          totalLiquido: cleanText(tank.totalLiquido),
          residuosSolidos: cleanText(tank.residuosSolidos),
          residuosTotais: cleanText(tank.residuosTotais),
          ensacamentoCumulativo: cleanText(tank.ensacamentoCumulativo),
          icamentoCumulativo: cleanText(tank.icamentoCumulativo),
          cambagemCumulativo: cleanText(tank.cambagemCumulativo),
          tamboresCumulativo: cleanText(tank.tamboresCumulativo),
          totalLiquidoCumulativo: cleanText(tank.totalLiquidoCumulativo),
          residuosSolidosCumulativo: cleanText(tank.residuosSolidosCumulativo),
          percentualLimpezaDiario: cleanText(tank.percentualLimpezaDiario),
          percentualLimpezaFinaDiario: cleanText(
            tank.percentualLimpezaFinaDiario,
          ),
          percentualLimpezaCumulativo: cleanText(
            tank.percentualLimpezaCumulativo,
          ),
          percentualLimpezaFinaCumulativo: cleanText(
            tank.percentualLimpezaFinaCumulativo,
          ),
          avancoLimpeza: cleanText(tank.avancoLimpeza),
          avancoLimpezaFina: cleanText(tank.avancoLimpezaFina),
          compartimentosAvancoJson: cleanText(tank.compartimentosAvancoJson),
          compartimentosCumulativoJson: cleanText(
            tank.compartimentosCumulativoJson,
          ),
        ),
      );
    }

    final normalizedOs = _normalizeOsNumber(assigned.osNumber);
    for (final item in queueItems) {
      final op = item.operation.toLowerCase();
      if (op != 'rdo.tank.add' && op != 'rdo_add_tank' && op != 'add_tank') {
        continue;
      }
      if (_normalizeOsNumber(item.osNumber) != normalizedOs) {
        continue;
      }
      // Mantém tanques sincronizados localmente disponíveis até o bootstrap
      // voltar com o snapshot atualizado do servidor.
      if (item.state == SyncState.draft) {
        continue;
      }

      final payload = item.payload;
      final aliasRaw = payload[_kMetaEntityAliasKey];
      var alias = cleanText(aliasRaw);
      final rawTankId = cleanText(payload['tanque_id'] ?? payload['tank_id']);
      if (alias.isEmpty && rawTankId.startsWith(_kLocalRefPrefix)) {
        alias = rawTankId.substring(_kLocalRefPrefix.length);
      }
      final serverTankId = int.tryParse(rawTankId);
      if (alias.isEmpty && serverTankId == null) {
        continue;
      }

      final code = pickPayloadValue(payload, const <String>['tanque_codigo']);
      final name = pickPayloadValue(payload, const <String>[
        'tanque_nome',
        'nome_tanque',
      ]);
      if (code.isEmpty && name.isEmpty) {
        continue;
      }

      addOption(
        _TankCatalogOption(
          key: alias.isNotEmpty
              ? 'local:$alias'
              : (serverTankId == null
                    ? 'queue:${item.clientUuid}'
                    : 'server:$serverTankId'),
          label: buildLabel(code, name, alias.isNotEmpty ? code : name),
          localAlias: alias.isNotEmpty ? alias : null,
          serverTankId: alias.isEmpty ? serverTankId : null,
          tanqueCodigo: code,
          tanqueNome: name,
          tipoTanque: pickPayloadValue(payload, const <String>['tipo_tanque']),
          numeroCompartimentos: pickPayloadValue(payload, const <String>[
            'numero_compartimentos',
            'numero_compartimento',
          ]),
          gavetas: pickPayloadValue(payload, const <String>['gavetas']),
          patamares: pickPayloadValue(payload, const <String>[
            'patamares',
            'patamar',
          ]),
          volumeTanqueExec: pickPayloadValue(payload, const <String>[
            'volume_tanque_exec',
          ]),
          servicoExec: pickPayloadValue(payload, const <String>[
            'servico_exec',
          ]),
          metodoExec: pickPayloadValue(payload, const <String>['metodo_exec']),
          espacoConfinado: pickPayloadValue(payload, const <String>[
            'espaco_confinado',
          ]),
          operadoresSimultaneos: pickPayloadValue(payload, const <String>[
            'operadores_simultaneos',
          ]),
          h2sPpm: pickPayloadValue(payload, const <String>['h2s_ppm']),
          lel: pickPayloadValue(payload, const <String>['lel']),
          coPpm: pickPayloadValue(payload, const <String>['co_ppm']),
          o2Percent: pickPayloadValue(payload, const <String>['o2_percent']),
          totalNEfetivoConfinado: pickPayloadValue(payload, const <String>[
            'total_n_efetivo_confinado',
          ]),
          tempoBomba: pickPayloadValue(payload, const <String>['tempo_bomba']),
          sentidoLimpeza: pickPayloadValue(payload, const <String>[
            'sentido_limpeza',
            'sentido',
          ]),
          ensacamentoPrev: pickPayloadValue(payload, const <String>[
            'ensacamento_prev',
          ]),
          icamentoPrev: pickPayloadValue(payload, const <String>[
            'icamento_prev',
          ]),
          cambagemPrev: pickPayloadValue(payload, const <String>[
            'cambagem_prev',
          ]),
          ensacamentoDia: pickPayloadValue(payload, const <String>[
            'ensacamento_dia',
          ]),
          icamentoDia: pickPayloadValue(payload, const <String>[
            'icamento_dia',
          ]),
          cambagemDia: pickPayloadValue(payload, const <String>[
            'cambagem_dia',
          ]),
          tamboresDia: pickPayloadValue(payload, const <String>[
            'tambores_dia',
          ]),
          bombeio: pickPayloadValue(payload, const <String>['bombeio']),
          totalLiquido: pickPayloadValue(payload, const <String>[
            'total_liquido',
            'total_liquido_dia',
          ]),
          residuosSolidos: pickPayloadValue(payload, const <String>[
            'residuos_solidos',
          ]),
          residuosTotais: pickPayloadValue(payload, const <String>[
            'residuos_totais',
          ]),
          ensacamentoCumulativo: pickPayloadValue(payload, const <String>[
            'ensacamento_cumulativo',
            'ensacamento_acu',
          ]),
          icamentoCumulativo: pickPayloadValue(payload, const <String>[
            'icamento_cumulativo',
            'icamento_acu',
          ]),
          cambagemCumulativo: pickPayloadValue(payload, const <String>[
            'cambagem_cumulativo',
            'cambagem_acu',
          ]),
          tamboresCumulativo: pickPayloadValue(payload, const <String>[
            'tambores_cumulativo',
            'tambores_acu',
          ]),
          totalLiquidoCumulativo: pickPayloadValue(payload, const <String>[
            'total_liquido_cumulativo',
            'total_liquido_acu',
          ]),
          residuosSolidosCumulativo: pickPayloadValue(payload, const <String>[
            'residuos_solidos_cumulativo',
            'residuos_solidos_acu',
          ]),
          percentualLimpezaDiario: pickPayloadValue(payload, const <String>[
            'percentual_limpeza_diario',
            'avanco_limpeza',
          ]),
          percentualLimpezaFinaDiario: pickPayloadValue(payload, const <String>[
            'percentual_limpeza_fina_diario',
            'avanco_limpeza_fina',
          ]),
          percentualLimpezaCumulativo: pickPayloadValue(payload, const <String>[
            'percentual_limpeza_cumulativo',
            'limpeza_acu',
          ]),
          percentualLimpezaFinaCumulativo: pickPayloadValue(
            payload,
            const <String>[
              'percentual_limpeza_fina_cumulativo',
              'limpeza_fina_acu',
            ],
          ),
          avancoLimpeza: pickPayloadValue(payload, const <String>[
            'avanco_limpeza',
            'percentual_limpeza_diario',
          ]),
          avancoLimpezaFina: pickPayloadValue(payload, const <String>[
            'avanco_limpeza_fina',
            'percentual_limpeza_fina_diario',
          ]),
          compartimentosAvancoJson: pickPayloadValue(payload, const <String>[
            'compartimentos_avanco_json',
          ]),
          compartimentosCumulativoJson: pickPayloadValue(
            payload,
            const <String>['compartimentos_cumulativo_json'],
          ),
        ),
      );
    }

    final options = optionsByLogical.values.toList(growable: false);
    options.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return options;
  }

  List<_ActivitySyncRow> _normalizeActivities(List<_ActivityDraft> rows) {
    final normalized = <_ActivitySyncRow>[];
    final seen = <String>{};
    for (final row in rows) {
      final nome = row.nome.trim();
      final inicio = row.inicio == null ? '' : _formatTimeOfDay(row.inicio!);
      final fim = row.fim == null ? '' : _formatTimeOfDay(row.fim!);
      final comentarioPt = row.comentarioPt.trim();
      final comentarioEn = row.comentarioEn.trim();

      if (nome.isEmpty &&
          inicio.isEmpty &&
          fim.isEmpty &&
          comentarioPt.isEmpty &&
          comentarioEn.isEmpty) {
        continue;
      }
      if (nome.isEmpty) {
        continue;
      }

      final dedupKey = '$nome||$inicio||$fim||$comentarioPt||$comentarioEn';
      if (seen.contains(dedupKey)) {
        continue;
      }
      seen.add(dedupKey);
      normalized.add(
        _ActivitySyncRow(
          nome: nome,
          inicio: inicio,
          fim: fim,
          comentarioPt: comentarioPt,
          comentarioEn: comentarioEn,
        ),
      );
    }
    return normalized;
  }

  List<_TeamSyncRow> _normalizeTeamMembers(List<_TeamMemberDraft> rows) {
    final normalized = <_TeamSyncRow>[];
    final seen = <String>{};
    for (final row in rows) {
      final nome = row.nome.trim();
      final funcao = row.funcao.trim();
      final pessoaId = row.pessoaId.trim();
      final hasAny =
          nome.isNotEmpty || funcao.isNotEmpty || pessoaId.isNotEmpty;
      if (!hasAny) {
        continue;
      }
      final key = '$pessoaId||$nome||$funcao||${row.emServico ? 1 : 0}';
      if (seen.contains(key)) {
        continue;
      }
      seen.add(key);
      normalized.add(
        _TeamSyncRow(
          nome: nome,
          funcao: funcao,
          pessoaId: pessoaId,
          emServico: row.emServico,
        ),
      );
    }
    return normalized;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  _AssignedOsSummary? _resolveAssignedOs(List<PendingSyncItem> items) {
    if (items.isEmpty) {
      return null;
    }

    final byOs = <String, List<PendingSyncItem>>{};
    for (final item in items) {
      byOs.putIfAbsent(item.osNumber, () => <PendingSyncItem>[]).add(item);
    }

    if (byOs.isEmpty) {
      return null;
    }

    String activeOs = byOs.keys.first;
    DateTime latestDate = byOs[activeOs]!.first.businessDate;

    for (final entry in byOs.entries) {
      final entryLatest = _latestDate(entry.value);
      if (entryLatest.isAfter(latestDate)) {
        activeOs = entry.key;
        latestDate = entryLatest;
      }
    }

    final activeItems = byOs[activeOs]!;
    final latestItem = _latestItem(activeItems);
    final pendingCount = activeItems
        .where(
          (item) =>
              item.state == SyncState.queued ||
              item.state == SyncState.error ||
              item.state == SyncState.conflict,
        )
        .length;

    final maxRdo = activeItems.fold<int>(
      0,
      (current, item) =>
          item.rdoSequence > current ? item.rdoSequence : current,
    );
    final filledCount = activeItems
        .map((item) => item.rdoSequence)
        .toSet()
        .length;
    final nextRdo = maxRdo + 1;

    final vessel =
        _pickPayloadValue(activeItems, const <String>[
          'embarcacao_nome',
          'embarcacao',
          'navio',
          'vessel',
          'unidade',
        ]) ??
        'Embarcação vinculada';

    final operationLabel =
        _pickPayloadValue(activeItems, const <String>[
          'frente_trabalho',
          'frente',
          'servico',
          'cliente',
          'empresa',
          'operacao_nome',
        ]) ??
        'Operação em andamento';

    final tankLabel = _pickPayloadValue(activeItems, const <String>[
      'tanque_nome',
      'tanque_codigo',
      'tanque',
    ]);

    return _AssignedOsSummary(
      osNumber: activeOs,
      vessel: vessel,
      operationLabel: operationLabel,
      tankLabel: tankLabel,
      pendingCount: pendingCount,
      filledCount: filledCount,
      nextRdo: nextRdo,
      lastBusinessDate: latestItem.businessDate,
    );
  }

  String? _pickPayloadValue(List<PendingSyncItem> items, List<String> keys) {
    for (final item in items.reversed) {
      for (final key in keys) {
        final raw = item.payload[key];
        if (raw == null) {
          continue;
        }
        final normalized = '$raw'.trim();
        if (normalized.isNotEmpty && normalized != '-') {
          return normalized;
        }
      }
    }
    return null;
  }

  DateTime _latestDate(List<PendingSyncItem> items) {
    var latest = items.first.businessDate;
    for (final item in items) {
      if (item.businessDate.isAfter(latest)) {
        latest = item.businessDate;
      }
    }
    return latest;
  }

  PendingSyncItem _latestItem(List<PendingSyncItem> items) {
    var latest = items.first;
    for (final item in items) {
      if (item.businessDate.isAfter(latest.businessDate)) {
        latest = item;
      }
    }
    return latest;
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: _kInk),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _kInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRdoGroup {
  const _QueueRdoGroup({
    required this.osNumber,
    required this.rdoSequence,
    required this.businessDate,
    required this.state,
    required this.operationCount,
    required this.syncedOperationCount,
    required this.retryCount,
    this.lastError,
  });

  final String osNumber;
  final int rdoSequence;
  final DateTime businessDate;
  final SyncState state;
  final int operationCount;
  final int syncedOperationCount;
  final int retryCount;
  final String? lastError;
}

class _ServerRdoOption {
  const _ServerRdoOption({
    required this.id,
    required this.sequence,
    required this.businessDate,
    this.teamMembers = const <_TeamMemberDraft>[],
    this.reportedPob,
  });

  final int id;
  final int sequence;
  final DateTime? businessDate;
  final List<_TeamMemberDraft> teamMembers;
  final int? reportedPob;
}

class _LocalRdoExportSnapshot {
  const _LocalRdoExportSnapshot({
    required this.sequence,
    required this.businessDate,
    required this.state,
    required this.turno,
    required this.observacoesPt,
    required this.observacoesEn,
    required this.planejamentoPt,
    required this.planejamentoEn,
    required this.ptAbertura,
    required this.ptNumManha,
    required this.ptNumTarde,
    required this.ptNumNoite,
    required this.ptTurnos,
    required this.ecRows,
    required this.tanks,
    required this.activities,
    required this.teamRows,
    required this.photoCount,
  });

  final int sequence;
  final DateTime businessDate;
  final SyncState state;
  final String turno;
  final String observacoesPt;
  final String observacoesEn;
  final String planejamentoPt;
  final String planejamentoEn;
  final String ptAbertura;
  final String ptNumManha;
  final String ptNumTarde;
  final String ptNumNoite;
  final List<String> ptTurnos;
  final List<_LocalEcExportRow> ecRows;
  final List<_LocalTankExportRow> tanks;
  final List<_LocalActivityExportRow> activities;
  final List<_LocalTeamExportRow> teamRows;
  final int photoCount;
}

class _LocalTankExportRow {
  const _LocalTankExportRow({
    required this.idRef,
    required this.codigo,
    required this.nome,
    required this.tipo,
    required this.servico,
    required this.metodo,
    required this.espacoConfinado,
    required this.operadores,
    required this.h2s,
    required this.lel,
    required this.co,
    required this.o2,
    required this.sentido,
  });

  final String idRef;
  final String codigo;
  final String nome;
  final String tipo;
  final String servico;
  final String metodo;
  final String espacoConfinado;
  final String operadores;
  final String h2s;
  final String lel;
  final String co;
  final String o2;
  final String sentido;
}

class _LocalActivityExportRow {
  const _LocalActivityExportRow({
    required this.nome,
    required this.inicio,
    required this.fim,
    required this.comentarioPt,
    required this.comentarioEn,
  });

  final String nome;
  final String inicio;
  final String fim;
  final String comentarioPt;
  final String comentarioEn;
}

class _LocalTeamExportRow {
  const _LocalTeamExportRow({
    required this.nome,
    required this.funcao,
    required this.emServico,
  });

  final String nome;
  final String funcao;
  final bool emServico;
}

class _LocalEcExportRow {
  const _LocalEcExportRow({required this.entrada, required this.saida});

  final String entrada;
  final String saida;
}

class _BootstrapCacheSnapshot {
  const _BootstrapCacheSnapshot({required this.payload, this.cachedAt});

  final SupervisorBootstrapPayload payload;
  final DateTime? cachedAt;
}

class _AssignedOsSummary {
  const _AssignedOsSummary({
    required this.osNumber,
    required this.vessel,
    required this.operationLabel,
    required this.pendingCount,
    required this.filledCount,
    required this.nextRdo,
    required this.lastBusinessDate,
    this.tankLabel,
  });

  final String osNumber;
  final String vessel;
  final String operationLabel;
  final String? tankLabel;
  final int pendingCount;
  final int filledCount;
  final int nextRdo;
  final DateTime lastBusinessDate;
}

class _CreateRdoDraft {
  const _CreateRdoDraft({
    required this.businessDate,
    required this.turno,
    required this.observacoes,
    required this.observacoesEn,
    required this.planejamento,
    required this.planejamentoEn,
    required this.ptAbertura,
    required this.ptTurnos,
    required this.ptNumManha,
    required this.ptNumTarde,
    required this.ptNumNoite,
    required this.ecTimes,
    required this.teamMembers,
    required this.tank,
    required this.tanks,
    required this.activities,
    required this.photos,
  });

  final DateTime businessDate;
  final String turno;
  final String observacoes;
  final String observacoesEn;
  final String planejamento;
  final String planejamentoEn;
  final String ptAbertura;
  final List<String> ptTurnos;
  final String ptNumManha;
  final String ptNumTarde;
  final String ptNumNoite;
  final List<_EcTimeDraft> ecTimes;
  final List<_TeamMemberDraft> teamMembers;
  final _TankDraft tank;
  final List<_TankDraft> tanks;
  final List<_ActivityDraft> activities;
  final List<_DraftPhoto> photos;
}

enum _TankMode { none, existing, create }

class _TankCatalogOption {
  const _TankCatalogOption({
    required this.key,
    required this.label,
    required this.tanqueCodigo,
    required this.tanqueNome,
    this.serverTankId,
    this.localAlias,
    this.tipoTanque = '',
    this.numeroCompartimentos = '',
    this.gavetas = '',
    this.patamares = '',
    this.volumeTanqueExec = '',
    this.servicoExec = '',
    this.metodoExec = '',
    this.espacoConfinado = '',
    this.operadoresSimultaneos = '',
    this.h2sPpm = '',
    this.lel = '',
    this.coPpm = '',
    this.o2Percent = '',
    this.totalNEfetivoConfinado = '',
    this.tempoBomba = '',
    this.sentidoLimpeza = '',
    this.ensacamentoPrev = '',
    this.icamentoPrev = '',
    this.cambagemPrev = '',
    this.ensacamentoDia = '',
    this.icamentoDia = '',
    this.cambagemDia = '',
    this.tamboresDia = '',
    this.bombeio = '',
    this.totalLiquido = '',
    this.residuosSolidos = '',
    this.residuosTotais = '',
    this.ensacamentoCumulativo = '',
    this.icamentoCumulativo = '',
    this.cambagemCumulativo = '',
    this.tamboresCumulativo = '',
    this.totalLiquidoCumulativo = '',
    this.residuosSolidosCumulativo = '',
    this.percentualLimpezaDiario = '',
    this.percentualLimpezaFinaDiario = '',
    this.percentualLimpezaCumulativo = '',
    this.percentualLimpezaFinaCumulativo = '',
    this.avancoLimpeza = '',
    this.avancoLimpezaFina = '',
    this.compartimentosAvancoJson = '',
    this.compartimentosCumulativoJson = '',
  });

  final String key;
  final String label;
  final int? serverTankId;
  final String? localAlias;
  final String tanqueCodigo;
  final String tanqueNome;
  final String tipoTanque;
  final String numeroCompartimentos;
  final String gavetas;
  final String patamares;
  final String volumeTanqueExec;
  final String servicoExec;
  final String metodoExec;
  final String espacoConfinado;
  final String operadoresSimultaneos;
  final String h2sPpm;
  final String lel;
  final String coPpm;
  final String o2Percent;
  final String totalNEfetivoConfinado;
  final String tempoBomba;
  final String sentidoLimpeza;
  final String ensacamentoPrev;
  final String icamentoPrev;
  final String cambagemPrev;
  final String ensacamentoDia;
  final String icamentoDia;
  final String cambagemDia;
  final String tamboresDia;
  final String bombeio;
  final String totalLiquido;
  final String residuosSolidos;
  final String residuosTotais;
  final String ensacamentoCumulativo;
  final String icamentoCumulativo;
  final String cambagemCumulativo;
  final String tamboresCumulativo;
  final String totalLiquidoCumulativo;
  final String residuosSolidosCumulativo;
  final String percentualLimpezaDiario;
  final String percentualLimpezaFinaDiario;
  final String percentualLimpezaCumulativo;
  final String percentualLimpezaFinaCumulativo;
  final String avancoLimpeza;
  final String avancoLimpezaFina;
  final String compartimentosAvancoJson;
  final String compartimentosCumulativoJson;

  _TankCatalogOption copyWith({
    String? numeroCompartimentos,
    String? ensacamentoPrev,
    String? icamentoPrev,
    String? cambagemPrev,
    String? ensacamentoCumulativo,
    String? icamentoCumulativo,
    String? cambagemCumulativo,
    String? percentualLimpezaCumulativo,
    String? percentualLimpezaFinaCumulativo,
    String? compartimentosAvancoJson,
    String? compartimentosCumulativoJson,
  }) {
    return _TankCatalogOption(
      key: key,
      label: label,
      serverTankId: serverTankId,
      localAlias: localAlias,
      tanqueCodigo: tanqueCodigo,
      tanqueNome: tanqueNome,
      tipoTanque: tipoTanque,
      numeroCompartimentos: numeroCompartimentos ?? this.numeroCompartimentos,
      gavetas: gavetas,
      patamares: patamares,
      volumeTanqueExec: volumeTanqueExec,
      servicoExec: servicoExec,
      metodoExec: metodoExec,
      espacoConfinado: espacoConfinado,
      operadoresSimultaneos: operadoresSimultaneos,
      h2sPpm: h2sPpm,
      lel: lel,
      coPpm: coPpm,
      o2Percent: o2Percent,
      totalNEfetivoConfinado: totalNEfetivoConfinado,
      tempoBomba: tempoBomba,
      sentidoLimpeza: sentidoLimpeza,
      ensacamentoPrev: ensacamentoPrev ?? this.ensacamentoPrev,
      icamentoPrev: icamentoPrev ?? this.icamentoPrev,
      cambagemPrev: cambagemPrev ?? this.cambagemPrev,
      ensacamentoDia: ensacamentoDia,
      icamentoDia: icamentoDia,
      cambagemDia: cambagemDia,
      tamboresDia: tamboresDia,
      bombeio: bombeio,
      totalLiquido: totalLiquido,
      residuosSolidos: residuosSolidos,
      residuosTotais: residuosTotais,
      ensacamentoCumulativo:
          ensacamentoCumulativo ?? this.ensacamentoCumulativo,
      icamentoCumulativo: icamentoCumulativo ?? this.icamentoCumulativo,
      cambagemCumulativo: cambagemCumulativo ?? this.cambagemCumulativo,
      tamboresCumulativo: tamboresCumulativo,
      totalLiquidoCumulativo: totalLiquidoCumulativo,
      residuosSolidosCumulativo: residuosSolidosCumulativo,
      percentualLimpezaDiario: percentualLimpezaDiario,
      percentualLimpezaFinaDiario: percentualLimpezaFinaDiario,
      percentualLimpezaCumulativo:
          percentualLimpezaCumulativo ?? this.percentualLimpezaCumulativo,
      percentualLimpezaFinaCumulativo:
          percentualLimpezaFinaCumulativo ??
          this.percentualLimpezaFinaCumulativo,
      avancoLimpeza: avancoLimpeza,
      avancoLimpezaFina: avancoLimpezaFina,
      compartimentosAvancoJson:
          compartimentosAvancoJson ?? this.compartimentosAvancoJson,
      compartimentosCumulativoJson:
          compartimentosCumulativoJson ?? this.compartimentosCumulativoJson,
    );
  }
}

class _TankDraft {
  const _TankDraft._({
    required this.mode,
    this.existingTank,
    this.tanqueCodigo = '',
    this.tanqueNome = '',
    this.tipoTanque = '',
    this.numeroCompartimentos = '',
    this.gavetas = '',
    this.patamares = '',
    this.volumeTanqueExec = '',
    this.servicoExec = '',
    this.metodoExec = '',
    this.espacoConfinado = '',
    this.operadoresSimultaneos = '',
    this.h2sPpm = '',
    this.lel = '',
    this.coPpm = '',
    this.o2Percent = '',
    this.totalNEfetivoConfinado = '',
    this.sentidoLimpeza = '',
    this.tempoBomba = '',
    this.ensacamentoPrev = '',
    this.icamentoPrev = '',
    this.cambagemPrev = '',
    this.ensacamentoDia = '',
    this.icamentoDia = '',
    this.cambagemDia = '',
    this.tamboresDia = '',
    this.bombeio = '',
    this.totalLiquido = '',
    this.residuosSolidos = '',
    this.residuosTotais = '',
    this.ensacamentoCumulativo = '',
    this.icamentoCumulativo = '',
    this.cambagemCumulativo = '',
    this.tamboresCumulativo = '',
    this.totalLiquidoCumulativo = '',
    this.residuosSolidosCumulativo = '',
    this.percentualLimpezaDiario = '',
    this.percentualLimpezaFinaDiario = '',
    this.percentualLimpezaCumulativo = '',
    this.percentualLimpezaFinaCumulativo = '',
    this.compartimentosAvanco = const <int>[],
    this.compartimentosAvancoJson = '',
  });

  const _TankDraft.none() : this._(mode: _TankMode.none);

  const _TankDraft.existing({
    required _TankCatalogOption tank,
    required String tanqueCodigo,
    required String tanqueNome,
    required String tipoTanque,
    required String numeroCompartimentos,
    required String gavetas,
    required String patamares,
    required String volumeTanqueExec,
    required String servicoExec,
    required String metodoExec,
    required String espacoConfinado,
    required String operadoresSimultaneos,
    required String h2sPpm,
    required String lel,
    required String coPpm,
    required String o2Percent,
    required String totalNEfetivoConfinado,
    required String sentidoLimpeza,
    required String tempoBomba,
    required String ensacamentoPrev,
    required String icamentoPrev,
    required String cambagemPrev,
    required String ensacamentoDia,
    required String icamentoDia,
    required String cambagemDia,
    required String tamboresDia,
    required String bombeio,
    required String totalLiquido,
    required String residuosSolidos,
    required String residuosTotais,
    required String ensacamentoCumulativo,
    required String icamentoCumulativo,
    required String cambagemCumulativo,
    required String tamboresCumulativo,
    required String totalLiquidoCumulativo,
    required String residuosSolidosCumulativo,
    required String percentualLimpezaDiario,
    required String percentualLimpezaFinaDiario,
    required String percentualLimpezaCumulativo,
    required String percentualLimpezaFinaCumulativo,
    required List<int> compartimentosAvanco,
    required String compartimentosAvancoJson,
  }) : this._(
         mode: _TankMode.existing,
         existingTank: tank,
         tanqueCodigo: tanqueCodigo,
         tanqueNome: tanqueNome,
         tipoTanque: tipoTanque,
         numeroCompartimentos: numeroCompartimentos,
         gavetas: gavetas,
         patamares: patamares,
         volumeTanqueExec: volumeTanqueExec,
         servicoExec: servicoExec,
         metodoExec: metodoExec,
         espacoConfinado: espacoConfinado,
         operadoresSimultaneos: operadoresSimultaneos,
         h2sPpm: h2sPpm,
         lel: lel,
         coPpm: coPpm,
         o2Percent: o2Percent,
         totalNEfetivoConfinado: totalNEfetivoConfinado,
         sentidoLimpeza: sentidoLimpeza,
         tempoBomba: tempoBomba,
         ensacamentoPrev: ensacamentoPrev,
         icamentoPrev: icamentoPrev,
         cambagemPrev: cambagemPrev,
         ensacamentoDia: ensacamentoDia,
         icamentoDia: icamentoDia,
         cambagemDia: cambagemDia,
         tamboresDia: tamboresDia,
         bombeio: bombeio,
         totalLiquido: totalLiquido,
         residuosSolidos: residuosSolidos,
         residuosTotais: residuosTotais,
         ensacamentoCumulativo: ensacamentoCumulativo,
         icamentoCumulativo: icamentoCumulativo,
         cambagemCumulativo: cambagemCumulativo,
         tamboresCumulativo: tamboresCumulativo,
         totalLiquidoCumulativo: totalLiquidoCumulativo,
         residuosSolidosCumulativo: residuosSolidosCumulativo,
         percentualLimpezaDiario: percentualLimpezaDiario,
         percentualLimpezaFinaDiario: percentualLimpezaFinaDiario,
         percentualLimpezaCumulativo: percentualLimpezaCumulativo,
         percentualLimpezaFinaCumulativo: percentualLimpezaFinaCumulativo,
         compartimentosAvanco: compartimentosAvanco,
         compartimentosAvancoJson: compartimentosAvancoJson,
       );

  const _TankDraft.newTank({
    required String tanqueCodigo,
    required String tanqueNome,
    required String tipoTanque,
    required String numeroCompartimentos,
    required String gavetas,
    required String patamares,
    required String volumeTanqueExec,
    required String servicoExec,
    required String metodoExec,
    required String espacoConfinado,
    required String operadoresSimultaneos,
    required String h2sPpm,
    required String lel,
    required String coPpm,
    required String o2Percent,
    required String totalNEfetivoConfinado,
    required String sentidoLimpeza,
    required String tempoBomba,
    required String ensacamentoPrev,
    required String icamentoPrev,
    required String cambagemPrev,
    required String ensacamentoDia,
    required String icamentoDia,
    required String cambagemDia,
    required String tamboresDia,
    required String bombeio,
    required String totalLiquido,
    required String residuosSolidos,
    required String residuosTotais,
    required String ensacamentoCumulativo,
    required String icamentoCumulativo,
    required String cambagemCumulativo,
    required String tamboresCumulativo,
    required String totalLiquidoCumulativo,
    required String residuosSolidosCumulativo,
    required String percentualLimpezaDiario,
    required String percentualLimpezaFinaDiario,
    required String percentualLimpezaCumulativo,
    required String percentualLimpezaFinaCumulativo,
    required List<int> compartimentosAvanco,
    required String compartimentosAvancoJson,
  }) : this._(
         mode: _TankMode.create,
         tanqueCodigo: tanqueCodigo,
         tanqueNome: tanqueNome,
         tipoTanque: tipoTanque,
         numeroCompartimentos: numeroCompartimentos,
         gavetas: gavetas,
         patamares: patamares,
         volumeTanqueExec: volumeTanqueExec,
         servicoExec: servicoExec,
         metodoExec: metodoExec,
         espacoConfinado: espacoConfinado,
         operadoresSimultaneos: operadoresSimultaneos,
         h2sPpm: h2sPpm,
         lel: lel,
         coPpm: coPpm,
         o2Percent: o2Percent,
         totalNEfetivoConfinado: totalNEfetivoConfinado,
         sentidoLimpeza: sentidoLimpeza,
         tempoBomba: tempoBomba,
         ensacamentoPrev: ensacamentoPrev,
         icamentoPrev: icamentoPrev,
         cambagemPrev: cambagemPrev,
         ensacamentoDia: ensacamentoDia,
         icamentoDia: icamentoDia,
         cambagemDia: cambagemDia,
         tamboresDia: tamboresDia,
         bombeio: bombeio,
         totalLiquido: totalLiquido,
         residuosSolidos: residuosSolidos,
         residuosTotais: residuosTotais,
         ensacamentoCumulativo: ensacamentoCumulativo,
         icamentoCumulativo: icamentoCumulativo,
         cambagemCumulativo: cambagemCumulativo,
         tamboresCumulativo: tamboresCumulativo,
         totalLiquidoCumulativo: totalLiquidoCumulativo,
         residuosSolidosCumulativo: residuosSolidosCumulativo,
         percentualLimpezaDiario: percentualLimpezaDiario,
         percentualLimpezaFinaDiario: percentualLimpezaFinaDiario,
         percentualLimpezaCumulativo: percentualLimpezaCumulativo,
         percentualLimpezaFinaCumulativo: percentualLimpezaFinaCumulativo,
         compartimentosAvanco: compartimentosAvanco,
         compartimentosAvancoJson: compartimentosAvancoJson,
       );

  final _TankMode mode;
  final _TankCatalogOption? existingTank;
  final String tanqueCodigo;
  final String tanqueNome;
  final String tipoTanque;
  final String numeroCompartimentos;
  final String gavetas;
  final String patamares;
  final String volumeTanqueExec;
  final String servicoExec;
  final String metodoExec;
  final String espacoConfinado;
  final String operadoresSimultaneos;
  final String h2sPpm;
  final String lel;
  final String coPpm;
  final String o2Percent;
  final String totalNEfetivoConfinado;
  final String sentidoLimpeza;
  final String tempoBomba;
  final String ensacamentoPrev;
  final String icamentoPrev;
  final String cambagemPrev;
  final String ensacamentoDia;
  final String icamentoDia;
  final String cambagemDia;
  final String tamboresDia;
  final String bombeio;
  final String totalLiquido;
  final String residuosSolidos;
  final String residuosTotais;
  final String ensacamentoCumulativo;
  final String icamentoCumulativo;
  final String cambagemCumulativo;
  final String tamboresCumulativo;
  final String totalLiquidoCumulativo;
  final String residuosSolidosCumulativo;
  final String percentualLimpezaDiario;
  final String percentualLimpezaFinaDiario;
  final String percentualLimpezaCumulativo;
  final String percentualLimpezaFinaCumulativo;
  final List<int> compartimentosAvanco;
  final String compartimentosAvancoJson;

  Map<String, dynamic> toPayloadMap() {
    final payload = <String, dynamic>{};

    void putText(String key, String value) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        payload[key] = normalized;
      }
    }

    void mirror(String keyA, String keyB, String value) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        payload[keyA] = normalized;
        payload[keyB] = normalized;
      }
    }

    putText('tanque_codigo', tanqueCodigo);
    mirror('tanque_nome', 'nome_tanque', tanqueNome);
    putText('tipo_tanque', tipoTanque);
    mirror(
      'numero_compartimentos',
      'numero_compartimento',
      numeroCompartimentos,
    );
    putText('gavetas', gavetas);
    mirror('patamares', 'patamar', patamares);
    putText('volume_tanque_exec', volumeTanqueExec);
    putText('servico_exec', servicoExec);
    putText('metodo_exec', metodoExec);
    putText('espaco_confinado', espacoConfinado);
    putText('operadores_simultaneos', operadoresSimultaneos);
    putText('h2s_ppm', h2sPpm);
    putText('lel', lel);
    putText('co_ppm', coPpm);
    putText('o2_percent', o2Percent);
    putText('total_n_efetivo_confinado', totalNEfetivoConfinado);
    mirror('sentido_limpeza', 'sentido', sentidoLimpeza);
    putText('tempo_bomba', tempoBomba);

    putText('ensacamento_prev', ensacamentoPrev);
    putText('icamento_prev', icamentoPrev);
    putText('cambagem_prev', cambagemPrev);
    putText('ensacamento_dia', ensacamentoDia);
    putText('icamento_dia', icamentoDia);
    putText('cambagem_dia', cambagemDia);
    putText('tambores_dia', tamboresDia);
    putText('bombeio', bombeio);
    putText('total_liquido', totalLiquido);
    putText('residuos_solidos', residuosSolidos);
    putText('residuos_totais', residuosTotais);

    mirror('ensacamento_cumulativo', 'ensacamento_acu', ensacamentoCumulativo);
    mirror('icamento_cumulativo', 'icamento_acu', icamentoCumulativo);
    mirror('cambagem_cumulativo', 'cambagem_acu', cambagemCumulativo);
    mirror('tambores_cumulativo', 'tambores_acu', tamboresCumulativo);
    mirror(
      'total_liquido_cumulativo',
      'total_liquido_acu',
      totalLiquidoCumulativo,
    );
    mirror(
      'residuos_solidos_cumulativo',
      'residuos_solidos_acu',
      residuosSolidosCumulativo,
    );

    mirror(
      'percentual_limpeza_diario',
      'avanco_limpeza',
      percentualLimpezaDiario,
    );
    mirror(
      'percentual_limpeza_fina_diario',
      'avanco_limpeza_fina',
      percentualLimpezaFinaDiario,
    );
    mirror(
      'percentual_limpeza_cumulativo',
      'limpeza_acu',
      percentualLimpezaCumulativo,
    );
    mirror(
      'percentual_limpeza_fina_cumulativo',
      'limpeza_fina_acu',
      percentualLimpezaFinaCumulativo,
    );

    if (compartimentosAvanco.isNotEmpty) {
      payload['compartimentos_avanco[]'] = compartimentosAvanco
          .map((item) => '$item')
          .toList(growable: false);
    }
    if (compartimentosAvancoJson.trim().isNotEmpty) {
      payload['compartimentos_avanco_json'] = compartimentosAvancoJson.trim();
    }

    return payload;
  }
}

class _DraftPhoto {
  const _DraftPhoto({
    required this.path,
    required this.name,
    required this.bytes,
  });

  final String path;
  final String name;
  final Uint8List bytes;

  _DraftPhoto copyWith({String? path, String? name, Uint8List? bytes}) {
    return _DraftPhoto(
      path: path ?? this.path,
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
    );
  }
}

class _EcTimeDraft {
  const _EcTimeDraft({this.entrada, this.saida});

  final TimeOfDay? entrada;
  final TimeOfDay? saida;

  String get entradaText {
    if (entrada == null) {
      return '';
    }
    final hour = entrada!.hour.toString().padLeft(2, '0');
    final minute = entrada!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get saidaText {
    if (saida == null) {
      return '';
    }
    final hour = saida!.hour.toString().padLeft(2, '0');
    final minute = saida!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  _EcTimeDraft copyWith({TimeOfDay? entrada, TimeOfDay? saida}) {
    return _EcTimeDraft(
      entrada: entrada ?? this.entrada,
      saida: saida ?? this.saida,
    );
  }
}

class _CompartmentProgressDraft {
  const _CompartmentProgressDraft({this.mecanizada = 0, this.fina = 0});

  final int mecanizada;
  final int fina;

  _CompartmentProgressDraft copyWith({int? mecanizada, int? fina}) {
    return _CompartmentProgressDraft(
      mecanizada: mecanizada ?? this.mecanizada,
      fina: fina ?? this.fina,
    );
  }
}

class _TeamMemberDraft {
  const _TeamMemberDraft({
    this.nome = '',
    this.funcao = '',
    this.pessoaId = '',
    this.emServico = true,
  });

  final String nome;
  final String funcao;
  final String pessoaId;
  final bool emServico;

  _TeamMemberDraft copyWith({
    String? nome,
    String? funcao,
    String? pessoaId,
    bool? emServico,
  }) {
    return _TeamMemberDraft(
      nome: nome ?? this.nome,
      funcao: funcao ?? this.funcao,
      pessoaId: pessoaId ?? this.pessoaId,
      emServico: emServico ?? this.emServico,
    );
  }
}

class _TeamSyncRow {
  const _TeamSyncRow({
    required this.nome,
    required this.funcao,
    required this.pessoaId,
    required this.emServico,
  });

  final String nome;
  final String funcao;
  final String pessoaId;
  final bool emServico;
}

class _ActivityDraft {
  const _ActivityDraft({
    this.nome = '',
    this.inicio,
    this.fim,
    this.comentarioPt = '',
    this.comentarioEn = '',
  });

  final String nome;
  final TimeOfDay? inicio;
  final TimeOfDay? fim;
  final String comentarioPt;
  final String comentarioEn;

  _ActivityDraft copyWith({
    String? nome,
    TimeOfDay? inicio,
    bool clearInicio = false,
    TimeOfDay? fim,
    bool clearFim = false,
    String? comentarioPt,
    String? comentarioEn,
  }) {
    return _ActivityDraft(
      nome: nome ?? this.nome,
      inicio: clearInicio ? null : (inicio ?? this.inicio),
      fim: clearFim ? null : (fim ?? this.fim),
      comentarioPt: comentarioPt ?? this.comentarioPt,
      comentarioEn: comentarioEn ?? this.comentarioEn,
    );
  }
}

class _ActivitySyncRow {
  const _ActivitySyncRow({
    required this.nome,
    required this.inicio,
    required this.fim,
    required this.comentarioPt,
    required this.comentarioEn,
  });

  final String nome;
  final String inicio;
  final String fim;
  final String comentarioPt;
  final String comentarioEn;
}

enum _HomologationStatus { pending, ok, nok, na }

_HomologationStatus _homologationStatusFromRaw(dynamic raw) {
  final value = (raw ?? '').toString().trim().toLowerCase();
  switch (value) {
    case 'ok':
      return _HomologationStatus.ok;
    case 'nok':
      return _HomologationStatus.nok;
    case 'na':
      return _HomologationStatus.na;
    default:
      return _HomologationStatus.pending;
  }
}

class _HomologationEntry {
  const _HomologationEntry({
    this.status = _HomologationStatus.pending,
    this.note = '',
  });

  final _HomologationStatus status;
  final String note;

  _HomologationEntry copyWith({_HomologationStatus? status, String? note}) {
    return _HomologationEntry(
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

class _HomologationCase {
  const _HomologationCase({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class _HomologationSummary {
  const _HomologationSummary({
    required this.ok,
    required this.nok,
    required this.na,
    required this.pending,
  });

  final int ok;
  final int nok;
  final int na;
  final int pending;

  int get done => ok + nok + na;
}

class _HomologationBadge extends StatelessWidget {
  const _HomologationBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kCardBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _kInk,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HomologationChoiceChip extends StatelessWidget {
  const _HomologationChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? _kInk : _kMutedInk,
        fontWeight: FontWeight.w700,
        fontSize: 12.2,
      ),
      selectedColor: AppTheme.supervisorLime.withValues(alpha: 0.55),
      backgroundColor: const Color(0xFFF5F7F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected
              ? AppTheme.supervisorLime.withValues(alpha: 0.8)
              : _kCardBorder,
        ),
      ),
    );
  }
}
