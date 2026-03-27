# Checklist de Lancamento - Fase 3

## 1) Backend/API (obrigatorio)

- [ ] `settings.py` em uso no servidor de producao.
- [ ] Endpoints mobile ativos e respondendo `200/401` conforme esperado:
  - [ ] `POST /api/mobile/v1/auth/token/`
  - [ ] `GET /api/mobile/v1/bootstrap/`
  - [ ] `POST /api/mobile/v1/rdo/sync/`
  - [ ] `POST /api/mobile/v1/rdo/sync/batch/`
- [ ] Supervisor real autenticando no app.
- [ ] Fluxo de OS atribuida aparecendo no app.

## 2) Build Android (obrigatorio)

- [ ] `android/key.properties` configurado com keystore oficial.
- [ ] `.release.env` preenchido com URLs reais.
- [ ] Build executado:
  - [ ] `bash scripts/build_android_release.sh apk`
  - [ ] `bash scripts/build_android_release.sh aab`
- [ ] APK instalado em aparelho real.
- [ ] AAB gerado para publicacao.

## 3) Validacao funcional (obrigatorio)

- [ ] Login supervisor.
- [ ] Iniciar RDO.
- [ ] Salvar RDO local.
- [ ] Auto-sync ou sync manual concluindo sem erro.
- [ ] RDO aparecendo no web no local correto.
- [ ] KPI diario e acumulado refletindo os dados enviados.

## 4) Distribuicao web (obrigatorio)

- [ ] Pagina de download publicada em `/mobile-app/`.
- [ ] Variaveis de ambiente configuradas no backend:
  - [ ] `MOBILE_APP_DOWNLOAD_ENABLED=true`
  - [ ] `MOBILE_APP_ANDROID_URL=<link oficial APK/loja>`
  - [ ] `MOBILE_APP_IOS_URL=<link iOS quando disponivel>`

## 5) Fora do escopo desta fase

- [ ] Upload de fotos (release futura).
- [ ] Publicacao iOS (release futura).
