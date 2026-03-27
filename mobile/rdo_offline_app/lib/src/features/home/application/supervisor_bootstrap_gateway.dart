class ActivityChoiceItem {
  const ActivityChoiceItem({required this.value, required this.label});

  final String value;
  final String label;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'value': value, 'label': label};
  }

  factory ActivityChoiceItem.fromJson(Map<String, dynamic> json) {
    return ActivityChoiceItem(
      value: _cleanString(json['value']),
      label: _cleanString(json['label']),
    );
  }
}

class AssignedTankItem {
  const AssignedTankItem({
    required this.id,
    required this.tanqueCodigo,
    required this.nomeTanque,
    this.rdoId,
    this.rdoSequence,
    this.rdoDate,
    this.tipoTanque,
    this.numeroCompartimentos,
    this.gavetas,
    this.patamares,
    this.volumeTanqueExec,
    this.servicoExec,
    this.metodoExec,
    this.espacoConfinado,
    this.operadoresSimultaneos,
    this.h2sPpm,
    this.lel,
    this.coPpm,
    this.o2Percent,
    this.totalNEfetivoConfinado,
    this.tempoBomba,
    this.sentidoLimpeza,
    this.ensacamentoPrev,
    this.icamentoPrev,
    this.cambagemPrev,
    this.ensacamentoDia,
    this.icamentoDia,
    this.cambagemDia,
    this.tamboresDia,
    this.bombeio,
    this.totalLiquido,
    this.residuosSolidos,
    this.residuosTotais,
    this.ensacamentoCumulativo,
    this.icamentoCumulativo,
    this.cambagemCumulativo,
    this.tamboresCumulativo,
    this.totalLiquidoCumulativo,
    this.residuosSolidosCumulativo,
    this.percentualLimpezaDiario,
    this.percentualLimpezaFinaDiario,
    this.percentualLimpezaCumulativo,
    this.percentualLimpezaFinaCumulativo,
    this.avancoLimpeza,
    this.avancoLimpezaFina,
    this.compartimentosAvancoJson,
    this.compartimentosCumulativoJson,
  });

  final int id;
  final String tanqueCodigo;
  final String nomeTanque;
  final int? rdoId;
  final int? rdoSequence;
  final DateTime? rdoDate;
  final String? tipoTanque;
  final int? numeroCompartimentos;
  final int? gavetas;
  final int? patamares;
  final String? volumeTanqueExec;
  final String? servicoExec;
  final String? metodoExec;
  final String? espacoConfinado;
  final int? operadoresSimultaneos;
  final String? h2sPpm;
  final String? lel;
  final String? coPpm;
  final String? o2Percent;
  final int? totalNEfetivoConfinado;
  final String? tempoBomba;
  final String? sentidoLimpeza;
  final int? ensacamentoPrev;
  final int? icamentoPrev;
  final int? cambagemPrev;
  final int? ensacamentoDia;
  final int? icamentoDia;
  final int? cambagemDia;
  final int? tamboresDia;
  final String? bombeio;
  final String? totalLiquido;
  final String? residuosSolidos;
  final String? residuosTotais;
  final int? ensacamentoCumulativo;
  final int? icamentoCumulativo;
  final int? cambagemCumulativo;
  final int? tamboresCumulativo;
  final String? totalLiquidoCumulativo;
  final String? residuosSolidosCumulativo;
  final String? percentualLimpezaDiario;
  final String? percentualLimpezaFinaDiario;
  final String? percentualLimpezaCumulativo;
  final String? percentualLimpezaFinaCumulativo;
  final String? avancoLimpeza;
  final String? avancoLimpezaFina;
  final String? compartimentosAvancoJson;
  final String? compartimentosCumulativoJson;

