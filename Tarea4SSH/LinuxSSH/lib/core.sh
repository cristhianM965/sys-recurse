#!/usr/bin/env bash
set -euo pipefail

msg()  { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
die()  { echo -e "[ERROR] $*" >&2; exit 1; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Ejecuta como root (sudo)."
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

pause() {
  read -rp "Enter para continuar..."
}