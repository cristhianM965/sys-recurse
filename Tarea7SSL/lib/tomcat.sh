#!/usr/bin/env bash
set -Eeuo pipefail

linux_choose_tomcat_version() {
  local versions=(
    "10.1.39"
    "10.1.38"
    "9.0.102"
    "9.0.100"
  )
  local option
  local i

  echo > /dev/tty
  echo "Versiones disponibles para Tomcat:" > /dev/tty

  i=1
  for v in "${versions[@]}"; do
    echo "  [$i] $v" > /dev/tty
    ((i++))
  done
  echo > /dev/tty

  while true; do
    read -r -p "Elige una versión: " option < /dev/tty
    if [[ "$option" =~ ^[0-9]+$ ]] && (( option >= 1 && option <= ${#versions[@]} )); then
      printf '%s\n' "${versions[$((option-1))]}"
      return 0
    fi
    echo "Opción inválida." > /dev/tty
  done
}

linux_install_tomcat() {
  local version="$1"
  local port="$2"

  echo "Instalando Tomcat versión ${version}..."

  linux_run_apt_update
  apt-get install -y default-jdk curl tar

  linux_create_tomcat_user
  linux_prepare_tomcat_dirs
  linux_download_and_extract_tomcat "$version"
  linux_configure_tomcat_port "$port"
  linux_harden_tomcat
  linux_create_tomcat_systemd
  linux_restrict_web_permissions "$TOMCAT_USER" "${TOMCAT_BASE_DIR}/webapps"
  linux_configure_firewall "$port"

  systemctl daemon-reload
  systemctl enable "$TOMCAT_SERVICE_NAME"
  systemctl restart "$TOMCAT_SERVICE_NAME"

  linux_validate_service_active "$TOMCAT_SERVICE_NAME"
  echo "Tomcat configurado correctamente."
  linux_print_http_validation "$port"
}

linux_create_tomcat_user() {
  if ! getent group "$TOMCAT_GROUP" >/dev/null 2>&1; then
    groupadd --system "$TOMCAT_GROUP"
  fi

  if ! id "$TOMCAT_USER" >/dev/null 2>&1; then
    useradd --system --home "$TOMCAT_BASE_DIR" --shell /usr/sbin/nologin --gid "$TOMCAT_GROUP" "$TOMCAT_USER"
  fi
}

linux_prepare_tomcat_dirs() {
  mkdir -p "$TOMCAT_BASE_DIR"
  chown -R "${TOMCAT_USER}:${TOMCAT_GROUP}" "$TOMCAT_BASE_DIR"
  chmod 750 "$TOMCAT_BASE_DIR"
}
linux_download_and_extract_tomcat() {
  local version="$1"
  local temp_file="/tmp/apache-tomcat.tar.gz"
  local major_version
  local download_url
  local extracted_dir

  major_version="$(echo "$version" | cut -d'.' -f1)"

  if [[ -z "$major_version" ]]; then
    echo "No se pudo determinar la versión mayor de Tomcat."
    return 1
  fi

  download_url="https://archive.apache.org/dist/tomcat/tomcat-${major_version}/v${version}/bin/apache-tomcat-${version}.tar.gz"

  echo "Descargando Tomcat desde:"
  echo "$download_url"

  rm -f "$temp_file"
  rm -rf /tmp/apache-tomcat-*

  if ! curl -fL --retry 3 --connect-timeout 20 "$download_url" -o "$temp_file"; then
    echo "No se pudo descargar Tomcat versión ${version}."
    return 1
  fi

  [[ -s "$temp_file" ]] || {
    echo "El archivo descargado está vacío."
    return 1
  }

  rm -rf "${TOMCAT_BASE_DIR:?}/"*
  tar -xzf "$temp_file" -C /tmp

  extracted_dir="/tmp/apache-tomcat-${version}"
  [[ -d "$extracted_dir" ]] || {
    echo "No se encontró el directorio extraído de Tomcat."
    return 1
  }

  mkdir -p "$TOMCAT_BASE_DIR"
  cp -a "${extracted_dir}/." "$TOMCAT_BASE_DIR/"
  chown -R "${TOMCAT_USER}:${TOMCAT_GROUP}" "$TOMCAT_BASE_DIR"
  chmod -R 750 "$TOMCAT_BASE_DIR"

  rm -rf "$extracted_dir" "$temp_file"
}

linux_configure_tomcat_port() {
  local port="$1"
  local server_xml="${TOMCAT_BASE_DIR}/conf/server.xml"

  [[ -f "$server_xml" ]] || { echo "No existe $server_xml"; return 1; }

  cp "$server_xml" "${server_xml}.bak"
  sed -i -E 's/Connector port="8080"/Connector port="'"$port"'"/g' "$server_xml"
}

linux_harden_tomcat() {
  local server_xml="${TOMCAT_BASE_DIR}/conf/server.xml"
  local web_xml="${TOMCAT_BASE_DIR}/conf/web.xml"

  [[ -f "$server_xml" ]] || { echo "No existe $server_xml"; return 1; }
  [[ -f "$web_xml" ]] || { echo "No existe $web_xml"; return 1; }

  if ! grep -q 'server="SecureServer"' "$server_xml"; then
    sed -i -E 's#<Connector port="([0-9]+)" protocol="HTTP/1.1"#<Connector port="\1" protocol="HTTP/1.1" server="SecureServer"#g' "$server_xml"
  fi

  if ! grep -q 'httpHeaderSecurity' "$web_xml"; then
    sed -i '/<\/web-app>/i \
<filter>\n\
  <filter-name>httpHeaderSecurity</filter-name>\n\
  <filter-class>org.apache.catalina.filters.HttpHeaderSecurityFilter</filter-class>\n\
  <async-supported>true</async-supported>\n\
  <init-param>\n\
    <param-name>antiClickJackingOption</param-name>\n\
    <param-value>SAMEORIGIN</param-value>\n\
  </init-param>\n\
  <init-param>\n\
    <param-name>blockContentTypeSniffingEnabled</param-name>\n\
    <param-value>true</param-value>\n\
  </init-param>\n\
</filter>\n\
<filter-mapping>\n\
  <filter-name>httpHeaderSecurity</filter-name>\n\
  <url-pattern>/*</url-pattern>\n\
</filter-mapping>' "$web_xml"
  fi
}

linux_create_tomcat_systemd() {
  cat > "$TOMCAT_SYSTEMD_FILE" <<EOF
[Unit]
Description=Apache Tomcat Custom
After=network.target

[Service]
Type=forking
User=${TOMCAT_USER}
Group=${TOMCAT_GROUP}
Environment=JAVA_HOME=/usr/lib/jvm/default-java
Environment=CATALINA_PID=${TOMCAT_BASE_DIR}/temp/tomcat.pid
Environment=CATALINA_HOME=${TOMCAT_BASE_DIR}
Environment=CATALINA_BASE=${TOMCAT_BASE_DIR}
ExecStart=${TOMCAT_BASE_DIR}/bin/startup.sh
ExecStop=${TOMCAT_BASE_DIR}/bin/shutdown.sh
UMask=0027
RestartSec=10
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

linux_tomcat_flow() {
  local version
  local port

  version="$(linux_choose_tomcat_version)"
  port="$(linux_read_valid_port)"

  echo
  echo "Resumen:"
  echo "Servicio: Tomcat"
  echo "Versión: $version"
  echo "Puerto:  $port"
  echo

  linux_confirm "¿Deseas continuar con la instalación?" || return 0
  linux_install_tomcat "$version" "$port"
}

linux_uninstall_tomcat() {
  echo "Desinstalando Tomcat..."

  systemctl stop "$TOMCAT_SERVICE_NAME" 2>/dev/null || true
  systemctl disable "$TOMCAT_SERVICE_NAME" 2>/dev/null || true

  rm -f "$TOMCAT_SYSTEMD_FILE"
  systemctl daemon-reload

  rm -rf "$TOMCAT_BASE_DIR"

  if id "$TOMCAT_USER" >/dev/null 2>&1; then
    userdel -r "$TOMCAT_USER" 2>/dev/null || true
  fi

  if getent group "$TOMCAT_GROUP" >/dev/null 2>&1; then
    groupdel "$TOMCAT_GROUP" 2>/dev/null || true
  fi

  echo "Tomcat desinstalado correctamente."
}