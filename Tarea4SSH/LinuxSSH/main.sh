#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/net.sh"
source "$SCRIPT_DIR/lib/ssh.sh"

menu() {
  clear
  echo "=== TAREA 4 - SSH (LINUX) ==="
  echo "1) Instalar + habilitar + arrancar SSH"
  echo "2) Hardening básico (OPCIONAL)"
  echo "0) Salir"
  echo
  read -rp "Elige opción: " opt
  case "$opt" in
    1) ensure_ssh_linux; pause ;;
    2) hardening_basico_linux_opcional; pause ;;
    0) exit 0 ;;
    *) warn "Opción inválida"; pause ;;
  esac
}

while true; do menu; done