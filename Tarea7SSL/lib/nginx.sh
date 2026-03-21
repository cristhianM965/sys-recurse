#!/usr/bin/env bash
set -Eeuo pipefail

linux_install_nginx() {
  local version="$1"
  local port="$2"

  echo "Instalando Nginx versión ${version}..."
  linux_run_apt_update

  export DEBIAN_FRONTEND=noninteractive
  if ! apt-get install -y "nginx=${version}"; then
    echo "No se pudo instalar exactamente la versión elegida."
    echo "Se intentará instalar la versión disponible del repositorio."
    apt-get install -y nginx
  fi

  linux_configure_nginx_port "$port"
  linux_harden_nginx
  linux_restrict_web_permissions "www-data" "/var/www"
  linux_prepare_webroot "/var/www/nginx" "www-data" "www-data"
  if [[ -f /var/www/html/index.html ]]; then
  cp -f /var/www/html/index.html /var/www/apache2/index.html
fi
chown -R www-data:www-data /var/www/apache2
chmod -R 755 /var/www/apache2
  linux_configure_firewall "$port"

  nginx -t
  systemctl enable nginx
  systemctl restart nginx

  linux_validate_service_active "nginx"
  echo "Nginx configurado correctamente."
  linux_print_http_validation "$port"
}

linux_configure_nginx_port() {
  local port="$1"

  [[ -f "$NGINX_DEFAULT_SITE" ]] || { echo "No existe $NGINX_DEFAULT_SITE"; return 1; }

  cp "$NGINX_DEFAULT_SITE" "${NGINX_DEFAULT_SITE}.bak"

  cat > "$NGINX_DEFAULT_SITE" <<EOF
server {
    listen ${port} default_server;
    listen [::]:${port} default_server;

    root /var/www/nginx;
    index index.nginx-debian.html index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

  nginx -t
}

linux_harden_nginx() {
  mkdir -p /etc/nginx/snippets

  cat > "$NGINX_SECURITY_SNIPPET" <<'EOF'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
if ($request_method ~* ^(TRACE|TRACK|DELETE)$ ) { return 405; }
EOF

  if ! grep -q 'server_tokens off;' "$NGINX_MAIN_CONF"; then
    sed -i '/http\s*{/a \    server_tokens off;' "$NGINX_MAIN_CONF"
  fi

  if ! grep -q 'include /etc/nginx/snippets/custom-security-headers.conf;' "$NGINX_DEFAULT_SITE"; then
    sed -i '/server_name _;/a \    include /etc/nginx/snippets/custom-security-headers.conf;' "$NGINX_DEFAULT_SITE"
  fi

  nginx -t
}

linux_nginx_flow() {
  local version
  local port

  version="$(linux_choose_version_from_apt "nginx" "Nginx")"
  port="$(linux_read_valid_port)"

  echo
  echo "Resumen:"
  echo "Servicio: Nginx"
  echo "Versión: $version"
  echo "Puerto:  $port"
  echo

  linux_confirm "¿Deseas continuar con la instalación?" || return 0
  linux_install_nginx "$version" "$port"
}

linux_uninstall_nginx() {
  echo "Desinstalando Nginx..."

  systemctl stop nginx 2>/dev/null || true
  systemctl disable nginx 2>/dev/null || true

  export DEBIAN_FRONTEND=noninteractive
  apt-get purge -y nginx nginx-common nginx-core 2>/dev/null || true
  apt-get autoremove -y

  rm -f "$NGINX_SECURITY_SNIPPET"

  if [[ -f "${NGINX_DEFAULT_SITE}.bak" ]]; then
    cp -f "${NGINX_DEFAULT_SITE}.bak" "$NGINX_DEFAULT_SITE" 2>/dev/null || true
  fi

  echo "Nginx desinstalado correctamente."
}