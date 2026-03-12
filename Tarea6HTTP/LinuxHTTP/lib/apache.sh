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
  linux_restrict_web_permissions "www-data" "/var/www"
  linux_prepare_webroot "/var/www/apache2" "www-data" "www-data"
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

  cat > "$APACHE_DEFAULT_SITE" <<EOF
<VirtualHost *:${port}>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/apache2

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

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

linux_uninstall_apache() {
  echo "Desinstalando Apache2..."

  systemctl stop apache2 2>/dev/null || true
  systemctl disable apache2 2>/dev/null || true

  export DEBIAN_FRONTEND=noninteractive
  apt-get purge -y apache2 apache2-bin apache2-data apache2-utils 2>/dev/null || true
  apt-get autoremove -y

  rm -f "$APACHE_HEADERS_CONF"

  if [[ -f "${APACHE_PORTS_CONF}.bak" ]]; then
    cp -f "${APACHE_PORTS_CONF}.bak" "$APACHE_PORTS_CONF" 2>/dev/null || true
  fi

  if [[ -f "${APACHE_DEFAULT_SITE}.bak" ]]; then
    cp -f "${APACHE_DEFAULT_SITE}.bak" "$APACHE_DEFAULT_SITE" 2>/dev/null || true
  fi

  echo "Apache2 desinstalado correctamente."
}