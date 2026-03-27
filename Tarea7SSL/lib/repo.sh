#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ftp_list() {
  local remote_path="$1"

  log "Listando contenido FTP: $remote_path"

  curl -fsS --user "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST$remote_path/" --list-only \
    | sed '/^\s*$/d' \
    || die "No se pudo listar la ruta FTP: $remote_path"
}

ftp_path_exists() {
  local remote_path="$1"

  if curl -fsS --user "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST$remote_path/" --list-only >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

ftp_select_service() {
  local base_path="${1:-$FTP_BASE}"

  mapfile -t services < <(ftp_list "$base_path")

  [[ ${#services[@]} -gt 0 ]] || die "No se encontraron servicios en el FTP: $base_path"

  select_option "Servicios disponibles en FTP:" "${services[@]}"
}

ftp_list_installers() {
  local service="$1"
  local remote_dir="$FTP_BASE/$service"

  log "Buscando instaladores en $remote_dir"

  ftp_list "$remote_dir" | grep -E "$VALID_PACKAGE_REGEX" || true
}

ftp_select_installer() {
  local service="$1"

  mapfile -t files < <(ftp_list_installers "$service" | sed '/^\s*$/d')

  [[ ${#files[@]} -gt 0 ]] || die "No se encontraron instaladores válidos para $service en el FTP."

  select_option "Versiones disponibles para $service:" "${files[@]}"
}

ftp_download_file() {
  local remote_file="$1"
  local local_file="$2"

  log "Descargando desde FTP: $remote_file -> $local_file"

  curl -fsS --user "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST$remote_file" -o "$local_file" \
    || die "No se pudo descargar el archivo: $remote_file"
}

ftp_download_with_hash() {
  local service="$1"
  local installer="$2"

  local remote_installer="$FTP_BASE/$service/$installer"
  local remote_hash="$FTP_BASE/$service/$installer$HASH_EXTENSION"

  local local_installer="$DOWNLOAD_DIR/$installer"
  local local_hash="$DOWNLOAD_DIR/$installer$HASH_EXTENSION"

  ftp_download_file "$remote_installer" "$local_installer"
  ftp_download_file "$remote_hash" "$local_hash"

  validate_sha256 "$local_installer" "$local_hash"

  echo "$local_installer"
}

validate_sha256() {
  local local_file="$1"
  local hash_file="$2"

  [[ -f "$local_file" ]] || die "No existe el archivo descargado: $local_file"
  [[ -f "$hash_file" ]] || die "No existe el archivo hash: $hash_file"

  log "Validando integridad SHA256 de $(basename "$local_file")"

  local expected_hash
  local actual_hash

  expected_hash="$(awk '{print $1}' "$hash_file" | head -n1)"
  actual_hash="$(sha256sum "$local_file" | awk '{print $1}')"

  [[ -n "$expected_hash" ]] || die "El archivo hash está vacío o es inválido: $hash_file"
  [[ -n "$actual_hash" ]] || die "No se pudo calcular el hash local de: $local_file"

  if [[ "$expected_hash" != "$actual_hash" ]]; then
    rm -f "$local_file"
    die "La integridad del archivo falló. Hash esperado: $expected_hash | Hash real: $actual_hash"
  fi

  log "Integridad verificada correctamente para $(basename "$local_file")"
}

show_ftp_repo_tree_hint() {
  cat <<EOF

Estructura esperada del FTP:

/http
└── Linux
    ├── Apache
    │   ├── archivo.deb
    │   └── archivo.deb.sha256
    ├── Nginx
    │   ├── archivo.deb
    │   └── archivo.deb.sha256
    ├── Tomcat
    │   ├── archivo.tar.gz
    │   └── archivo.tar.gz.sha256
    └── vsftpd
        ├── archivo.deb
        └── archivo.deb.sha256

EOF
}

ftp_debug_connection() {
  log "Probando conexión básica al FTP $FTP_HOST"

  curl -v --user "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/" --list-only >/dev/null 2>&1 \
    && log "Conexión FTP exitosa." \
    || die "No se pudo establecer conexión con el FTP."
}