  String get displayLabel {
    final code = tanqueCodigo.trim();
    final name = nomeTanque.trim();
    if (code.isNotEmpty && name.isNotEmpty) {
      return '$code • $name';
    }
    if (code.isNotEmpty) {
      return code;
    }
    if (name.isNotEmpty) {
      return name;
    }
    return 'Tanque #$id';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'tanque_codigo': tanqueCodigo,
      'nome_tanque': nomeTanque,
      'rdo_id': rdoId,
      'rdo_sequence': rdoSequence,
      'rdo_date': rdoDate?.toIso8601String(),
      'tipo_tanque': tipoTanque,
      'numero_compartimentos': numeroCompartimentos,
      'gavetas': gavetas,
      'patamares': patamares,
      'volume_tanque_exec': volumeTanqueExec,
      'servico_exec': servicoExec,
      'metodo_exec': metodoExec,
      'espaco_confinado': espacoConfinado,
      'operadores_simultaneos': operadoresSimultaneos,
      'h2s_ppm': h2sPpm,
      'lel': lel,
      'co_ppm': coPpm,
      'o2_percent': o2Percent,
      'total_n_efetivo_confinado': totalNEfetivoConfinado,
      'tempo_bomba': tempoBomba,
      'sentido_limpeza': sentidoLimpeza,
      'ensacamento_prev': ensacamentoPrev,
      'icamento_prev': icamentoPrev,
      'cambagem_prev': cambagemPrev,
      'ensacamento_dia': ensacamentoDia,
      'icamento_dia': icamentoDia,
      'cambagem_dia': cambagemDia,
      'tambores_dia': tamboresDia,
      'bombeio': bombeio,
      'total_liquido': totalLiquido,
      'residuos_solidos': residuosSolidos,
      'residuos_totais': residuosTotais,
      'ensacamento_cumulativo': ensacamentoCumulativo,
      'icamento_cumulativo': icamentoCumulativo,
      'cambagem_cumulativo': cambagemCumulativo,
      'tambores_cumulativo': tamboresCumulativo,
      'total_liquido_cumulativo': totalLiquidoCumulativo,
      'residuos_solidos_cumulativo': residuosSolidosCumulativo,
      'percentual_limpeza_diario': percentualLimpezaDiario,
      'percentual_limpeza_fina_diario': percentualLimpezaFinaDiario,
      'percentual_limpeza_cumulativo': percentualLimpezaCumulativo,
      'percentual_limpeza_fina_cumulativo': percentualLimpezaFinaCumulativo,
      'avanco_limpeza': avancoLimpeza,
      'avanco_limpeza_fina': avancoLimpezaFina,
      'compartimentos_avanco_json': compartimentosAvancoJson,
      'compartimentos_cumulativo_json': compartimentosCumulativoJson,
    };
  }

  factory AssignedTankItem.fromJson(Map<String, dynamic> json) {
    return AssignedTankItem(
      id: _coerceInt(json['id']) ?? 0,
      tanqueCodigo: _cleanString(json['tanque_codigo']),
      nomeTanque: _cleanString(json['nome_tanque']),
      rdoId: _coerceInt(json['rdo_id']),
      rdoSequence: _coerceInt(json['rdo_sequence']),
      rdoDate: _parseDate(json['rdo_date']),
      tipoTanque: _stringOrNull(json['tipo_tanque']),
      numeroCompartimentos: _coerceInt(json['numero_compartimentos']),
      gavetas: _coerceInt(json['gavetas']),
      patamares: _coerceInt(json['patamares']),
      volumeTanqueExec: _stringOrNull(json['volume_tanque_exec']),
      servicoExec: _stringOrNull(json['servico_exec']),
      metodoExec: _stringOrNull(json['metodo_exec']),
      espacoConfinado: _stringOrNull(json['espaco_confinado']),
      operadoresSimultaneos: _coerceInt(json['operadores_simultaneos']),
      h2sPpm: _stringOrNull(json['h2s_ppm']),
      lel: _stringOrNull(json['lel']),
      coPpm: _stringOrNull(json['co_ppm']),
      o2Percent: _stringOrNull(json['o2_percent']),
      totalNEfetivoConfinado: _coerceInt(json['total_n_efetivo_confinado']),
      tempoBomba: _stringOrNull(json['tempo_bomba']),
      sentidoLimpeza: _stringOrNull(json['sentido_limpeza']),
      ensacamentoPrev: _coerceInt(json['ensacamento_prev']),
      icamentoPrev: _coerceInt(json['icamento_prev']),
      cambagemPrev: _coerceInt(json['cambagem_prev']),
      ensacamentoDia: _coerceInt(json['ensacamento_dia']),
      icamentoDia: _coerceInt(json['icamento_dia']),
      cambagemDia: _coerceInt(json['cambagem_dia']),
      tamboresDia: _coerceInt(json['tambores_dia']),
      bombeio: _stringOrNull(json['bombeio']),
      totalLiquido: _stringOrNull(json['total_liquido']),
      residuosSolidos: _stringOrNull(json['residuos_solidos']),
      residuosTotais: _stringOrNull(json['residuos_totais']),
      ensacamentoCumulativo: _coerceInt(json['ensacamento_cumulativo']),
      icamentoCumulativo: _coerceInt(json['icamento_cumulativo']),
      cambagemCumulativo: _coerceInt(json['cambagem_cumulativo']),
      tamboresCumulativo: _coerceInt(json['tambores_cumulativo']),
      totalLiquidoCumulativo: _stringOrNull(json['total_liquido_cumulativo']),
      residuosSolidosCumulativo: _stringOrNull(
        json['residuos_solidos_cumulativo'],
      ),
      percentualLimpezaDiario: _stringOrNull(json['percentual_limpeza_diario']),
      percentualLimpezaFinaDiario: _stringOrNull(
        json['percentual_limpeza_fina_diario'],
      ),
      percentualLimpezaCumulativo: _stringOrNull(
        json['percentual_limpeza_cumulativo'],
      ),
      percentualLimpezaFinaCumulativo: _stringOrNull(
        json['percentual_limpeza_fina_cumulativo'],
      ),
      avancoLimpeza: _stringOrNull(json['avanco_limpeza']),
      avancoLimpezaFina: _stringOrNull(json['avanco_limpeza_fina']),
      compartimentosAvancoJson: _stringOrNull(
        json['compartimentos_avanco_json'],
      ),
      compartimentosCumulativoJson: _stringOrNull(
        json['compartimentos_cumulativo_json'],
      ),
    );
  }
}

