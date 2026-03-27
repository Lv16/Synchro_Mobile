#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/var/www/mobile-sdk/flutter/bin/flutter}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/dist/ios}"
NO_CODESIGN="${NO_CODESIGN:-true}" # true | false
RELEASE_CHANNEL_RAW="${RELEASE_CHANNEL:-prod}"

normalize_channel() {
  case "${1,,}" in
    prod|production) echo "prod" ;;
    homolog|hml|qa|staging) echo "homolog" ;;
    *)
      echo "ERRO: RELEASE_CHANNEL invalido '$1'. Use: prod | homolog"
      exit 1
      ;;
  esac
}

RELEASE_CHANNEL="$(normalize_channel "$RELEASE_CHANNEL_RAW")"
DEFAULT_ENV_FILE="$ROOT_DIR/.release.$RELEASE_CHANNEL.env"
LEGACY_ENV_FILE="$ROOT_DIR/.release.env"

if [[ -z "${ENV_FILE:-}" ]]; then
  if [[ -f "$DEFAULT_ENV_FILE" ]]; then
    ENV_FILE="$DEFAULT_ENV_FILE"
  else
    ENV_FILE="$LEGACY_ENV_FILE"
  fi
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERRO: build iOS so pode rodar em macOS (Xcode)."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERRO: xcodebuild nao encontrado. Instale o Xcode."
  exit 1
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "ERRO: CocoaPods nao encontrado. Instale com: sudo gem install cocoapods"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERRO: arquivo de ambiente nao encontrado: $ENV_FILE"
  echo "Dica: copie $ROOT_DIR/.release.${RELEASE_CHANNEL}.env.example para $ROOT_DIR/.release.${RELEASE_CHANNEL}.env"
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

cd "$ROOT_DIR"

echo "[1/5] flutter pub get"
"$FLUTTER_BIN" pub get

app_title="${RDO_APP_TITLE:-}"
artifact_prefix="${ARTIFACT_PREFIX:-}"
if [[ -z "$app_title" ]]; then
  if [[ "$RELEASE_CHANNEL" == "homolog" ]]; then
    app_title="Ambipar Synchro HML"
  else
    app_title="Ambipar Synchro"
  fi
fi
if [[ -z "$artifact_prefix" ]]; then
  if [[ "$RELEASE_CHANNEL" == "homolog" ]]; then
    artifact_prefix="ambipar-synchro-hml"
  else
    artifact_prefix="ambipar-synchro"
  fi
fi
if [[ "$RELEASE_CHANNEL" == "homolog" && -z "${RDO_HOMOLOG_MODE:-}" ]]; then
  RDO_HOMOLOG_MODE=true
fi

echo "[2/5] flutter analyze"
"$FLUTTER_BIN" analyze

echo "[3/5] pod install"
(
  cd ios
  pod install
)

common_args=(
  --release
  "--build-name=$BUILD_NAME"
  "--build-number=$BUILD_NUMBER"
  "--dart-define=RDO_RELEASE_CHANNEL=$RELEASE_CHANNEL"
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

if [[ "$NO_CODESIGN" == "true" ]]; then
  common_args+=(--no-codesign)
fi

echo "[4/5] flutter build ipa"
"$FLUTTER_BIN" build ipa "${common_args[@]}"

timestamp="$(date +%Y%m%d_%H%M%S)"
release_dir="$OUTPUT_ROOT/${timestamp}_${RELEASE_CHANNEL}_v${BUILD_NAME}+${BUILD_NUMBER}"
mkdir -p "$release_dir"

ipa_path="$(ls -1 "$ROOT_DIR"/build/ios/ipa/*.ipa 2>/dev/null | head -n 1 || true)"
archive_path="$ROOT_DIR/build/ios/archive/Runner.xcarchive"

if [[ -n "$ipa_path" && -f "$ipa_path" ]]; then
  cp "$ipa_path" "$release_dir/${artifact_prefix}-v${BUILD_NAME}+${BUILD_NUMBER}.ipa"
fi

if [[ -d "$archive_path" ]]; then
  tar -czf "$release_dir/Runner.xcarchive.tgz" -C "$(dirname "$archive_path")" "$(basename "$archive_path")"
fi

echo "[5/5] concluido"
echo "Artefatos em: $release_dir"
if [[ "$NO_CODESIGN" == "true" ]]; then
  echo "Obs: build sem assinatura (NO_CODESIGN=true). Use Xcode/TestFlight para assinatura/distribuicao."
fi
