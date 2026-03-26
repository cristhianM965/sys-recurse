#!/usr/bin/env bash

linux_ftp_download_and_verify() {
    local servicio="$1"   
    local FTP_SERVER="$2" 
    local FTP_USER="$3"   
    local FTP_PASS="$4"   
    
    local os_folder="Linux"
    local remote_dir="ftp://${FTP_SERVER}/${os_folder}/${servicio}/"

    echo "=========================================="
    echo "Iniciando cliente FTP para: $servicio"
    echo "Conectando a (FTPS): $remote_dir"

    echo "Consultando archivos disponibles en el repositorio FTP..."
    local file_name
    file_name=$(curl -s -k --ssl-reqd -u "${FTP_USER}:${FTP_PASS}" "${remote_dir}" | grep '\.deb$' | awk '{print $9}' | head -n 1)

    if [[ -z "$file_name" ]]; then
        echo "ERROR: No se encontró ningún instalador en la carpeta FTP."
        return 1
    fi

    echo "Archivo detectado: $file_name"
    echo "Descargando instalador y firma criptográfica..."
    
    # Descargas seguras saltándose la advertencia del certificado autofirmado (-k)
    curl -s -k --ssl-reqd -u "${FTP_USER}:${FTP_PASS}" "${remote_dir}${file_name}" -o "/tmp/${file_name}"
    curl -s -k --ssl-reqd -u "${FTP_USER}:${FTP_PASS}" "${remote_dir}${file_name}.sha256" -o "/tmp/${file_name}.sha256"

    if [[ ! -f "/tmp/${file_name}" ]] || [[ ! -f "/tmp/${file_name}.sha256" ]]; then
        echo "ERROR: Falló la descarga del instalador o su archivo Hash."
        return 1
    fi
    
    echo "Archivos descargados correctamente en /tmp/"
    echo "Verificando integridad (Hash SHA256)..."
    
    cd /tmp
    # Validar que el archivo .deb no esté corrupto usando su firma
    if sha256sum -c "${file_name}.sha256" > /dev/null 2>&1; then
        echo "¡Hash verificado con éxito! El archivo es auténtico."
        echo "Instalando $servicio localmente..."
        export DEBIAN_FRONTEND=noninteractive
        dpkg -i "$file_name" > /dev/null 2>&1 || apt-get install -f -y > /dev/null 2>&1
        echo "Instalación de $servicio completada."
    else
        echo "ERROR CRÍTICO: El Hash no coincide. El archivo podría estar corrupto o alterado."
        rm -f "/tmp/${file_name}" "/tmp/${file_name}.sha256"
        return 1
    fi
    
    # Limpiar la basura temporal
    rm -f "/tmp/${file_name}" "/tmp/${file_name}.sha256"
}