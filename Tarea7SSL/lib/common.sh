#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.env"

log() {
  local msg="$1"
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
  echo "[$(date '+%F %T')] $msg" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $1"
  exit 1
}

require_root() {
  [[ $EUID -eq 0 ]] || die "Ejecuta este script como root."
}

ensure_dirs() {
  mkdir -p "$WORKDIR"
  mkdir -p "$DOWNLOAD_DIR"
  mkdir -p "$CERT_DIR"
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_base_tools() {
  log "Instalando herramientas base necesarias..."
  apt-get update -y
  apt-get install -y \
    curl \
    wget \
    unzip \
    openssl \
    ca-certificates \
    tar \
    systemd \
    procps \
    iproute2 \
    grep \
    sed \
    gawk \
    coreutils
}

ask_yes_no() {
  local prompt="$1"
  local ans

  while true; do
    read -r -p "$prompt [S/N]: " ans
    case "${ans^^}" in
      S|SI) return 0 ;;
      N|NO) return 1 ;;
      *) echo "Responde S o N." ;;
    esac
  done
}

select_option() {
  local title="$1"
  shift
  local options=("$@")

  [[ ${#options[@]} -gt 0 ]] || die "No hay opciones disponibles para seleccionar."

  echo >&2
  echo "$title" >&2

  local i=1
  for opt in "${options[@]}"; do
    echo "  $i) $opt" >&2
    ((i++))
  done

  local choice
  while true; do
    read -r -p "Seleccione una opción: " choice >&2
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "${options[$((choice-1))]}"
      return 0
    fi
    echo "Opción inválida." >&2
  done
}

trim() {
  local var="$1"
  # shellcheck disable=SC2001
  echo "$(echo "$var" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
}

service_exists_systemd() {
  local svc="$1"
  systemctl list-unit-files | awk '{print $1}' | grep -q "^${svc}\.service$"
}

safe_systemctl_restart() {
  local svc="$1"
  if service_exists_systemd "$svc"; then
    systemctl restart "$svc"
  else
    die "El servicio systemd '$svc' no existe."
  fi
}

safe_systemctl_enable_now() {
  local svc="$1"
  if service_exists_systemd "$svc"; then
    systemctl enable --now "$svc"
  else
    die "El servicio systemd '$svc' no existe."
  fi
}