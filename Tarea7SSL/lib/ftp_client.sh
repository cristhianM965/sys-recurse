#!/usr/bin/env bash
set -Eeuo pipefail

linux_ftp_download_and_verify() {

    local servicio="$1"   # Recibe el nombre del servicio
    local FTP_SERVER="$2" # Recibe la IP que escribiste en consola
    local FTP_USER="$3"   # Recibe el usuario que escribiste
    local FTP_PASS="$4"   # Recibe la contraseña que escribiste
    
    local os_folder="Linux"
    local remote_dir="ftp://${FTP_SERVER}/${os_folder}/${servicio}/"
  
  echo "=========================================="
  echo "Iniciando cliente FTP para: $servicio"
  echo "Conectando a: $remote_dir"
  
  # Listar directorio y obtener el instalador (ignorando el .sha256)
  echo "Consultando archivos disponibles en el repositorio FTP..."
  local file_name
  file_name=$(curl -s -k --ssl-reqd -u "${FTP_USER}:${FTP_PASS}" "${remote_dir}" 
  if [[ -z "$file_name" ]]; then
    echo "ERROR: No se encontró ningún instalador en la carpeta FTP."
    return 1
  fi

  echo "Archivo detectado: $file_name"

  # Descargar binario y hash a la carpeta temporal
  echo "Descargando instalador y firma criptográfica..."
  curl -u "${FTP_USER}:${FTP_PASS}" "${remote_dir}${file_name}" -o "/tmp/${file_name}"
  curl -s -u "${FTP_USER}:${FTP_PASS}" "${remote_dir}${file_name}.sha256" -o "/tmp/${file_name}.sha256"

  # Validación de Integridad (SHA256)
  echo "Validando integridad del archivo..."
  cd /tmp
  if sha256sum -c "${file_name}.sha256"; then
    echo "¡Éxito! La integridad del archivo está verificada."
    export ARCHIVO_DESCARGADO="/tmp/${file_name}"
    return 0
  else
    echo "ERROR CRÍTICO: El hash no coincide. El archivo fue alterado o se descargó mal."
    rm -f "/tmp/${file_name}" "/tmp/${file_name}.sha256"
    return 1
  fi
}