class AssignedOsItem {
  const AssignedOsItem({
    required this.id,
    required this.osNumber,
    required this.unidade,
    required this.cliente,
    required this.servico,
    required this.statusGeral,
    required this.statusOperacao,
    required this.statusLinhaMovimentacao,
    required this.rdoCount,
    this.nextRdo,
    this.canStart,
    this.startBlockReason = '',
    this.dataInicio,
    this.dataFim,
    this.lastRdoId,
    this.servicosCount = 0,
    this.maxTanquesServicos,
    this.totalTanquesOs = 0,
    this.availableTanks = const <AssignedTankItem>[],
  });

  final int id;
  final String osNumber;
  final String unidade;
  final String cliente;
  final String servico;
  final String statusGeral;
  final String statusOperacao;
  final String statusLinhaMovimentacao;
  final int rdoCount;
  final int? nextRdo;
  final bool? canStart;
  final String startBlockReason;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final int? lastRdoId;
  final int servicosCount;
  final int? maxTanquesServicos;
  final int totalTanquesOs;
  final List<AssignedTankItem> availableTanks;

  AssignedOsItem copyWith({
    int? id,
    String? osNumber,
    String? unidade,
    String? cliente,
    String? servico,
    String? statusGeral,
    String? statusOperacao,
    String? statusLinhaMovimentacao,
    int? rdoCount,
    int? nextRdo,
    bool? canStart,
    String? startBlockReason,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? lastRdoId,
    int? servicosCount,
    int? maxTanquesServicos,
    int? totalTanquesOs,
    List<AssignedTankItem>? availableTanks,
  }) {
    return AssignedOsItem(
      id: id ?? this.id,
      osNumber: osNumber ?? this.osNumber,
      unidade: unidade ?? this.unidade,
      cliente: cliente ?? this.cliente,
      servico: servico ?? this.servico,
      statusGeral: statusGeral ?? this.statusGeral,
      statusOperacao: statusOperacao ?? this.statusOperacao,
      statusLinhaMovimentacao:
          statusLinhaMovimentacao ?? this.statusLinhaMovimentacao,
      rdoCount: rdoCount ?? this.rdoCount,
      nextRdo: nextRdo ?? this.nextRdo,
      canStart: canStart ?? this.canStart,
      startBlockReason: startBlockReason ?? this.startBlockReason,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      lastRdoId: lastRdoId ?? this.lastRdoId,
      servicosCount: servicosCount ?? this.servicosCount,
      maxTanquesServicos: maxTanquesServicos ?? this.maxTanquesServicos,
      totalTanquesOs: totalTanquesOs ?? this.totalTanquesOs,
      availableTanks: availableTanks ?? this.availableTanks,
    );
  }

