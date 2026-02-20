#!/usr/bin/env bash
set -euo pipefail

ensure_ssh_linux() {
  require_root

  msg "Instalando/asegurando OpenSSH Server..."
  install_pkg "openssh-server"

  msg "Habilitando servicio para iniciar en boot..."
  systemctl enable ssh

  msg "Iniciando/reiniciando servicio..."
  systemctl restart ssh

  msg "Verificando estado..."
  systemctl --no-pager status ssh | sed -n '1,12p'

  msg "Puerto 22 escuchando (ss -lntp | grep :22)..."
  ss -lntp | grep -E ":(22)\b" || warn "No se detectó :22 escuchando. Revisa sshd."
}

hardening_basico_linux_opcional() {
  require_root

  # NO te lo hago agresivo porque tu práctica dice que es en entorno controlado.
  # Esto es “básico y seguro” sin romper acceso.
  msg "Hardening básico (opcional): deshabilitar login root por SSH y limitar intentos."
  local cfg="/etc/ssh/sshd_config"

  cp -a "$cfg" "${cfg}.bak.$(date +%F_%H%M%S)"

  # Ajustes seguros comunes:
  grep -qE '^\s*PermitRootLogin' "$cfg" \
    && sed -i 's/^\s*PermitRootLogin.*/PermitRootLogin no/' "$cfg" \
    || echo "PermitRootLogin no" >> "$cfg"

  grep -qE '^\s*MaxAuthTries' "$cfg" \
    && sed -i 's/^\s*MaxAuthTries.*/MaxAuthTries 3/' "$cfg" \
    || echo "MaxAuthTries 3" >> "$cfg"

  systemctl restart ssh
  msg "Listo. Si usas root por SSH en tus prácticas, NO apliques este hardening."
}