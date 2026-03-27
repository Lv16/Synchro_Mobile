# RDO Offline App (Flutter)

Base inicial do aplicativo mobile para preenchimento offline de RDO.

## Objetivo deste projeto

- Isolar desenvolvimento mobile sem impacto no Web existente.
- Preparar fluxo offline-first (fila local + sincronização posterior).
- Dar base para Android/iOS com evolução incremental.

## Estado atual

- Projeto Flutter criado em pasta isolada: `/var/www/mobile/rdo_offline_app`.
- Tela inicial com:
  - indicadores de fila (`Pendentes`, `Sincronizados`, `Erros`);
  - ações `Gerar fila demo` e `Sincronizar agora`;
  - lista de pacotes de sincronização.
- Camadas implementadas:
  - `domain` (`PendingSyncItem`, estados);
  - `application` (`OfflineSyncController`, `RdoSyncGateway`);
  - `data`:
    - `SqliteOfflineRdoRepository` (persistência local);
    - `HttpRdoSyncGateway` (envio para API mobile);
    - `DemoRdoSyncGateway` (modo simulado para desenvolvimento).

## Backend mobile já conectado

- Endpoints adicionados no Django:
  - `POST /api/mobile/v1/auth/token/`
  - `POST /api/mobile/v1/auth/revoke/`
  - `GET /api/mobile/v1/bootstrap/`
  - `POST /api/mobile/v1/rdo/sync/`
  - `POST /api/mobile/v1/rdo/sync/batch/`
  - `GET /api/mobile/v1/rdo/sync/status/?client_uuid=<uuid>`
  - `POST /api/mobile/v1/rdo/photo/upload/`
- Idempotência server-side:
  - modelo `MobileSyncEvent`;
  - deduplicação por `client_uuid` (reenvio retorna resposta anterior, sem duplicar operação).

## Como executar neste servidor

O SDK Flutter local está em `/var/www/mobile-sdk/flutter`.

```bash
cd /var/www/mobile/rdo_offline_app
/var/www/mobile-sdk/flutter/bin/flutter pub get
/var/www/mobile-sdk/flutter/bin/flutter analyze
/var/www/mobile-sdk/flutter/bin/flutter test
```

## Configurar sync real

O app exige `RDO_SYNC_URL` e inicia sempre pela tela de login do Supervisor.
Sem `RDO_SYNC_URL`, ele exibe erro de configuração na abertura.

## Rollout seguro (recomendado)

### Fase 1: validar em banco de teste (`settings_dev`)

1. Subir Django em `settings_dev`:

```bash
source /var/www/html/venv/bin/activate
cd /var/www/html/GESTAO_OPERACIONAL
python manage.py migrate --settings=setup.settings_dev --noinput
python manage.py runserver 0.0.0.0:8001 --settings=setup.settings_dev
```

2. (Opcional) definir senha de supervisor no `db_dev.sqlite3` para teste:

```bash
source /var/www/html/venv/bin/activate
cd /var/www/html/GESTAO_OPERACIONAL
python manage.py shell --settings=setup.settings_dev -c "from django.contrib.auth.models import User, Group; u=User.objects.get(username='supervisor.app'); g=Group.objects.get(name='Supervisor'); u.groups.add(g); u.set_password('DEFINA_UMA_SENHA_TEMPORARIA'); u.save()"
```

3. Rodar app Flutter apontando para o backend de teste (sem token fixo):

```bash
cd /var/www/mobile/rdo_offline_app
/var/www/mobile-sdk/flutter/bin/flutter run \
  --dart-define=RDO_SYNC_URL=http://SEU_HOST:8001/api/mobile/v1/rdo/sync/ \
  --dart-define=RDO_SYNC_BATCH_URL=http://SEU_HOST:8001/api/mobile/v1/rdo/sync/batch/ \
  --dart-define=RDO_PHOTO_UPLOAD_URL=http://SEU_HOST:8001/api/mobile/v1/rdo/photo/upload/ \
  --dart-define=RDO_BOOTSTRAP_URL=http://SEU_HOST:8001/api/mobile/v1/bootstrap/ \
  --dart-define=RDO_AUTH_TOKEN_URL=http://SEU_HOST:8001/api/mobile/v1/auth/token/ \
  --dart-define=RDO_AUTH_REVOKE_URL=http://SEU_HOST:8001/api/mobile/v1/auth/revoke/
```

