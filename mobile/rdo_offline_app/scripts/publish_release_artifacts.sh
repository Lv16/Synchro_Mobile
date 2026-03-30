#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_ANDROID_DIR="${DIST_ANDROID_DIR:-$ROOT_DIR/dist/android}"
TARGET_STATIC_DIR="${TARGET_STATIC_DIR:-/var/www/html/GESTAO_OPERACIONAL/static/mobile/releases}"
BASE_URL="${BASE_URL:-https://synchro.ambipar.vps-kinghost.net/static/mobile/releases}"
RELEASE_DIR="${1:-}"

normalize_channel() {
  case "${1,,}" in
    prod|production) echo "prod" ;;
    homolog|hml|qa|staging) echo "homolog" ;;
    *) echo "" ;;
  esac
}

if [[ -z "$RELEASE_DIR" ]]; then
  RELEASE_DIR="$(ls -1dt "$DIST_ANDROID_DIR"/* 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$RELEASE_DIR" || ! -d "$RELEASE_DIR" ]]; then
  echo "ERRO: diretorio de release nao encontrado em $DIST_ANDROID_DIR"
  exit 1
fi

APK_SRC="$(ls -1 "$RELEASE_DIR"/*.apk 2>/dev/null | head -n 1 || true)"
AAB_SRC="$(ls -1 "$RELEASE_DIR"/*.aab 2>/dev/null | head -n 1 || true)"

if [[ -z "$APK_SRC" ]]; then
  echo "ERRO: APK nao encontrado em $RELEASE_DIR"
  exit 1
fi

mkdir -p "$TARGET_STATIC_DIR"

APK_BASENAME="$(basename "$APK_SRC")"
channel="$(normalize_channel "${RELEASE_CHANNEL:-}")"
if [[ -z "$channel" ]]; then
  case "$APK_BASENAME" in
    *-hml-*|*homolog*) channel="homolog" ;;
    *) channel="prod" ;;
  esac
fi

if [[ "$channel" == "homolog" ]]; then
  latest_prefix="ambipar-synchro-hml"
else
  latest_prefix="ambipar-synchro"
fi

cp -f "$APK_SRC" "$TARGET_STATIC_DIR/$APK_BASENAME"
cp -f "$APK_SRC" "$TARGET_STATIC_DIR/${latest_prefix}-latest.apk"

if [[ -n "$AAB_SRC" ]]; then
  AAB_BASENAME="$(basename "$AAB_SRC")"
  cp -f "$AAB_SRC" "$TARGET_STATIC_DIR/$AAB_BASENAME"
  cp -f "$AAB_SRC" "$TARGET_STATIC_DIR/${latest_prefix}-latest.aab"
fi

sha256sum "$TARGET_STATIC_DIR/$APK_BASENAME" > "$TARGET_STATIC_DIR/$APK_BASENAME.sha256"
sha256sum "$TARGET_STATIC_DIR/${latest_prefix}-latest.apk" > "$TARGET_STATIC_DIR/${latest_prefix}-latest.apk.sha256"

if [[ -n "${AAB_SRC:-}" ]]; then
  sha256sum "$TARGET_STATIC_DIR/$AAB_BASENAME" > "$TARGET_STATIC_DIR/$AAB_BASENAME.sha256"
  sha256sum "$TARGET_STATIC_DIR/${latest_prefix}-latest.aab" > "$TARGET_STATIC_DIR/${latest_prefix}-latest.aab.sha256"
fi

cat <<EOF2
Publicacao concluida.
Release origem: $RELEASE_DIR
Canal: $channel

APK:
- $TARGET_STATIC_DIR/$APK_BASENAME
- $TARGET_STATIC_DIR/${latest_prefix}-latest.apk
- URL: $BASE_URL/${latest_prefix}-latest.apk

AAB:
- ${AAB_SRC:+$TARGET_STATIC_DIR/$AAB_BASENAME}
- ${AAB_SRC:+$TARGET_STATIC_DIR/${latest_prefix}-latest.aab}

Para habilitar o botao no web (/mobile-app/), configure:
MOBILE_APP_DOWNLOAD_ENABLED=true
MOBILE_APP_ANDROID_URL=$BASE_URL/${latest_prefix}-latest.apk
MOBILE_APP_IOS_URL=
EOF2
