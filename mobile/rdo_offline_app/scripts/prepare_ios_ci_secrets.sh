#!/usr/bin/env bash
set -euo pipefail

# Gera comandos prontos para configurar Secrets/Variables no GitHub Actions
# para o workflow iOS TestFlight, sem depender de configuracao manual extensa.

usage() {
  cat <<'EOF'
Uso:
  bash scripts/prepare_ios_ci_secrets.sh \
    --p12 /caminho/certificado.p12 \
    --p12-password 'SENHA_P12' \
    --profile /caminho/profile.mobileprovision \
    --asc-key /caminho/AuthKey_XXXXXX.p8 \
    --asc-key-id 'XXXXXX' \
    --asc-issuer-id '00000000-0000-0000-0000-000000000000' \
    [--repo owner/repo] \
    [--release-env /var/www/mobile/rdo_offline_app/.release.env] \
    [--device-name Ambipar_Supervisor]

Saida:
  - Comandos "gh secret set ..." para secrets obrigatorios de iOS.
  - Comandos "gh variable set ..." para variables de API usadas pelo app.

Observacoes:
  - Nao executa nada automaticamente no GitHub.
  - Apenas imprime os comandos para copiar/colar com seguranca.
EOF
}

base64_file() {
  local input="$1"
  if base64 --help 2>/dev/null | rg -q -- "-w"; then
    base64 -w 0 "$input"
  else
    base64 "$input" | tr -d '\n'
  fi
}

require_file() {
  local file="$1"
  local label="$2"
  if [[ ! -f "$file" ]]; then
    echo "ERRO: $label nao encontrado: $file" >&2
    exit 1
  fi
}

repo=''
release_env=''
device_name=''
p12_path=''
p12_password=''
profile_path=''
asc_key_path=''
asc_key_id=''
asc_issuer_id=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --p12)
      p12_path="$2"
      shift 2
      ;;
    --p12-password)
      p12_password="$2"
      shift 2
      ;;
    --profile)
      profile_path="$2"
      shift 2
      ;;
    --asc-key)
      asc_key_path="$2"
      shift 2
      ;;
    --asc-key-id)
      asc_key_id="$2"
      shift 2
      ;;
    --asc-issuer-id)
      asc_issuer_id="$2"
      shift 2
      ;;
    --repo)
      repo="$2"
      shift 2
      ;;
    --release-env)
      release_env="$2"
      shift 2
      ;;
    --device-name)
      device_name="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERRO: opcao invalida: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$p12_path" || -z "$p12_password" || -z "$profile_path" || -z "$asc_key_path" || -z "$asc_key_id" || -z "$asc_issuer_id" ]]; then
  echo "ERRO: faltam parametros obrigatorios." >&2
  usage
  exit 1
fi

require_file "$p12_path" "Certificado .p12"
require_file "$profile_path" "Provisioning profile"
require_file "$asc_key_path" "App Store Connect key (.p8)"

p12_b64="$(base64_file "$p12_path")"
profile_b64="$(base64_file "$profile_path")"
asc_key_b64="$(base64_file "$asc_key_path")"

repo_arg=()
if [[ -n "$repo" ]]; then
  repo_arg=(--repo "$repo")
fi

release_env_arg="${release_env:-}"
if [[ -z "$release_env_arg" ]]; then
  default_release_env="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.release.env"
  if [[ -f "$default_release_env" ]]; then
    release_env_arg="$default_release_env"
  fi
fi

echo ""
echo "### 1) Secrets obrigatorios (copiar/colar)"
echo "gh secret set IOS_BUILD_CERTIFICATE_BASE64 ${repo_arg[*]} -b'$p12_b64'"
echo "gh secret set IOS_BUILD_CERTIFICATE_PASSWORD ${repo_arg[*]} -b'$p12_password'"
echo "gh secret set IOS_PROVISION_PROFILE_BASE64 ${repo_arg[*]} -b'$profile_b64'"
echo "gh secret set IOS_KEYCHAIN_PASSWORD ${repo_arg[*]} -b'$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)'"
echo "gh secret set APPSTORE_CONNECT_API_KEY_ID ${repo_arg[*]} -b'$asc_key_id'"
echo "gh secret set APPSTORE_CONNECT_ISSUER_ID ${repo_arg[*]} -b'$asc_issuer_id'"
echo "gh secret set APPSTORE_CONNECT_API_PRIVATE_KEY_BASE64 ${repo_arg[*]} -b'$asc_key_b64'"

if [[ -n "$release_env_arg" && -f "$release_env_arg" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$release_env_arg"
  set +a

  echo ""
  echo "### 2) Variables do app (copiar/colar)"
  echo "gh variable set RDO_SYNC_URL ${repo_arg[*]} -b'${RDO_SYNC_URL:-}'"
  echo "gh variable set RDO_SYNC_BATCH_URL ${repo_arg[*]} -b'${RDO_SYNC_BATCH_URL:-}'"
  echo "gh variable set RDO_PHOTO_UPLOAD_URL ${repo_arg[*]} -b'${RDO_PHOTO_UPLOAD_URL:-}'"
  echo "gh variable set RDO_BOOTSTRAP_URL ${repo_arg[*]} -b'${RDO_BOOTSTRAP_URL:-}'"
  echo "gh variable set RDO_AUTH_TOKEN_URL ${repo_arg[*]} -b'${RDO_AUTH_TOKEN_URL:-}'"
  echo "gh variable set RDO_AUTH_REVOKE_URL ${repo_arg[*]} -b'${RDO_AUTH_REVOKE_URL:-}'"

  translate_url="${RDO_TRANSLATE_PREVIEW_URL:-${RDO_TRANSLATION_URL:-}}"
  if [[ -n "$translate_url" ]]; then
    echo "gh variable set RDO_TRANSLATE_PREVIEW_URL ${repo_arg[*]} -b'$translate_url'"
  fi

  final_device_name="${device_name:-${RDO_DEVICE_NAME:-}}"
  if [[ -n "$final_device_name" ]]; then
    echo "gh variable set RDO_DEVICE_NAME ${repo_arg[*]} -b'$final_device_name'"
  fi
fi

echo ""
echo "Pronto. Revise os comandos e execute no terminal com GitHub CLI autenticado."