### Fase 2: apontar para ambiente verdadeiro (`settings.py`)

Depois de validar a fase 1, troque apenas as URLs (`https://...`) para o domínio oficial e rode novo build.

### Modo recomendado (login de supervisor no app)

Compile com:

```bash
/var/www/mobile-sdk/flutter/bin/flutter run \
  --dart-define=RDO_SYNC_URL=https://seu-dominio/api/mobile/v1/rdo/sync/ \
  --dart-define=RDO_SYNC_BATCH_URL=https://seu-dominio/api/mobile/v1/rdo/sync/batch/ \
  --dart-define=RDO_PHOTO_UPLOAD_URL=https://seu-dominio/api/mobile/v1/rdo/photo/upload/ \
  --dart-define=RDO_BOOTSTRAP_URL=https://seu-dominio/api/mobile/v1/bootstrap/ \
  --dart-define=RDO_AUTH_TOKEN_URL=https://seu-dominio/api/mobile/v1/auth/token/ \
  --dart-define=RDO_AUTH_REVOKE_URL=https://seu-dominio/api/mobile/v1/auth/revoke/ \
  --dart-define=RDO_DEVICE_NAME=Galaxy_Supervisor
```

### Modo homologacao (checklist no app)

Para habilitar o checklist `OK/NOK/NA` dentro da Home durante os testes:

```bash
/var/www/mobile-sdk/flutter/bin/flutter run \
  --dart-define=RDO_SYNC_URL=https://seu-dominio/api/mobile/v1/rdo/sync/ \
  --dart-define=RDO_SYNC_BATCH_URL=https://seu-dominio/api/mobile/v1/rdo/sync/batch/ \
  --dart-define=RDO_PHOTO_UPLOAD_URL=https://seu-dominio/api/mobile/v1/rdo/photo/upload/ \
  --dart-define=RDO_BOOTSTRAP_URL=https://seu-dominio/api/mobile/v1/bootstrap/ \
  --dart-define=RDO_AUTH_TOKEN_URL=https://seu-dominio/api/mobile/v1/auth/token/ \
  --dart-define=RDO_AUTH_REVOKE_URL=https://seu-dominio/api/mobile/v1/auth/revoke/ \
  --dart-define=RDO_HOMOLOG_MODE=true
```

### Ambiente de homologacao Android separado

Para instalar um app de teste lado a lado com o oficial no Android, use o flavor `homolog`.
Ele gera:

- `applicationId` separado (`.hml`)
- nome visivel `Ambipar Synchro HML`
- banner `HML` dentro do app
- armazenamento separado do app de producao

Preparacao:

```bash
cd /var/www/mobile/rdo_offline_app
cp .release.homolog.env.example .release.homolog.env
```

Ajuste a `.release.homolog.env` para apontar para o backend de homologacao.

Rodar no aparelho sem gerar release:

```bash
cd /var/www/mobile/rdo_offline_app
FLAVOR=homolog ENV_FILE=.release.homolog.env ./scripts/run_android_app.sh
```

Gerar APK/AAB de homologacao:

```bash
cd /var/www/mobile/rdo_offline_app
FLAVOR=homolog ENV_FILE=.release.homolog.env ./scripts/build_android_release.sh both
```

Publicar artefatos de homologacao:

```bash
cd /var/www/mobile/rdo_offline_app
RELEASE_CHANNEL=homolog ./scripts/publish_release_artifacts.sh
```

Arquivos publicados de homologacao:

- `ambipar-synchro-hml-latest.apk`
- `ambipar-synchro-hml-latest.aab`

URL esperada:

- `https://synchro.ambipar.vps-kinghost.net/static/mobile/releases/ambipar-synchro-hml-latest.apk`

### Modo legado (token fixo no build)

Também é possível incluir token estático no build como header adicional de requisição
(a tela de login continua obrigatória):

```bash
/var/www/mobile-sdk/flutter/bin/flutter run \
  --dart-define=RDO_SYNC_URL=https://seu-dominio/api/mobile/v1/rdo/sync/ \
  --dart-define=RDO_SYNC_BATCH_URL=https://seu-dominio/api/mobile/v1/rdo/sync/batch/ \
  --dart-define=RDO_PHOTO_UPLOAD_URL=https://seu-dominio/api/mobile/v1/rdo/photo/upload/ \
  --dart-define=RDO_API_TOKEN=SEU_TOKEN_BEARER
```

