#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/var/www/mobile-sdk/flutter/bin/flutter}"
FLAVOR_RAW="${FLAVOR:-homolog}"
MODE_RAW="${MODE:-debug}"
DEVICE_ID="${DEVICE_ID:-}"

normalize_flavor() {
  case "${1,,}" in
    prod|production) echo "prod" ;;
    homolog|hml|qa|staging) echo "homolog" ;;
    *)
      echo "ERRO: FLAVOR invalido '$1'. Use prod ou homolog." >&2
      exit 1
      ;;
  esac
}

normalize_mode() {
  case "${1,,}" in
    debug) echo "--debug" ;;
    profile) echo "--profile" ;;
    release) echo "--release" ;;
    *)
      echo "ERRO: MODE invalido '$1'. Use debug, profile ou release." >&2
      exit 1
      ;;
  esac
}

FLAVOR="$(normalize_flavor "$FLAVOR_RAW")"
MODE_FLAG="$(normalize_mode "$MODE_RAW")"
DEFAULT_ENV_FILE="$ROOT_DIR/.release.$FLAVOR.env"
LEGACY_ENV_FILE="$ROOT_DIR/.release.env"

if [[ -z "${ENV_FILE:-}" ]]; then
  if [[ -f "$DEFAULT_ENV_FILE" ]]; then
    ENV_FILE="$DEFAULT_ENV_FILE"
  else
    ENV_FILE="$LEGACY_ENV_FILE"
  fi
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERRO: arquivo de ambiente nao encontrado: $ENV_FILE"
  echo "Dica: copie $ROOT_DIR/.release.homolog.env.example para $ROOT_DIR/.release.homolog.env"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

required_vars=(
  RDO_SYNC_URL
  RDO_SYNC_BATCH_URL
  RDO_PHOTO_UPLOAD_URL
  RDO_BOOTSTRAP_URL
  RDO_AUTH_TOKEN_URL
  RDO_AUTH_REVOKE_URL
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "ERRO: variavel obrigatoria ausente em $ENV_FILE: $var_name"
    exit 1
  fi
done

release_channel="${RDO_RELEASE_CHANNEL:-$FLAVOR}"
app_title="${RDO_APP_TITLE:-}"
if [[ -z "$app_title" ]]; then
  if [[ "$FLAVOR" == "homolog" ]]; then
    app_title="Ambipar Synchro HML"
  else
    app_title="Ambipar Synchro"
  fi
fi

if [[ "$FLAVOR" == "homolog" && -z "${RDO_HOMOLOG_MODE:-}" ]]; then
  RDO_HOMOLOG_MODE=true
fi

cd "$ROOT_DIR"

echo "[1/2] flutter pub get"
"$FLUTTER_BIN" pub get

common_args=(
  "$MODE_FLAG"
  "--flavor=$FLAVOR"
  "--dart-define=RDO_SYNC_URL=$RDO_SYNC_URL"
  "--dart-define=RDO_SYNC_BATCH_URL=$RDO_SYNC_BATCH_URL"
  "--dart-define=RDO_PHOTO_UPLOAD_URL=$RDO_PHOTO_UPLOAD_URL"
  "--dart-define=RDO_BOOTSTRAP_URL=$RDO_BOOTSTRAP_URL"
  "--dart-define=RDO_AUTH_TOKEN_URL=$RDO_AUTH_TOKEN_URL"
  "--dart-define=RDO_AUTH_REVOKE_URL=$RDO_AUTH_REVOKE_URL"
  "--dart-define=RDO_RELEASE_CHANNEL=$release_channel"
  "--dart-define=RDO_APP_TITLE=$app_title"
)

if [[ -n "${RDO_TRANSLATION_URL:-}" ]]; then
  common_args+=("--dart-define=RDO_TRANSLATION_URL=$RDO_TRANSLATION_URL")
fi

translation_preview_url="${RDO_TRANSLATE_PREVIEW_URL:-}"
if [[ -z "$translation_preview_url" ]]; then
  translation_preview_url="${RDO_TRANSLATION_URL:-}"
fi

if [[ -n "$translation_preview_url" ]]; then
  common_args+=("--dart-define=RDO_TRANSLATE_PREVIEW_URL=$translation_preview_url")
fi

if [[ -n "${RDO_DEVICE_NAME:-}" ]]; then
  common_args+=("--dart-define=RDO_DEVICE_NAME=$RDO_DEVICE_NAME")
fi

if [[ -n "${RDO_APP_UPDATE_URL:-}" ]]; then
  common_args+=("--dart-define=RDO_APP_UPDATE_URL=$RDO_APP_UPDATE_URL")
fi

if [[ -n "${RDO_MOBILE_RDO_PAGE_URL:-}" ]]; then
  common_args+=("--dart-define=RDO_MOBILE_RDO_PAGE_URL=$RDO_MOBILE_RDO_PAGE_URL")
fi

if [[ -n "${RDO_MOBILE_OS_RDOS_URL:-}" ]]; then
  common_args+=("--dart-define=RDO_MOBILE_OS_RDOS_URL=$RDO_MOBILE_OS_RDOS_URL")
fi

if [[ "${RDO_HOMOLOG_MODE:-false}" == "true" ]]; then
  common_args+=("--dart-define=RDO_HOMOLOG_MODE=true")
fi

if [[ -n "$DEVICE_ID" ]]; then
  common_args+=("-d" "$DEVICE_ID")
fi

echo "[2/2] flutter run ($FLAVOR / ${MODE_RAW,,})"
"$FLUTTER_BIN" run "${common_args[@]}" "$@"
