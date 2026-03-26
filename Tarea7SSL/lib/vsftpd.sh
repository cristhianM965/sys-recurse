#!/usr/bin/env bash

# ==========================================
# Módulo de Instalación: vsftpd (Servidor FTP)
# ==========================================

linux_vsftpd_flow() {
    echo "Iniciando instalación de vsftpd desde repositorios oficiales..."
    
    apt-get update -y > /dev/null 2>&1
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y vsftpd
    
    echo "Aplicando configuración base de FTP..."
    local conf="/etc/vsftpd.conf"
    cp "$conf" "${conf}.bak"
    
    # Habilitar usuarios locales y permisos de escritura
    sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' "$conf" || true
    sed -i 's/#local_enable=YES/local_enable=YES/' "$conf" || true
    sed -i 's/#write_enable=YES/write_enable=YES/' "$conf" || true
    sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/' "$conf" || true
    
    # Parche necesario para chroot en Linux modernos
    if ! grep -q "allow_writeable_chroot=YES" "$conf"; then
        echo "allow_writeable_chroot=YES" >> "$conf"
    fi
    
    systemctl enable vsftpd
    systemctl restart vsftpd
    
    echo "Servicio vsftpd instalado y configurado."

    # ================================================================
    # NUEVO: CREACIÓN AUTOMÁTICA DE LA ESTRUCTURA DEL REPOSITORIO FTP
    # ================================================================
    echo "Construyendo estructura del repositorio FTP automatizado..."
    local ftp_home="/home/cris2204"

    # 1. Crear las carpetas de la rúbrica
    mkdir -p "$ftp_home/Linux/Apache"
    mkdir -p "$ftp_home/Linux/Nginx"
    mkdir -p "$ftp_home/Windows/Tomcat"

    # 2. Llenar la carpeta de Apache
    echo "Descargando instalador de Apache y generando Hash..."
    cd "$ftp_home/Linux/Apache"
    rm -f * # Limpiar por si hay basura
    apt-get download apache2 > /dev/null 2>&1
    for f in *.deb; do sha256sum "$f" > "$f.sha256"; done

    # 3. Llenar la carpeta de Nginx
    echo "Descargando instalador de Nginx y generando Hash..."
    cd "$ftp_home/Linux/Nginx"
    rm -f *
    apt-get download nginx > /dev/null 2>&1
    for f in *.deb; do sha256sum "$f" > "$f.sha256"; done

    # 4. Ajustar los permisos para que el usuario FTP sea el dueño
    chown -R cris2204:cris2204 "$ftp_home/Linux"
    chown -R cris2204:cris2204 "$ftp_home/Windows"

    echo "¡Repositorio FTP estructurado y surtido con éxito!"
}