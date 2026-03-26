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
    
    echo "Servicio vsftpd instalado."
}