#!/usr/bin/env bash
set -euo pipefail

# =========================
# DNS Automation - Linux BIND9
# Domain: reprobados.com
# =========================

DOMAIN_DEFAULT="reprobados.com"
ZONEFILE_DEFAULT="/var/cache/bind/db.reprobados.com"
NAMED_LOCAL="/etc/bind/named.conf.local"

log(){ echo -e "[INFO] $*"; }
warn(){ echo -e "[WARN] $*" >&2; }
err(){ echo -e "[ERROR] $*" >&2; exit 1; }

need_root(){
  if [[ $EUID -ne 0 ]]; then
    err "Ejecuta como root: sudo $0 ..."
  fi
}

has_static_ip_netplan(){
  # Detecta si existe 'dhcp4: no' y 'addresses:' en algún YAML de netplan
  local f
  for f in /etc/netplan/*.yaml /etc/netplan/*.yml; do
    [[ -f "$f" ]] || continue
    if grep -qE "dhcp4:\s*no" "$f" && grep -qE "addresses:" "$f"; then
      return 0
    fi
  done
  return 1
}

detect_iface(){
  # Intenta detectar interfaz principal (no loopback)
  ip -o link show | awk -F': ' '{print $2}' | grep -vE 'lo' | head -n 1
}

configure_static_ip_netplan(){
  local iface="$1"
  local ipcidr="$2"
  local gw="$3"
  local dns="$4"
  local outfile="/etc/netplan/01-dns-static.yaml"

  log "Configurando IP fija con netplan en $iface -> $ipcidr (GW $gw, DNS $dns)"
  cat > "$outfile" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $iface:
      dhcp4: no
      addresses:
        - $ipcidr
      routes:
        - to: default
          via: $gw
      nameservers:
        addresses: [$dns]
EOF

  netplan generate
  netplan apply
  log "IP fija aplicada. (Archivo: $outfile)"
}

bind_installed(){
  dpkg -s bind9 >/dev/null 2>&1
}

bind_running(){
  systemctl is-active --quiet bind9
}

install_bind(){
  log "Instalando paquetes: bind9 bind9utils bind9-doc"
  apt-get update -y
  apt-get install -y bind9 bind9utils bind9-doc
}

ensure_named_conf_local_zone(){
  local domain="$1"
  local zonefile="$2"

  if grep -qE "zone \"${domain}\"" "$NAMED_LOCAL" 2>/dev/null; then
    log "Zona ya declarada en $NAMED_LOCAL (idempotente)."
    return
  fi

  log "Agregando declaración de zona en $NAMED_LOCAL"
  cat >> "$NAMED_LOCAL" <<EOF

zone "${domain}" {
  type master;
  file "${zonefile}";
};
EOF
}

increment_serial_yyyymmddnn(){
  local old="$1"
  local today
  today="$(date +%Y%m%d)"
  # formato: YYYYMMDDNN
  if [[ "$old" =~ ^${today}([0-9]{2})$ ]]; then
    local nn="${BASH_REMATCH[1]}"
    local newnn
    newnn=$(printf "%02d" $((10#$nn + 1)))
    echo "${today}${newnn}"
  else
    echo "${today}01"
  fi
}

ensure_zonefile(){
  local domain="$1"
  local zonefile="$2"
  local target_ip="$3"
  local use_cname="$4"

  mkdir -p "$(dirname "$zonefile")"

  if [[ -f "$zonefile" ]]; then
    log "Archivo de zona existe: $zonefile (se actualizarán registros si es necesario)."
  else
    log "Creando archivo de zona: $zonefile"
    cat > "$zonefile" <<EOF
\$TTL    604800
@   IN  SOA ns1.${domain}. admin.${domain}. (
        2026010101 ; Serial
        604800     ; Refresh
        86400      ; Retry
        2419200    ; Expire
        604800 )   ; Negative Cache TTL
;
@       IN  NS  ns1.${domain}.
ns1     IN  A   127.0.0.1
@       IN  A   ${target_ip}
EOF

    if [[ "$use_cname" == "true" ]]; then
      echo "www     IN  CNAME   @" >> "$zonefile"
    else
      echo "www     IN  A       ${target_ip}" >> "$zonefile"
    fi
  fi

  # Actualizar serial y registros A/CNAME de forma idempotente
  local current_serial
  current_serial="$(awk '/Serial/{print $1; exit}' "$zonefile" || true)"
  if [[ -n "$current_serial" ]]; then
    local new_serial
    new_serial="$(increment_serial_yyyymmddnn "$current_serial")"
    sed -i "0,/^[0-9]\{10\}[[:space:]]*; Serial/s//${new_serial} ; Serial/" "$zonefile" || true
  fi

  # Root A record (@)
  if grep -qE "^[[:space:]]*@?[[:space:]]+IN[[:space:]]+A" "$zonefile"; then
    # reemplaza la primera coincidencia de "@ IN A ..."
    sed -i "0,/^[[:space:]]*@?[[:space:]]\+IN[[:space:]]\+A[[:space:]]\+.*/s//@       IN  A   ${target_ip}/" "$zonefile"
  else
    echo "@       IN  A   ${target_ip}" >> "$zonefile"
  fi

  # www
  if [[ "$use_cname" == "true" ]]; then
    # elimina A de www si existe y asegura CNAME
    sed -i "/^www[[:space:]].*IN[[:space:]]\+A[[:space:]]/d" "$zonefile"
    if grep -qE "^www[[:space:]].*IN[[:space:]]+CNAME" "$zonefile"; then
      sed -i "0,/^www[[:space:]].*IN[[:space:]]\+CNAME.*/s//www     IN  CNAME   @/" "$zonefile"
    else
      echo "www     IN  CNAME   @" >> "$zonefile"
    fi
  else
    # elimina CNAME de www si existe y asegura A
    sed -i "/^www[[:space:]].*IN[[:space:]]\+CNAME/d" "$zonefile"
    if grep -qE "^www[[:space:]].*IN[[:space:]]+A" "$zonefile"; then
      sed -i "0,/^www[[:space:]].*IN[[:space:]]\+A.*/s//www     IN  A       ${target_ip}/" "$zonefile"
    else
      echo "www     IN  A       ${target_ip}" >> "$zonefile"
    fi
  fi
}

