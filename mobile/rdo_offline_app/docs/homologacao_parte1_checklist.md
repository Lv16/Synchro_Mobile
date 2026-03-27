# Homologacao Funcional - Parte 1 (Sem Fotos / Sem iOS)

Data base: 2026-02-22  
Ultima execucao automatica: 2026-02-23  
Escopo: Android + Web Preview do app, sem fluxo de fotos.

## Objetivo

Validar que o app do Supervisor consegue:

1. preencher RDO offline;
2. sincronizar automaticamente quando houver rede;
3. refletir os dados no backend sem quebrar o web.

## Regras desta fase

1. Nao alterar comportamento do web supervisor.
2. Executar primeiro em ambiente de teste (`settings_dev`).
3. Fotos ficam para release futura.
4. iOS fica para release futura.

## Evidencias automaticas ja obtidas

1. Flutter: `analyze` e `test` OK.
2. Backend mobile API + RDO: `GO.tests.test_mobile_sync_api`, `GO.tests.test_rdo_tank_association`, `GO.tests.test_tank_alias_normalization` OK (18/18) em `settings_dev`.
3. Migracoes de teste limpas: `No migrations to apply` em `settings_dev`.
4. App com modo homologacao (`RDO_HOMOLOG_MODE=true`) para registrar `OK/NOK/NA` no celular.

## Ambiente de homologacao recomendado

1. Backend Django com `settings_dev`.
2. App em preview web:
   - `/static/mobile-preview/`
   - `/static/mobile-preview-v2/`
3. Usuario de teste no grupo `Supervisor`.
4. OS de teste atribuida ao supervisor.

## Checklist de aceite funcional

Marcar cada item com `OK`, `NOK` ou `NA`.

## Execucao automatica mais recente (2026-02-23)

Comandos executados:

1. `./venv_new/bin/python manage.py migrate --settings=setup.settings_dev --noinput`
2. `./venv_new/bin/python manage.py test GO.tests.test_mobile_sync_api GO.tests.test_rdo_tank_association GO.tests.test_tank_alias_normalization --settings=setup.settings_dev`
3. `/var/www/mobile-sdk/flutter/bin/flutter pub get`
4. `/var/www/mobile-sdk/flutter/bin/flutter analyze`
5. `/var/www/mobile-sdk/flutter/bin/flutter test`

Resultado:

1. `migrate` OK (`No migrations to apply`).
2. Testes backend/RDO OK (`18/18`).
3. Flutter `analyze` OK (`No issues found`).
4. Flutter `test` OK (`All tests passed`).

## Status parcial do checklist (2026-02-23)

| Grupo | Status | Cobertura atual |
| --- | --- | --- |
| A. Login e sessao | Parcial | `A2` coberto automatico (bloqueio nao-supervisor). `A1/A3` pendente validacao manual de fluxo no aparelho. |
| B. Home e atribuicao de OS | Parcial | `B1` e parte de `B2/B3` cobertas por teste de bootstrap; falta rodada manual no app para confirmar UX completa. |
| C. Criacao de RDO offline | Pendente manual | Requer execucao guiada no app para validar formulario completo, previsoes e "salvar e adicionar outro tanque". |
| D. Sincronizacao | Parcial | Idempotencia, batch e escopo de sync cobertos no backend; autosync e mensagens do app ainda precisam da rodada manual. |
| E. Integridade backend | Parcial | Idempotencia e persistencia de tanque cobertas por teste; validar equipe/atividades via caso manual fim-a-fim. |
| F. KPI e tabela web | Pendente manual | Dependente de sincronizacao real no ambiente e conferencia visual na tabela/KPIs do web. |

### A. Login e sessao

1. Login com supervisor valido entra no app.  
Aceite: abre Home sem erro de autenticacao.
2. Login com usuario nao supervisor bloqueia acesso.  
Aceite: API responde negando acesso mobile.
3. Logout encerra sessao local corretamente.  
Aceite: volta para tela de login.

### B. Home e atribuicao de OS

1. Lista de OS atribuida carrega ao abrir app.  
Aceite: mostra OS do supervisor autenticado.
2. OS finalizada nao permite iniciar RDO.  
Aceite: exibe bloqueio e nao abre fluxo de criacao.
3. Duplicidade de OS por mesmo numero nao confunde usuario.  
Aceite: OS aparece consolidada.

### C. Criacao de RDO offline

1. Botao "Iniciar RDO offline" abre formulario completo.
2. Salvar RDO offline cria itens na fila local.
3. Campos criticos sao persistidos:
   - turno/data/observacoes;
   - atividades;
   - equipe e funcao;
   - tanque novo e tanque existente;
   - "salvar e adicionar outro tanque".
4. Regras de previsao (preenchimento unico) respeitadas.

Aceite: RDO aparece em "RDOs no aparelho" apos salvar.

### D. Sincronizacao (principal da fase)

1. Auto-sync ao abrir app com internet.
2. Auto-sync ao voltar do background.
3. Auto-sync periodico (timer).
4. Auto-sync apos salvar RDO offline.
5. Botao "Sincronizar agora" forca envio manual.
6. Erro de sync aparece por item (mensagem clara).
7. Reenvio apos erro funciona sem duplicar dados.

Aceite: itens saem de `queued/error` para `synced` quando API aceita.

### E. Integridade de dados no backend

1. RDO sincronizado existe no backend com dados esperados.
2. Tanques vinculados ao RDO corretos.
3. Equipe e atividades persistidas.
4. Idempotencia: reenviar mesmo pacote nao duplica.

Aceite: consulta no web/admin confirma unicidade e valores.

### F. Validacao de KPI e tabela web

1. RDO enviado pelo app aparece na tabela do sistema no local correto (OS/RDO).
2. KPI relacionado ao RDO considera o registro sincronizado.
3. KPI acumulado e diario batem com os dados enviados.

Aceite: comparacao manual app x web sem divergencia relevante.

## Cenarios obrigatorios de teste manual

1. Online continuo: cria RDO e confirma envio automatico.
2. Offline curto: cria 2+ RDO, reconecta e valida sync.
3. Offline longo simulado: cria varios RDO/tanques, sincroniza em lote depois.
4. Falha controlada: derrubar rede no meio do envio e validar retry posterior.
5. Sessao invalida: expirar token e validar comportamento de erro + relogin.

## Criterios de aceite da Parte 1

Parte 1 aprovada quando:

1. 100% dos itens A-D estao `OK`;
2. itens E-F sem erro bloqueante;
3. nenhum impacto funcional detectado no web;
4. sem incidente de duplicidade de RDO/tanque no backend.

## Itens explicitamente fora da Parte 1

1. Captura/upload de fotos.
2. Distribuicao iOS.
3. Publicacao em loja.