  bool get isEmAndamento {
    return _isProgressStatus(statusOperacao) ||
        _isProgressStatus(statusLinhaMovimentacao) ||
        _isProgressStatus(statusGeral);
  }

  bool get isFinalizada {
    return _isFinalStatus(statusOperacao) ||
        _isFinalStatus(statusLinhaMovimentacao) ||
        _isFinalStatus(statusGeral);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'numero_os': osNumber,
      'unidade': unidade,
      'cliente': cliente,
      'servico': servico,
      'status_geral': statusGeral,
      'status_operacao': statusOperacao,
      'status_linha_movimentacao': statusLinhaMovimentacao,
      'rdo_count': rdoCount,
      'next_rdo': nextRdo,
      'can_start': canStart,
      'start_block_reason': startBlockReason,
      'data_inicio': dataInicio?.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
      'last_rdo_id': lastRdoId,
      'servicos_count': servicosCount,
      'max_tanques_servicos': maxTanquesServicos,
      'total_tanques_os': totalTanquesOs,
      'tanks': availableTanks.map((item) => item.toJson()).toList(),
    };
  }

  factory AssignedOsItem.fromJson(Map<String, dynamic> json) {
    final rawTanks = json['tanks'];
    final tanks = <AssignedTankItem>[];
    if (rawTanks is List) {
      for (final row in rawTanks) {
        if (row is! Map) {
          continue;
        }
        tanks.add(AssignedTankItem.fromJson(Map<String, dynamic>.from(row)));
      }
    }
    return AssignedOsItem(
      id: _coerceInt(json['id']) ?? 0,
      osNumber: _cleanString(json['numero_os']),
      unidade: _cleanString(json['unidade']),
      cliente: _cleanString(json['cliente']),
      servico: _cleanString(json['servico']),
      statusGeral: _cleanString(json['status_geral']),
      statusOperacao: _cleanString(json['status_operacao']),
      statusLinhaMovimentacao: _cleanString(json['status_linha_movimentacao']),
      rdoCount: _coerceInt(json['rdo_count']) ?? 0,
      nextRdo: _coerceInt(json['next_rdo']),
      canStart: _coerceBool(json['can_start']),
      startBlockReason: _cleanString(json['start_block_reason']),
      dataInicio: _parseDate(json['data_inicio']),
      dataFim: _parseDate(json['data_fim']),
      lastRdoId: _coerceInt(json['last_rdo_id']),
      servicosCount: _coerceInt(json['servicos_count']) ?? 0,
      maxTanquesServicos: _coerceInt(json['max_tanques_servicos']),
      totalTanquesOs: _coerceInt(json['total_tanques_os']) ?? 0,
      availableTanks: tanks,
    );
  }
}

class SupervisorBootstrapPayload {
  const SupervisorBootstrapPayload({
    required this.items,
    required this.activityChoices,
    this.serviceChoices = const <ActivityChoiceItem>[],
    this.methodChoices = const <ActivityChoiceItem>[],
    this.personChoices = const <ActivityChoiceItem>[],
    this.functionChoices = const <ActivityChoiceItem>[],
    this.sentidoChoices = const <ActivityChoiceItem>[],
    this.ptTurnosChoices = const <ActivityChoiceItem>[],
  });

