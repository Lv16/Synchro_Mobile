# Runbook Manual - Homologacao Parte 1

Escopo: validar manualmente os itens que nao sao 100% cobertos por testes automatizados.

## 1) Preparacao rapida (settings_dev)

1. Rodar validacao automatica:
   - `cd /var/www/mobile/rdo_offline_app`
   - `bash scripts/homologacao_parte1_auto.sh`
2. Subir backend de teste:
   - `cd /var/www/html/GESTAO_OPERACIONAL`
   - `./venv_new/bin/python manage.py runserver 0.0.0.0:8001 --settings=setup.settings_dev`
3. Subir app em preview web (ou rodar no Android):
   - usar as URLs apontando para `http://SEU_HOST:8001/api/mobile/v1/...`
   - para usar checklist dentro do app, compile com `--dart-define=RDO_HOMOLOG_MODE=true`
4. Confirmar usuario no grupo `Supervisor` e com OS atribuida no `settings_dev`.

## 2) Casos manuais obrigatorios

Marcar cada caso como `OK` ou `NOK`.

### B1. Home carrega OS atribuida

1. Fazer login no app com supervisor.
2. Verificar se a OS atribuida aparece no card principal.
3. Conferir se o numero da OS e cliente/unidade batem com o web.

Aceite: OS aparece corretamente para o supervisor logado.

### B2. OS finalizada nao pode iniciar RDO

1. No backend de teste, marcar uma OS atribuida com `status_geral='Finalizada'` ou `status_operacao='Finalizada'`.
2. Reabrir Home do app.
3. Conferir se a OS nao aparece para iniciar, ou aparece bloqueada sem permitir "Iniciar RDO offline".

Aceite: fluxo de abertura de RDO nao inicia para OS finalizada.

### B3. Duplicidade de OS consolidada

1. Garantir 2 registros relacionados ao mesmo numero de OS (mesmo supervisor).
2. Abrir Home.
3. Verificar se o app exibe uma unica entrada consolidada.

Aceite: usuario nao ve duplicidade confusa para a mesma OS.

### C1. Formulario completo de RDO offline

1. Clicar em "Iniciar RDO offline".
2. Preencher campos principais do modal supervisor:
   - turno/data/observacoes;
   - atividades (inicio/fim/comentarios PT/EN);
   - equipe (pessoas) e funcao;
   - servico/metodo;
   - tanque novo e selecao de tanque existente.

Aceite: todos os campos do fluxo supervisor estao disponiveis e salvam sem erro.

### C2. Salvar e adicionar outro tanque

1. No mesmo RDO, usar "Salvar e adicionar outro tanque".
2. Preencher um segundo tanque.
3. Salvar.

Aceite: o RDO fica com os dois tanques na fila local e depois sincroniza sem duplicidade indevida.

### C3. Regra de previsao (preencher apenas uma vez)

1. Preencher previsao no primeiro RDO daquele tanque.
2. Abrir RDO seguinte para o mesmo tanque.
3. Verificar que os campos de previsao ficam bloqueados para edicao.

Aceite: previsao nao pode ser alterada novamente nos proximos RDOs.

### D1. Autosync (abertura, resume, timer)

1. Com itens em fila (`queued`), abrir app com internet.
2. Colocar app em background e voltar para foreground.
3. Aguardar o timer de autosync.

Aceite: fila e processada automaticamente sem tocar no botao manual.

### D2. Botao "Sincronizar agora"

1. Criar novo RDO offline.
2. Tocar em "Sincronizar agora".
3. Verificar mudanca de estado do item (`queued` -> `synced`) ou erro detalhado.

Aceite: botao dispara envio imediato e atualiza o status da fila.

### D3. Retry apos erro

1. Derrubar rede durante envio para forcar erro.
2. Reativar rede.
3. Acionar sync novamente.

Aceite: reenvio funciona e nao duplica RDO/tanque no backend.

### F1. RDO aparece na tabela web

1. Sincronizar RDO criado no app.
2. Abrir tela web de RDO (`rdo.html`) da mesma OS/data.
3. Verificar presenca no local correto.

Aceite: registro enviado pelo app aparece normalmente na tabela web.

### F2. KPI diario e acumulado

1. Comparar valores preenchidos no app vs dashboard/KPI web.
2. Validar diarios e acumulados apos sync.

Aceite: KPI do web considera os dados do app sem divergencia relevante.

## 3) Validacoes tecnicas de apoio (backend)

Use no `settings_dev` para conferencia rapida:

1. `./venv_new/bin/python manage.py shell --settings=setup.settings_dev`
2. Consultas uteis:
   - `from GO.models import RDO, RdoTanque, MobileSyncEvent`
   - `RDO.objects.filter(ordem_servico__numero_os=NUMERO_OS).order_by('-id')[:5]`
   - `RdoTanque.objects.filter(rdo__ordem_servico__numero_os=NUMERO_OS).count()`
   - `MobileSyncEvent.objects.filter(operation__startswith='rdo.').order_by('-created_at')[:10]`

## 4) Resultado da rodada

Preencher ao final:

1. Itens `OK`:
2. Itens `NOK`:
3. Bugs bloqueantes encontrados:
4. Go/No-Go da Parte 1:
