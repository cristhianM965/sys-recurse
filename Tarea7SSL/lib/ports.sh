#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

is_valid_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  (( port >= 1 && port <= 65535 ))
}

is_port_in_use() {
  local port="$1"
  ss -tuln | awk '{print $5}' | grep -qE "[:.]${port}$"
}

require_free_port() {
  local port="$1"
  is_valid_port "$port" || die "Puerto inválido: $port"

  if is_port_in_use "$port"; then
    log "El puerto $port ya está en uso."
    return 1
  fi
  return 0
}

ask_for_port() {
  local label="$1"
  local port

  while true; do
    read -r -p "Ingrese el puerto para $label: " port

    if ! is_valid_port "$port"; then
      echo "Puerto inválido. Debe estar entre 1 y 65535."
      continue
    fi

    if is_port_in_use "$port"; then
      echo "El puerto $port ya está ocupado. Elija otro."
      continue
    fi

    echo "$port"
    return 0
  done
}