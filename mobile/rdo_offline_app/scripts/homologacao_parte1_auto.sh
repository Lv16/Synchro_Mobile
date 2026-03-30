#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/var/www}"
BACKEND_DIR="${BACKEND_DIR:-$ROOT_DIR/html/GESTAO_OPERACIONAL}"
MOBILE_DIR="${MOBILE_DIR:-$ROOT_DIR/mobile/rdo_offline_app}"
PYTHON_BIN="${PYTHON_BIN:-$BACKEND_DIR/venv_new/bin/python}"
FLUTTER_BIN="${FLUTTER_BIN:-$ROOT_DIR/mobile-sdk/flutter/bin/flutter}"
DJANGO_SETTINGS="${DJANGO_SETTINGS:-setup.settings_dev}"

echo "[1/5] Django migrate ($DJANGO_SETTINGS)"
cd "$BACKEND_DIR"
"$PYTHON_BIN" manage.py migrate --settings="$DJANGO_SETTINGS" --noinput

echo "[2/5] Django tests (mobile + RDO)"
"$PYTHON_BIN" manage.py test \
  GO.tests.test_mobile_sync_api \
  GO.tests.test_rdo_tank_association \
  GO.tests.test_tank_alias_normalization \
  --settings="$DJANGO_SETTINGS"

echo "[3/5] Flutter pub get"
cd "$MOBILE_DIR"
"$FLUTTER_BIN" pub get

echo "[4/5] Flutter analyze"
"$FLUTTER_BIN" analyze

echo "[5/5] Flutter test"
"$FLUTTER_BIN" test

echo
echo "Homologacao automatica da Parte 1 concluida com sucesso."
