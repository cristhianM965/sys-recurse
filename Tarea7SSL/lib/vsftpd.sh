#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# Módulo de Descarga FTP y Hash SHA256
# ==========================================

linux_ftp_download_and_verify() {
  local servicio="$1" 
  local ftp_ip="$2"
  local ftp_user="$3"
  local ftp_pass="$4"
  
  local os_folder="Linux"
  local remote_dir="ftp://${ftp_ip}/${os_folder}/${servicio}/"
  
  echo "=========================================="
  echo "Conectando al Repositorio FTP Privado..."
  echo "Ruta: $remote_dir"
  
  # 1. Obtener nombre del instalador
  local file_name
  file_name=$(curl -s -u "${ftp_user}:${ftp_pass}" "${remote_dir}" | awk '{print $9}' | grep -v '\.sha256$' | head -n 1)

  if [[ -z "$file_name" ]]; then
    echo "ERROR: No se encontró ningún instalador en la carpeta FTP de $servicio."
    return 1
  fi

  echo "Binario detectado: $file_name"

  # 2. Descargar instalador y .sha256
  echo "Descargando instalador y firma criptográfica..."
  curl -u "${ftp_user}:${ftp_pass}" "${remote_dir}${file_name}" -o "/tmp/${file_name}"
  curl -s -u "${ftp_user}:${ftp_pass}" "${remote_dir}${file_name}.sha256" -o "/tmp/${file_name}.sha256"

  # 3. Validación de Integridad
  echo "Validando integridad (SHA256)..."
  cd /tmp
  if sha256sum -c "${file_name}.sha256"; then
    echo "¡Éxito! Integridad del archivo verificada."
    export ARCHIVO_DESCARGADO="/tmp/${file_name}"
    return 0
  else
    echo "ERROR CRÍTICO: El hash no coincide. El archivo está corrupto."
    rm -f "/tmp/${file_name}" "/tmp/${file_name}.sha256"
    return 1
  fi
}