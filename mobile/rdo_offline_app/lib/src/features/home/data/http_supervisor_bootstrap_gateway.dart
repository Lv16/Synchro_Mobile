import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../application/supervisor_bootstrap_gateway.dart';

class SupervisorBootstrapException implements Exception {
  const SupervisorBootstrapException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HttpSupervisorBootstrapGateway implements SupervisorBootstrapGateway {
  HttpSupervisorBootstrapGateway({
    required this.bootstrapUrl,
    http.Client? client,
    this.staticHeaders = const <String, String>{},
    this.authTokenProvider,
  }) : _client = client ?? http.Client();

  final Uri bootstrapUrl;
  final http.Client _client;
  final Map<String, String> staticHeaders;
  final FutureOr<String?> Function()? authTokenProvider;

  @override
  Future<SupervisorBootstrapPayload> fetchBootstrap() async {
    late final http.Response response;
    try {
      response = await _client.get(
        bootstrapUrl,
        headers: await _requestHeaders(),
      );
    } on SocketException {
      throw const SupervisorBootstrapException(
        'Sem conexão para carregar OS atribuídas.',
      );
    } on HttpException {
      throw const SupervisorBootstrapException(
        'Falha de rede ao carregar OS atribuídas.',
      );
    }

    final payload = _decodeJsonMap(response.body);
    final success = payload['success'];
    final hasExpectedShape =
        payload.containsKey('success') || payload['items'] is List;
    final ok =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        success != false &&
        hasExpectedShape;

    if (!ok) {
      throw SupervisorBootstrapException(
        _extractErrorMessage(payload, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final rawItems = payload['items'];
    if (rawItems is! List) {
      return SupervisorBootstrapPayload(
        items: const <AssignedOsItem>[],
        activityChoices: _parseActivityChoices(payload['atividade_choices']),
        serviceChoices: _parseActivityChoices(payload['servico_choices']),
        methodChoices: _parseActivityChoices(payload['metodo_choices']),
        personChoices: _parseActivityChoices(payload['pessoas_choices']),
        functionChoices: _parseActivityChoices(payload['funcoes_choices']),
        sentidoChoices: _parseActivityChoices(
          payload['sentido_limpeza_choices'],
        ),
        ptTurnosChoices: _parseActivityChoices(payload['pt_turnos_choices']),
      );
    }

    final parsed = <AssignedOsItem>[];
    for (final row in rawItems) {
      if (row is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(row);
      final id = _coerceInt(map['id']);
      if (id == null) {
        continue;
      }

      final numeroOs = _cleanString(map['numero_os']);
      if (numeroOs.isEmpty) {
        continue;
      }

      parsed.add(
        AssignedOsItem(
          id: id,
          osNumber: numeroOs,
          unidade: _cleanString(map['unidade']),
          cliente: _cleanString(map['cliente']),
          servico: _cleanString(map['servico']),
          statusGeral: _cleanString(map['status_geral']),
          statusOperacao: _cleanString(map['status_operacao']),
          statusLinhaMovimentacao: _cleanString(
            map['status_linha_movimentacao'],
          ),
          rdoCount: _coerceInt(map['rdo_count']) ?? 0,
          nextRdo: _coerceInt(map['next_rdo']),
          canStart: _coerceBool(map['can_start']),
          startBlockReason: _cleanString(map['start_block_reason']),
          dataInicio: _parseDate(map['data_inicio']),
          dataFim: _parseDate(map['data_fim']),
          lastRdoId: _coerceInt(map['last_rdo_id']),
          servicosCount: _coerceInt(map['servicos_count']) ?? 0,
          maxTanquesServicos: _coerceInt(map['max_tanques_servicos']),
          totalTanquesOs: _coerceInt(map['total_tanques_os']) ?? 0,
          availableTanks: _parseAssignedTanks(map['tanks']),
        ),
      );
    }

    return SupervisorBootstrapPayload(
      items: parsed,
      activityChoices: _parseActivityChoices(payload['atividade_choices']),
      serviceChoices: _parseActivityChoices(payload['servico_choices']),
      methodChoices: _parseActivityChoices(payload['metodo_choices']),
      personChoices: _parseActivityChoices(payload['pessoas_choices']),
      functionChoices: _parseActivityChoices(payload['funcoes_choices']),
      sentidoChoices: _parseActivityChoices(payload['sentido_limpeza_choices']),
      ptTurnosChoices: _parseActivityChoices(payload['pt_turnos_choices']),
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
        return 'Somente supervisor pode carregar OS no app.';
      default:
        return 'Falha ao carregar OS atribuídas.';
    }
  }
}

List<AssignedTankItem> _parseAssignedTanks(dynamic raw) {
  if (raw is! List) {
    return const <AssignedTankItem>[];
  }
  final out = <AssignedTankItem>[];
  final seenById = <int>{};
  for (final row in raw) {
    if (row is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(row);
    final id = _coerceInt(map['id']);
    if (id == null || seenById.contains(id)) {
      continue;
    }
    seenById.add(id);
    out.add(
      AssignedTankItem(
        id: id,
        tanqueCodigo: _cleanString(map['tanque_codigo']),
        nomeTanque: _cleanString(map['nome_tanque'] ?? map['nome']),
        rdoId: _coerceInt(map['rdo_id']),
        rdoSequence: _coerceInt(map['rdo_sequence']),
        rdoDate: _parseDate(map['rdo_data']),
        tipoTanque: _cleanString(map['tipo_tanque']),
        numeroCompartimentos: _coerceInt(map['numero_compartimentos']),
        gavetas: _coerceInt(map['gavetas']),
        patamares: _coerceInt(map['patamares']),
        volumeTanqueExec: _cleanString(map['volume_tanque_exec']),
        servicoExec: _cleanString(map['servico_exec']),
        metodoExec: _cleanString(map['metodo_exec']),
        espacoConfinado: _cleanString(map['espaco_confinado']),
        operadoresSimultaneos: _coerceInt(map['operadores_simultaneos']),
        h2sPpm: _cleanString(map['h2s_ppm']),
        lel: _cleanString(map['lel']),
        coPpm: _cleanString(map['co_ppm']),
        o2Percent: _cleanString(map['o2_percent']),
        totalNEfetivoConfinado: _coerceInt(map['total_n_efetivo_confinado']),
        tempoBomba: _cleanString(map['tempo_bomba']),
        sentidoLimpeza: _cleanString(map['sentido_limpeza']),
        ensacamentoPrev: _coerceInt(map['ensacamento_prev']),
        icamentoPrev: _coerceInt(map['icamento_prev']),
        cambagemPrev: _coerceInt(map['cambagem_prev']),
        ensacamentoDia: _coerceInt(map['ensacamento_dia']),
        icamentoDia: _coerceInt(map['icamento_dia']),
        cambagemDia: _coerceInt(map['cambagem_dia']),
        tamboresDia: _coerceInt(map['tambores_dia']),
        bombeio: _cleanString(map['bombeio']),
        totalLiquido: _cleanString(map['total_liquido']),
        residuosSolidos: _cleanString(map['residuos_solidos']),
        residuosTotais: _cleanString(map['residuos_totais']),
        ensacamentoCumulativo: _coerceInt(map['ensacamento_cumulativo']),
        icamentoCumulativo: _coerceInt(map['icamento_cumulativo']),
        cambagemCumulativo: _coerceInt(map['cambagem_cumulativo']),
        tamboresCumulativo: _coerceInt(map['tambores_cumulativo']),
        totalLiquidoCumulativo: _cleanString(map['total_liquido_cumulativo']),
        residuosSolidosCumulativo: _cleanString(
          map['residuos_solidos_cumulativo'],
        ),
        percentualLimpezaDiario: _cleanString(map['percentual_limpeza_diario']),
        percentualLimpezaFinaDiario: _cleanString(
          map['percentual_limpeza_fina_diario'],
        ),
        percentualLimpezaCumulativo: _cleanString(
          map['percentual_limpeza_cumulativo'],
        ),
        percentualLimpezaFinaCumulativo: _cleanString(
          map['percentual_limpeza_fina_cumulativo'],
        ),
        avancoLimpeza: _cleanString(map['avanco_limpeza']),
        avancoLimpezaFina: _cleanString(map['avanco_limpeza_fina']),
        compartimentosAvancoJson: _cleanString(
          map['compartimentos_avanco_json'],
        ),
        compartimentosCumulativoJson: _cleanString(
          map['compartimentos_cumulativo_json'],
        ),
      ),
    );
  }
  out.sort(
    (a, b) =>
        a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase()),
  );
  return out;
}

List<ActivityChoiceItem> _parseActivityChoices(dynamic raw) {
  if (raw is! List) {
    return const <ActivityChoiceItem>[];
  }
  final out = <ActivityChoiceItem>[];
  final seen = <String>{};
  for (final row in raw) {
    String value = '';
    String label = '';
    if (row is Map) {
      final map = Map<String, dynamic>.from(row);
      value = _cleanString(map['value']);
      label = _cleanString(map['label']);
    } else if (row is List && row.length >= 2) {
      value = _cleanString(row[0]);
      label = _cleanString(row[1]);
    } else {
      value = _cleanString(row);
      label = value;
    }
    if (value.isEmpty) {
      continue;
    }
    if (label.isEmpty) {
      label = value;
    }
    final key = value.toLowerCase();
    if (seen.contains(key)) {
      continue;
    }
    seen.add(key);
    out.add(ActivityChoiceItem(value: value, label: label));
  }
  return out;
}

String _cleanString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

int? _coerceInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    final direct = int.tryParse(value);
    if (direct != null) {
      return direct;
    }
    final asDouble = double.tryParse(value.replaceAll(',', '.'));
    if (asDouble != null) {
      return asDouble.toInt();
    }
  }
  if (value is double) {
    return value.toInt();
  }
  return null;
}

bool? _coerceBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value != 0;
  }
  if (value is String) {
    final low = value.trim().toLowerCase();
    if (low == 'true' || low == '1' || low == 'yes' || low == 'sim') {
      return true;
    }
    if (low == 'false' || low == '0' || low == 'no' || low == 'nao') {
      return false;
    }
  }
  return null;
}