  final List<AssignedOsItem> items;
  final List<ActivityChoiceItem> activityChoices;
  final List<ActivityChoiceItem> serviceChoices;
  final List<ActivityChoiceItem> methodChoices;
  final List<ActivityChoiceItem> personChoices;
  final List<ActivityChoiceItem> functionChoices;
  final List<ActivityChoiceItem> sentidoChoices;
  final List<ActivityChoiceItem> ptTurnosChoices;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((item) => item.toJson()).toList(),
      'atividade_choices': activityChoices
          .map((item) => item.toJson())
          .toList(),
      'servico_choices': serviceChoices.map((item) => item.toJson()).toList(),
      'metodo_choices': methodChoices.map((item) => item.toJson()).toList(),
      'pessoas_choices': personChoices.map((item) => item.toJson()).toList(),
      'funcoes_choices': functionChoices.map((item) => item.toJson()).toList(),
      'sentido_limpeza_choices': sentidoChoices
          .map((item) => item.toJson())
          .toList(),
      'pt_turnos_choices': ptTurnosChoices
          .map((item) => item.toJson())
          .toList(),
    };
  }

  factory SupervisorBootstrapPayload.fromJson(Map<String, dynamic> json) {
    List<ActivityChoiceItem> parseChoices(String key) {
      final raw = json[key];
      if (raw is! List) {
        return const <ActivityChoiceItem>[];
      }
      final out = <ActivityChoiceItem>[];
      for (final row in raw) {
        if (row is! Map) {
          continue;
        }
        out.add(ActivityChoiceItem.fromJson(Map<String, dynamic>.from(row)));
      }
      return out;
    }

    final rawItems = json['items'];
    final items = <AssignedOsItem>[];
    if (rawItems is List) {
      for (final row in rawItems) {
        if (row is! Map) {
          continue;
        }
        items.add(AssignedOsItem.fromJson(Map<String, dynamic>.from(row)));
      }
    }

    return SupervisorBootstrapPayload(
      items: items,
      activityChoices: parseChoices('atividade_choices'),
      serviceChoices: parseChoices('servico_choices'),
      methodChoices: parseChoices('metodo_choices'),
      personChoices: parseChoices('pessoas_choices'),
      functionChoices: parseChoices('funcoes_choices'),
      sentidoChoices: parseChoices('sentido_limpeza_choices'),
      ptTurnosChoices: parseChoices('pt_turnos_choices'),
    );
  }
}

abstract class SupervisorBootstrapGateway {
  Future<SupervisorBootstrapPayload> fetchBootstrap();
}

String _cleanString(dynamic raw) {
  if (raw == null) {
    return '';
  }
  return '$raw'.trim();
}

String? _stringOrNull(dynamic raw) {
  final normalized = _cleanString(raw);
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

int? _coerceInt(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is double) {
    return raw.round();
  }
  final normalized = '$raw'.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return int.tryParse(normalized) ?? double.tryParse(normalized)?.round();
}

bool? _coerceBool(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is bool) {
    return raw;
  }
  final normalized = '$raw'.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized == '1' ||
      normalized == 'true' ||
      normalized == 'sim' ||
      normalized == 'yes') {
    return true;
  }
  if (normalized == '0' ||
      normalized == 'false' ||
      normalized == 'nao' ||
      normalized == 'não' ||
      normalized == 'no') {
    return false;
  }
  return null;
}

DateTime? _parseDate(dynamic raw) {
  final normalized = _cleanString(raw);
  if (normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized);
}

bool _isFinalStatus(String value) {
  final low = value.toLowerCase();
  return low.contains('finaliz') ||
      low.contains('cancel') ||
      low.contains('encerrad') ||
      low.contains('fechad') ||
      low.contains('conclu') ||
      low.contains('retorn');
}

bool _isProgressStatus(String value) {
  final low = value.toLowerCase();
  return low.contains('andamento') ||
      low.contains('em andamento') ||
      low.contains('iniciad') ||
      low.contains('execut');
}
