#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/var/www/mobile-sdk/flutter/bin/flutter}"
KEY_PROPERTIES="${KEY_PROPERTIES:-$ROOT_DIR/android/key.properties}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/dist/android}"
TARGET="${1:-both}" # apk | aab | both
FLAVOR_RAW="${FLAVOR:-prod}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export PATH="$JAVA_HOME/bin:$PATH"

normalize_flavor() {
  case "${1,,}" in
    prod|production) echo "prod" ;;
    homolog|hml|qa|staging) echo "homolog" ;;
    *)
      echo "ERRO: FLAVOR invalido '$1'. Use: prod | homolog"
      exit 1
      ;;
  esac
}

FLAVOR="$(normalize_flavor "$FLAVOR_RAW")"
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
  echo "Dica: copie $ROOT_DIR/.release.${FLAVOR}.env.example para $ROOT_DIR/.release.${FLAVOR}.env"
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
  BUILD_NAME
  BUILD_NUMBER
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "ERRO: variavel obrigatoria ausente em $ENV_FILE: $var_name"
    exit 1
  fi
done

if [[ ! -f "$KEY_PROPERTIES" ]]; then
  echo "ERRO: key.properties nao encontrado em: $KEY_PROPERTIES"
  echo "Dica: use o modelo $ROOT_DIR/android/key.properties.example"
  exit 1
fi

store_file_line="$(grep '^storeFile=' "$KEY_PROPERTIES" || true)"
store_file_path="${store_file_line#storeFile=}"
if [[ -z "$store_file_path" ]]; then
  echo "ERRO: key.properties sem storeFile configurado."
  exit 1
fi
if [[ ! -f "$store_file_path" ]]; then
  echo "ERRO: keystore nao encontrado em: $store_file_path"
  exit 1
fi

case "$TARGET" in
  apk|aab|both) ;;
  *)
    echo "ERRO: alvo invalido '$TARGET'. Use: apk | aab | both"
    exit 1
    ;;
esac

cd "$ROOT_DIR"

echo "[1/4] flutter pub get"
"$FLUTTER_BIN" pub get

release_channel="${RDO_RELEASE_CHANNEL:-$FLAVOR}"
app_title="${RDO_APP_TITLE:-}"
artifact_prefix="${ARTIFACT_PREFIX:-}"

if [[ -z "$app_title" ]]; then
  if [[ "$FLAVOR" == "homolog" ]]; then
    app_title="Ambipar Synchro HML"
  else
    app_title="Ambipar Synchro"
  fi
fi

if [[ -z "$artifact_prefix" ]]; then
  if [[ "$FLAVOR" == "homolog" ]]; then
    artifact_prefix="ambipar-synchro-hml"
  else
    artifact_prefix="ambipar-synchro"
  fi
fi

if [[ "$FLAVOR" == "homolog" && -z "${RDO_HOMOLOG_MODE:-}" ]]; then
  RDO_HOMOLOG_MODE=true
fi

common_args=(
  --release
  "--build-name=$BUILD_NAME"
  "--build-number=$BUILD_NUMBER"
  "--dart-define=RDO_RELEASE_CHANNEL=$release_channel"
  "--dart-define=RDO_APP_TITLE=$app_title"
  "--dart-define=RDO_SYNC_URL=$RDO_SYNC_URL"
  "--dart-define=RDO_SYNC_BATCH_URL=$RDO_SYNC_BATCH_URL"
  "--dart-define=RDO_PHOTO_UPLOAD_URL=$RDO_PHOTO_UPLOAD_URL"
  "--dart-define=RDO_BOOTSTRAP_URL=$RDO_BOOTSTRAP_URL"
  "--dart-define=RDO_AUTH_TOKEN_URL=$RDO_AUTH_TOKEN_URL"
  "--dart-define=RDO_AUTH_REVOKE_URL=$RDO_AUTH_REVOKE_URL"
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

echo "[2/4] flutter analyze"
"$FLUTTER_BIN" analyze

echo "[3/4] build release ($TARGET / $FLAVOR)"
if [[ "$TARGET" == "apk" || "$TARGET" == "both" ]]; then
  "$FLUTTER_BIN" build apk "--flavor=$FLAVOR" "${common_args[@]}"
fi

if [[ "$TARGET" == "aab" || "$TARGET" == "both" ]]; then
  "$FLUTTER_BIN" build appbundle "--flavor=$FLAVOR" "${common_args[@]}"
fi

timestamp="$(date +%Y%m%d_%H%M%S)"
release_dir="$OUTPUT_ROOT/${timestamp}_${FLAVOR}_v${BUILD_NAME}+${BUILD_NUMBER}"
mkdir -p "$release_dir"

if [[ "$TARGET" == "apk" || "$TARGET" == "both" ]]; then
  cp "$ROOT_DIR/build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk" \
    "$release_dir/${artifact_prefix}-v${BUILD_NAME}+${BUILD_NUMBER}.apk"
fi

if [[ "$TARGET" == "aab" || "$TARGET" == "both" ]]; then
  cp "$ROOT_DIR/build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab" \
    "$release_dir/${artifact_prefix}-v${BUILD_NAME}+${BUILD_NUMBER}.aab"
fi

echo "[4/4] concluido"
echo "Artefatos em: $release_dir"
echo "Flavor: $FLAVOR"
