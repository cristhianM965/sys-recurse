#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

verify_port() {
  local port="$1"
  if ss -tuln | awk '{print $5}' | grep -qE "[:.]${port}$"; then
    log "OK: puerto $port en escucha"
    return 0
  else
    log "FAIL: puerto $port no está en escucha"
    return 1
  fi
}

verify_service() {
  local svc="$1"
  if systemctl is-active --quiet "$svc"; then
    log "OK: servicio activo -> $svc"
  else
    log "FAIL: servicio inactivo -> $svc"
  fi
}

verify_https() {
  local name="$1"
  local port="$2"

  if curl -kI --max-time 10 "https://127.0.0.1:$port" >/tmp/"$name"_https.txt 2>/dev/null; then
    log "OK: $name responde por HTTPS en $port"
  else
    log "FAIL: $name no responde por HTTPS en $port"
  fi
}

verify_http() {
  local name="$1"
  local port="$2"

  if curl -I --max-time 10 "http://127.0.0.1:$port" >/tmp/"$name"_http.txt 2>/dev/null; then
    log "OK: $name responde por HTTP en $port"
  else
    log "FAIL: $name no responde por HTTP en $port"
  fi
}

verify_ftps() {
  local port="$1"
  if openssl s_client -starttls ftp -connect "127.0.0.1:$port" </dev/null >/tmp/ftps_test.txt 2>&1; then
    log "OK: FTPS responde en puerto $port"
  else
    log "FAIL: FTPS no responde en puerto $port"
  fi
}

show_summary() {
  echo
  echo "============= RESUMEN ============="
  grep -E "OK:|FAIL:|WARN:|ERROR:" "$LOG_FILE" | tail -n 80
  echo "=================================="
}