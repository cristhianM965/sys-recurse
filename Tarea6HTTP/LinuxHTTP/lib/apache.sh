#!/usr/bin/env bash
set -Eeuo pipefail

linux_install_apache() {
  local version="$1"
  local port="$2"

  echo "Instalando Apache2 versión ${version}..."
  linux_run_apt_update

  export DEBIAN_FRONTEND=noninteractive
  if ! apt-get install -y "apache2=${version}"; then
    echo "No se pudo instalar exactamente la versión elegida."
    echo "Se intentará instalar la versión disponible del repositorio."
    apt-get install -y apache2
  fi

  a2enmod headers >/dev/null 2>&1 || true
  a2enconf security >/dev/null 2>&1 || true

  linux_configure_apache_port "$port"
  linux_harden_apache
  linux_write_index "/var/www/html" "Apache2" "$version" "$port"
  linux_restrict_web_permissions "www-data" "/var/www"
  linux_configure_firewall "$port"

  systemctl enable apache2
  systemctl restart apache2

  linux_validate_service_active "apache2"
  echo "Apache2 configurado correctamente."
  linux_print_http_validation "$port"
}

linux_configure_apache_port() {
  local port="$1"

  [[ -f "$APACHE_PORTS_CONF" ]] || { echo "No existe $APACHE_PORTS_CONF"; return 1; }
  [[ -f "$APACHE_DEFAULT_SITE" ]] || { echo "No existe $APACHE_DEFAULT_SITE"; return 1; }

  cp "$APACHE_PORTS_CONF" "${APACHE_PORTS_CONF}.bak"
  cp "$APACHE_DEFAULT_SITE" "${APACHE_DEFAULT_SITE}.bak"

  sed -i '/^Listen /d' "$APACHE_PORTS_CONF"
  echo "Listen ${port}" >> "$APACHE_PORTS_CONF"

  if grep -q '<VirtualHost \*:' "$APACHE_DEFAULT_SITE"; then
    sed -i -E "s#<VirtualHost \*:[0-9]+>#<VirtualHost *:${port}>#g" "$APACHE_DEFAULT_SITE"
  else
    cat >> "$APACHE_DEFAULT_SITE" <<EOF

<VirtualHost *:${port}>
    DocumentRoot /var/www/html
</VirtualHost>
EOF
  fi

  apache2ctl configtest
}

linux_harden_apache() {
  [[ -f "$APACHE_SECURITY_CONF" ]] || touch "$APACHE_SECURITY_CONF"

  sed -i '/^\s*ServerTokens\s\+/d' "$APACHE_SECURITY_CONF"
  sed -i '/^\s*ServerSignature\s\+/d' "$APACHE_SECURITY_CONF"
  sed -i '/^\s*TraceEnable\s\+/d' "$APACHE_SECURITY_CONF"

  {
    echo "ServerTokens Prod"
    echo "ServerSignature Off"
    echo "TraceEnable Off"
  } >> "$APACHE_SECURITY_CONF"

  cat > "$APACHE_HEADERS_CONF" <<'EOF'
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
EOF

  a2enconf custom-security-headers >/dev/null 2>&1 || true
  apache2ctl configtest
}

linux_apache_flow() {
  local version
  local port

  version="$(linux_choose_version_from_apt "apache2" "Apache2")"
  port="$(linux_read_valid_port)"

  echo
  echo "Resumen:"
  echo "Servicio: Apache2"
  echo "Versión: $version"
  echo "Puerto:  $port"
  echo

  linux_confirm "¿Deseas continuar con la instalación?" || return 0
  linux_install_apache "$version" "$port"
}