validate_bind(){
  log "Validando sintaxis: named-checkconf"
  named-checkconf
  log "Validando zona: named-checkzone"
  named-checkzone reprobados.com /var/cache/bind/db.reprobados.com
}

restart_bind(){
  log "Reiniciando y habilitando bind9"
  systemctl enable --now bind9
  systemctl restart bind9
  systemctl --no-pager status bind9 || true
}

run_client_tests_ssh(){
  local client_ip="$1"
  local client_user="$2"
  local server_ip="$3"
  local domain="$4"

  log "Ejecutando pruebas desde cliente via SSH: ${client_user}@${client_ip}"
  ssh -o StrictHostKeyChecking=no "${client_user}@${client_ip}" bash -s <<EOF
set -e
echo "=== nslookup ${domain} (usando DNS ${server_ip}) ==="
nslookup ${domain} ${server_ip} || true
echo "=== nslookup www.${domain} (usando DNS ${server_ip}) ==="
nslookup www.${domain} ${server_ip} || true
echo "=== ping -c 2 www.${domain} ==="
ping -c 2 www.${domain} || true
EOF
}

usage(){
  cat <<EOF
Uso:
  sudo $0 --target-ip 192.168.100.50 --server-ip 192.168.100.10 [opciones]

Obligatorio:
  --target-ip       IP a la que resolverán reprobados.com y www (IP del cliente/VM referenciada)
  --server-ip       IP del servidor DNS (esta máquina) para pruebas desde cliente

Opciones:
  --domain          Dominio (default: reprobados.com)
  --use-cname       true|false (default: true)  -> www como CNAME a @ o como A directo
  --set-static-ip   true|false (default: true)  -> si no hay IP fija, pedir datos y configurar netplan
  --iface           Interfaz para IP fija (default: auto)
  --client-ip       IP del cliente para pruebas SSH (opcional)
  --client-user     Usuario SSH del cliente (default: ubuntu)
EOF
}

main(){
  need_root

  local domain="$DOMAIN_DEFAULT"
  local zonefile="$ZONEFILE_DEFAULT"
  local target_ip=""
  local server_ip=""
  local use_cname="true"
  local set_static_ip="true"
  local iface=""
  local client_ip=""
  local client_user="ubuntu"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain) domain="$2"; shift 2;;
      --target-ip) target_ip="$2"; shift 2;;
      --server-ip) server_ip="$2"; shift 2;;
      --use-cname) use_cname="$2"; shift 2;;
      --set-static-ip) set_static_ip="$2"; shift 2;;
      --iface) iface="$2"; shift 2;;
      --client-ip) client_ip="$2"; shift 2;;
      --client-user) client_user="$2"; shift 2;;
      -h|--help) usage; exit 0;;
      *) err "Argumento desconocido: $1";;
    esac
  done

  [[ -n "$target_ip" ]] || { usage; err "Falta --target-ip"; }
  [[ -n "$server_ip" ]] || { usage; err "Falta --server-ip"; }

  # 1) IP fija
  if [[ "$set_static_ip" == "true" ]]; then
    if has_static_ip_netplan; then
      log "IP fija detectada en netplan (OK)."
    else
      warn "No se detectó IP fija en netplan."
      iface="${iface:-$(detect_iface)}"
      [[ -n "$iface" ]] || err "No pude detectar interfaz. Usa --iface enp0sX"

      read -r -p "IP/CIDR para el servidor (ej. 192.168.100.10/24): " ipcidr
      read -r -p "Gateway (ej. 192.168.100.1): " gw
      read -r -p "DNS upstream (ej. 8.8.8.8 o tu DNS anterior): " dns
      configure_static_ip_netplan "$iface" "$ipcidr" "$gw" "$dns"
    fi
  fi

  # 2) Instalación / Idempotencia
  if ! bind_installed; then
    install_bind
  else
    log "BIND9 ya está instalado (idempotente)."
  fi

  if bind_running; then
    log "bind9 ya está corriendo (idempotente)."
  else
    log "bind9 no está activo aún; se activará al final."
  fi

  # 3) Zona y registros
  ensure_named_conf_local_zone "$domain" "$zonefile"
  ensure_zonefile "$domain" "$zonefile" "$target_ip" "$use_cname"

  # 4) Validación + restart
  validate_bind
  restart_bind

  # 5) Pruebas desde cliente (opcional)
  if [[ -n "$client_ip" ]]; then
    run_client_tests_ssh "$client_ip" "$client_user" "$server_ip" "$domain"
  else
    log "Pruebas desde cliente: no se ejecutaron (no se dio --client-ip)."
    log "Manual: nslookup ${domain} ${server_ip}  y  ping www.${domain}"
  fi

  log "Listo. Dominio ${domain} debe resolver a ${target_ip}."
}

main "$@"