`RDO_SYNC_BATCH_URL` é opcional. Se não for enviado, o app deriva automaticamente
o endpoint batch a partir de `RDO_SYNC_URL`.
`RDO_BOOTSTRAP_URL` é opcional. Se não for enviado, o app deriva automaticamente
`/api/mobile/v1/bootstrap/` a partir de `RDO_SYNC_URL`.
Se `RDO_AUTH_TOKEN_URL` não for enviado, o app tenta derivar a URL a partir de `RDO_SYNC_URL`.

## Obter token de autenticação

`POST /api/mobile/v1/auth/token/` (JSON):

```json
{
  "username": "usuario",
  "password": "senha",
  "device_name": "Galaxy S23",
  "platform": "android"
}
```

## Contrato batch (sync v1)

`POST /api/mobile/v1/rdo/sync/batch/` (JSON):

```json
{
  "stop_on_error": true,
  "items": [
    {
      "client_uuid": "uuid-1",
      "operation": "rdo.update",
      "entity_alias": "rdo_main",
      "payload": { "rdo_id": "123", "observacoes": "..." }
    },
    {
      "client_uuid": "uuid-2",
      "operation": "rdo.tank.add",
      "depends_on": ["uuid-1", "rdo_main"],
      "entity_alias": "tank_main",
      "payload": { "rdo_id": "@ref:rdo_main", "tanque_codigo": "2P" }
    }
  ]
}
```

- `depends_on`: dependência por `client_uuid` ou `entity_alias`.
- `@ref:<alias>`: resolve referência para o ID retornado no item que definiu `entity_alias`.
- Resposta inclui `id_map` com mapeamento `{ alias: id_servidor }`.

No app, os metadados internos de fila para batch são:
- `__entity_alias`: alias local da entidade criada/atualizada.
- `__depends_on`: lista de dependências (uuid ou alias).
- `@local:<alias>` em payload: o gateway converte para `@ref:<alias>` no envio.

## Próximos passos técnicos

1. Integrar refresh de sessão e política de expiração com renovação automática.
2. Implementar upload de fotos em duas fases (metadados + binário).
3. Definir política de retry/backoff e limite de tentativas por pacote.
4. Adicionar telemetria de sync (latência, taxa de sucesso, conflitos).

## Lancamento nativo (Fase 3)

No lancamento oficial, o canal principal e o app Android/iOS nativo.
Preview web fica opcional apenas para homologacao interna e nao faz parte do fluxo final.

### Preparar assinatura Android

1. Copie o modelo:

```bash
cd /var/www/mobile/rdo_offline_app/android
cp key.properties.example key.properties
```

2. Edite `key.properties` com o keystore oficial:
- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

### Preparar variaveis de build

```bash
cd /var/www/mobile/rdo_offline_app
cp .release.env.example .release.env
```

Preencha `.release.env` com URLs reais de producao e versao (`BUILD_NAME`, `BUILD_NUMBER`).

### Gerar APK/AAB de release

```bash
cd /var/www/mobile/rdo_offline_app
bash scripts/build_android_release.sh both
```

Opcoes de alvo:
- `bash scripts/build_android_release.sh apk`
- `bash scripts/build_android_release.sh aab`
- `bash scripts/build_android_release.sh both`

Os artefatos ficam em `dist/android/<timestamp>_v<versao>/`.

### Publicar artefatos no web (download)

Depois do build, publique APK/AAB em `static/mobile/releases`:

```bash
cd /var/www/mobile/rdo_offline_app
bash scripts/publish_release_artifacts.sh
```

Com isso, os links ficam em:
- `https://synchro.ambipar.vps-kinghost.net/static/mobile/releases/ambipar-synchro-latest.apk`
- `https://synchro.ambipar.vps-kinghost.net/static/mobile/releases/ambipar-synchro-latest.aab`

### Iniciar desenvolvimento iOS (isolado do Android)

Alteracoes de iOS ficam apenas em `ios/` e `scripts/build_ios_release.sh`,
sem alterar o pipeline Android.

Pre-requisitos (maquina Mac):
- Xcode instalado e aberto ao menos 1 vez
- CocoaPods instalado (`sudo gem install cocoapods`)
- Flutter SDK no PATH

Build iOS (assinatura depois no Xcode/TestFlight):

```bash
cd /var/www/mobile/rdo_offline_app
bash scripts/build_ios_release.sh
```

