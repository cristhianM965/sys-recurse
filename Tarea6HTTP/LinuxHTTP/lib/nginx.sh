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

  sed -i -E "s/listen 80 default_server;/listen ${port} default_server;/g" "$NGINX_DEFAULT_SITE"
  sed -i -E "s/listen \[::\]:80 default_server;/listen [::]:${port} default_server;/g" "$NGINX_DEFAULT_SITE"
  sed -i -E "s/listen 80;/listen ${port};/g" "$NGINX_DEFAULT_SITE"
  sed -i -E "s/listen \[::\]:80;/listen [::]:${port};/g" "$NGINX_DEFAULT_SITE"

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