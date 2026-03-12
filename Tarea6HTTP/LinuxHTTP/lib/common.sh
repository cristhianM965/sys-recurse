#!/usr/bin/env bash
set -Eeuo pipefail

readonly APACHE_PORTS_CONF="/etc/apache2/ports.conf"
readonly APACHE_DEFAULT_SITE="/etc/apache2/sites-available/000-default.conf"
readonly APACHE_SECURITY_CONF="/etc/apache2/conf-available/security.conf"
readonly APACHE_HEADERS_CONF="/etc/apache2/conf-available/custom-security-headers.conf"

readonly NGINX_MAIN_CONF="/etc/nginx/nginx.conf"
readonly NGINX_DEFAULT_SITE="/etc/nginx/sites-available/default"
readonly NGINX_SECURITY_SNIPPET="/etc/nginx/snippets/custom-security-headers.conf"

readonly TOMCAT_SERVICE_NAME="tomcat-custom"
readonly TOMCAT_BASE_DIR="/opt/tomcat"
readonly TOMCAT_USER="tomcat"
readonly TOMCAT_GROUP="tomcat"
readonly TOMCAT_SYSTEMD_FILE="/etc/systemd/system/${TOMCAT_SERVICE_NAME}.service"

readonly RESERVED_PORTS_REGEX='^(20|21|22|23|25|53|67|68|69|110|111|123|135|137|138|139|143|161|162|389|443|445|465|514|587|631|993|995|1433|1521|2049|2375|2376|3306|3389|5432|5900|6379|8086|9200|27017)$'

linux_error_trap() {
  local exit_code=$?
  local line_no="${1:-desconocida}"
  echo
  echo "======================================================"
  echo "ERROR: Falló la ejecución en la línea ${line_no}."
  echo "Código de salida: ${exit_code}"
  echo "======================================================"
  exit "$exit_code"
}
trap 'linux_error_trap ${LINENO}' ERR

linux_require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Este script debe ejecutarse como root."
    exit 1
  fi
}

linux_check_dependencies() {
  local deps=(
    apt-get apt-cache awk sed grep ss systemctl curl tar
    cut tr head sort uniq find mkdir chmod chown cp mv tee
  )

  local missing=()
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Faltan dependencias del sistema:"
    printf ' - %s\n' "${missing[@]}"
    exit 1
  fi
}

linux_pause() {
  read -r -p "Presiona Enter para continuar..." _
}

linux_print_header() {
  clear
  echo "======================================================"
  echo " TAREA 6 - DESPLIEGUE DINÁMICO HTTP MULTI-VERSIÓN"
  echo " Linux: Apache2 | Nginx | Tomcat"
  echo "======================================================"
  echo
}

linux_confirm() {
  local prompt="$1"
  local answer
  while true; do
    read -r -p "$prompt [s/n]: " answer
    case "${answer,,}" in
      s|si|sí) return 0 ;;
      n|no) return 1 ;;
      *) echo "Respuesta inválida. Usa s o n." ;;
    esac
  done
}

linux_is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

linux_is_port_in_use() {
  local port="$1"
  ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$port$"
}

linux_read_valid_port() {
  local port
  while true; do
    read -r -p "Ingresa el puerto de escucha: " port

    if [[ -z "${port// }" ]]; then
      echo "El puerto no puede estar vacío."
      continue
    fi

    if ! linux_is_integer "$port"; then
      echo "El puerto debe ser numérico."
      continue
    fi

    if (( port < 1024 || port > 65535 )); then
      echo "El puerto debe estar entre 1024 y 65535."
      continue
    fi

    if [[ "$port" =~ $RESERVED_PORTS_REGEX ]]; then
      echo "Ese puerto está reservado para otros servicios. Elige otro."
      continue
    fi

    if linux_is_port_in_use "$port"; then
      echo "El puerto $port ya está en uso."
      continue
    fi

    echo "$port"
    return 0
  done
}

linux_safe_input_number() {
  local prompt="$1"
  local max="$2"
  local opt
  while true; do
    read -r -p "$prompt" opt
    if [[ "$opt" =~ ^[0-9]+$ ]] && (( opt >= 1 && opt <= max )); then
      echo "$opt"
      return 0
    fi
    echo "Opción inválida."
  done
}

linux_run_apt_update() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
}

linux_validate_service_active() {
  local service="$1"
  if ! systemctl is-active --quiet "$service"; then
    echo "El servicio $service no quedó activo."
    return 1
  fi
  return 0
}

linux_write_index() {
  local target_dir="$1"
  local service_name="$2"
  local version="$3"
  local port="$4"

  mkdir -p "$target_dir"
  cat > "${target_dir}/index.html" <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>${service_name}</title>
</head>
<body>
  <h1>Servidor: ${service_name} - Versión: ${version} - Puerto: ${port}</h1>
</body>
</html>
EOF
}

linux_configure_firewall() {
  local port="$1"

  if command -v ufw >/dev/null 2>&1; then
    ufw allow "${port}/tcp" >/dev/null 2>&1 || true

    for p in 80 8080; do
      if [[ "$p" != "$port" ]]; then
        ufw delete allow "${p}/tcp" >/dev/null 2>&1 || true
      fi
    done
  fi
}

linux_print_http_validation() {
  local port="$1"
  echo
  echo "Validación sugerida:"
  echo "curl -I http://localhost:${port}"
  echo
  curl -I --max-time 10 "http://localhost:${port}" || true
  echo
}

linux_get_apt_versions() {
  local package_name="$1"
  apt-cache madison "$package_name" 2>/dev/null | awk '{print $3}' | awk '!seen[$0]++'
}

linux_choose_version_from_apt() {
  local package_name="$1"
  local service_name="$2"

  mapfile -t versions < <(linux_get_apt_versions "$package_name")

  if [[ ${#versions[@]} -eq 0 ]]; then
    echo "No se encontraron versiones para ${service_name} en el repositorio." >&2
    return 1
  fi

  echo >&2
  echo "Versiones disponibles para ${service_name}:" >&2

  local i=1
  for v in "${versions[@]}"; do
    echo "  [$i] $v" >&2
    ((i++))
  done
  echo >&2

  local option
  option="$(linux_safe_input_number "Elige una versión: " "${#versions[@]}")"

  printf '%s\n' "${versions[$((option-1))]}"
}

linux_restrict_web_permissions() {
  local service_user="$1"
  local target_dir="$2"

  [[ -d "$target_dir" ]] || { echo "No existe el directorio $target_dir"; return 1; }

  chown -R "${service_user}:${service_user}" "$target_dir" 2>/dev/null || chown -R "${service_user}:www-data" "$target_dir" 2>/dev/null || true
  chmod -R 750 "$target_dir"
}