Por padrao, o script roda com `NO_CODESIGN=true` e gera artefatos em:
- `dist/ios/<timestamp>_v<versao>/`

Para build assinado no Mac (com certificados/profiles configurados):

```bash
cd /var/www/mobile/rdo_offline_app
NO_CODESIGN=false bash scripts/build_ios_release.sh
```

### Validacao iOS sem Mac local (CI em nuvem)

Foi adicionado workflow em:
- `.github/workflows/mobile_ios_smoke.yml`

Esse workflow roda em `macos-14` e executa:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `pod install`
5. `flutter build ios --release --no-codesign`

Com isso, cada alteracao no app mobile valida compilacao iOS automaticamente,
sem interferir no pipeline Android que ja esta em operacao.

### Release iOS para TestFlight (sem Mac local)

Workflow de release assinado:
- `.github/workflows/mobile_ios_testflight.yml`

Execucao:
1. Acesse `Actions > Mobile iOS Release (TestFlight)`.
2. Clique em `Run workflow`.
3. Informe `build_name`, `build_number` e mantenha `export_method=app-store`.
4. Opcional: desmarque `upload_to_testflight` para gerar IPA sem enviar.

Variaveis de repositorio obrigatorias (`Settings > Secrets and variables > Actions > Variables`):
- `RDO_SYNC_URL`
- `RDO_SYNC_BATCH_URL`
- `RDO_PHOTO_UPLOAD_URL`
- `RDO_BOOTSTRAP_URL`
- `RDO_AUTH_TOKEN_URL`
- `RDO_AUTH_REVOKE_URL`

Opcional:
- `RDO_TRANSLATE_PREVIEW_URL`
- `RDO_DEVICE_NAME`

Secrets obrigatorios (`Settings > Secrets and variables > Actions > Secrets`):
- `IOS_BUILD_CERTIFICATE_BASE64` (certificado `.p12` em base64)
- `IOS_BUILD_CERTIFICATE_PASSWORD`
- `IOS_PROVISION_PROFILE_BASE64` (`.mobileprovision` em base64)
- `IOS_KEYCHAIN_PASSWORD`
- `APPSTORE_CONNECT_API_KEY_ID`
- `APPSTORE_CONNECT_ISSUER_ID`
- `APPSTORE_CONNECT_API_PRIVATE_KEY_BASE64` (`.p8` em base64)

Exemplo para gerar base64 dos arquivos (Linux/Mac):

```bash
base64 -w 0 ios_dist.p12 > ios_dist.p12.b64
base64 -w 0 profile.mobileprovision > profile.mobileprovision.b64
base64 -w 0 AuthKey_XXXXXX.p8 > AuthKey_XXXXXX.p8.b64
```

No macOS, se `-w` nao existir:

```bash
base64 ios_dist.p12 | tr -d '\n' > ios_dist.p12.b64
base64 profile.mobileprovision | tr -d '\n' > profile.mobileprovision.b64
base64 AuthKey_XXXXXX.p8 | tr -d '\n' > AuthKey_XXXXXX.p8.b64
```

Runbook detalhado:
- `docs/ios_launch_runbook.md`

Geracao assistida dos comandos de Secrets/Variables (GitHub CLI):

```bash
cd /var/www/mobile/rdo_offline_app
bash scripts/prepare_ios_ci_secrets.sh \
  --p12 /caminho/ios_dist.p12 \
  --p12-password 'SENHA_P12' \
  --profile /caminho/profile.mobileprovision \
  --asc-key /caminho/AuthKey_XXXXXX.p8 \
  --asc-key-id 'XXXXXX' \
  --asc-issuer-id '00000000-0000-0000-0000-000000000000' \
  --repo owner/repo \
  --release-env /var/www/mobile/rdo_offline_app/.release.env
```

O script imprime comandos `gh secret set` e `gh variable set` prontos para copia/cola.

## Rodar homologacao automatica (Parte 1)

Use o script unico abaixo para repetir a validacao automatica em `settings_dev`
(migracoes + testes backend + checks Flutter):

```bash
cd /var/www/mobile/rdo_offline_app
bash scripts/homologacao_parte1_auto.sh
```

## Checklist de homologacao (Parte 1)

Arquivo de acompanhamento da fase atual:

- `docs/homologacao_parte1_checklist.md`
- `docs/homologacao_parte1_runbook_manual.md`
- `docs/lancamento_fase3_checklist.md`
