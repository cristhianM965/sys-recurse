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
  if [[ -f /var/www/html/index.html ]]; then
  cp -f /var/www/html/index.html /var/www/apache2/index.html
fi
chown -R www-data:www-data /var/www/apache2
chmod -R 755 /var/www/apache2
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
    echo "=========================================="
    echo "🌐 INICIANDO DESPLIEGUE DE APACHE"
    echo "=========================================="

    # FASE 1: Pedir y validar puertos
    local PUERTO_HTTP=$(linux_read_valid_port "HTTP" "8081")
    local PUERTO_HTTPS=$(linux_read_valid_port "HTTPS" "4443")

    # FASE 2: Origen de la instalación
    echo "------------------------------------------"
    echo "Seleccione el origen de la instalación:"
    echo "1) WEB (Repositorios Oficiales / apt)"
    echo "2) FTP Privado (Instalador local + Hash)"
    read -p "Origen (1-2): " origen

    if [[ "$origen" == "1" ]]; then
        echo ">> Modo seleccionado: WEB"
        apt-get update -y > /dev/null 2>&1
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y apache2
    elif [[ "$origen" == "2" ]]; then
        echo ">> Modo seleccionado: FTP Privado"
        read -p "Ingrese la IP o Dominio del servidor FTP: " FTP_IP
        read -p "Ingrese el usuario FTP: " FTP_USER
        read -s -p "Ingrese la contraseña FTP: " FTP_PASS
        echo ""
        
        linux_ftp_download_and_verify "Apache" "$FTP_IP" "$FTP_USER" "$FTP_PASS"
        if [ $? -ne 0 ]; then
            echo "Abortando configuración de Apache por fallo en FTP."
            return 1
        fi
    else
        echo "Opción inválida."
        return 1
    fi

    # FASE 3: Configurar Puertos y SSL (Idempotente)
    echo "=========================================="
    echo "⚙️ Configurando puertos $PUERTO_HTTP y $PUERTO_HTTPS..."
    
    # 3.1 Recrear ports.conf desde cero para evitar duplicidad o fallos de sed
    cat <<EOF > /etc/apache2/ports.conf
Listen $PUERTO_HTTP
<IfModule ssl_module>
    Listen $PUERTO_HTTPS
</IfModule>
<IfModule mod_gnutls.c>
    Listen $PUERTO_HTTPS
</IfModule>
EOF
    
    # 3.2 Modificar VirtualHost usando Regex sin importar qué puerto tenía antes
    sed -i -E "s/<VirtualHost \*:.*>/<VirtualHost \*:$PUERTO_HTTP>/" /etc/apache2/sites-available/000-default.conf
    
    # 3.3 Habilitar SSL y cambiar puerto seguro
    echo "🔒 Generando y aplicando certificado SSL autofirmado..."
    a2enmod ssl > /dev/null 2>&1
    a2ensite default-ssl > /dev/null 2>&1
    sed -i -E "s/<VirtualHost _default_:.*>/<VirtualHost _default_:$PUERTO_HTTPS>/" /etc/apache2/sites-available/default-ssl.conf

    # 3.4 Crear certificado de "Reprobados"
    mkdir -p /etc/ssl/reprobados
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/reprobados/apache.key \
        -out /etc/ssl/reprobados/apache.crt \
        -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=Reprobados/CN=www.reprobados.com" 2>/dev/null

    # 3.5 Inyectar certificado
    sed -i "s|SSLCertificateFile.*|SSLCertificateFile /etc/ssl/reprobados/apache.crt|" /etc/apache2/sites-available/default-ssl.conf
    sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/ssl/reprobados/apache.key|" /etc/apache2/sites-available/default-ssl.conf

    # Reinicio final
    systemctl restart apache2
    
    echo "✅ ¡Apache desplegado con éxito!"
    echo "🌍 HTTP  disponible en: http://localhost:$PUERTO_HTTP"
    echo "🔒 HTTPS disponible en: https://localhost:$PUERTO_HTTPS"
    echo "=========================================="
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