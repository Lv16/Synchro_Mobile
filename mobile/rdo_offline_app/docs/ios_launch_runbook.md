# iOS Launch Runbook (TestFlight)

## 1) Prerequisitos Apple

- App registrada no Apple Developer (Bundle ID):
  - `com.ambipar.synchro.rdoOfflineApp`
- App criada no App Store Connect.
- Certificado de distribuicao iOS exportado em `.p12`.
- Provisioning profile de distribuicao (`.mobileprovision`) para a app.
- API Key do App Store Connect (`.p8`, Key ID, Issuer ID).

## 2) Configurar GitHub Actions

Workflow:
- `.github/workflows/mobile_ios_testflight.yml`

### Variables (Repository Variables)

- `RDO_SYNC_URL`
- `RDO_SYNC_BATCH_URL`
- `RDO_PHOTO_UPLOAD_URL`
- `RDO_BOOTSTRAP_URL`
- `RDO_AUTH_TOKEN_URL`
- `RDO_AUTH_REVOKE_URL`
- `RDO_TRANSLATE_PREVIEW_URL` (opcional)
- `RDO_DEVICE_NAME` (opcional)

### Secrets (Repository Secrets)

- `IOS_BUILD_CERTIFICATE_BASE64` (conteudo base64 do `.p12`)
- `IOS_BUILD_CERTIFICATE_PASSWORD`
- `IOS_PROVISION_PROFILE_BASE64` (conteudo base64 do `.mobileprovision`)
- `IOS_KEYCHAIN_PASSWORD` (senha de uso temporario no runner)
- `APPSTORE_CONNECT_API_KEY_ID`
- `APPSTORE_CONNECT_ISSUER_ID`
- `APPSTORE_CONNECT_API_PRIVATE_KEY_BASE64` (conteudo base64 do `.p8`)

## 3) Gerar base64 dos arquivos (Linux/Mac)

Linux:

```bash
base64 -w 0 ios_dist.p12 > ios_dist.p12.b64
base64 -w 0 profile.mobileprovision > profile.mobileprovision.b64
base64 -w 0 AuthKey_XXXXXX.p8 > AuthKey_XXXXXX.p8.b64
```

macOS:

```bash
base64 ios_dist.p12 | tr -d '\n' > ios_dist.p12.b64
base64 profile.mobileprovision | tr -d '\n' > profile.mobileprovision.b64
base64 AuthKey_XXXXXX.p8 | tr -d '\n' > AuthKey_XXXXXX.p8.b64
```

Opcao mais rapida (gera comandos `gh` prontos):

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

## 4) Disparo do release

1. GitHub > `Actions`.
2. Workflow: `Mobile iOS Release (TestFlight)`.
3. `Run workflow`:
   - `build_name`: ex. `1.0.0`
   - `build_number`: ex. `21` (sempre subir)
   - `export_method`: `app-store`
   - `upload_to_testflight`: `true`

## 5) Pos-release

- Confirmar build em App Store Connect > TestFlight.
- Testar no iPhone:
  - Login Supervisor.
  - Listagem de OS atribuida.
  - Criacao de RDO.
  - Sincronizacao de fila.
  - Fluxo de fotos (camera + galeria).
  - Indicador de atualizacao do app.

## 6) Riscos comuns e mitigacao

- Erro de assinatura/provisioning:
  - revisar `.p12`, profile e Bundle ID.
- Erro de upload TestFlight:
  - revisar Key ID, Issuer ID e `.p8`.
- Build number rejeitado:
  - aumentar `build_number` no dispatch.
