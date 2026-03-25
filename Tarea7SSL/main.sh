#!/usr/bin/env bash


# ==========================================
# TAREA 07: Orquestador Híbrido Linux
# ==========================================

# 1. Importar librerías
source ./lib/nginx.sh
source ./lib/apache.sh
source ./lib/tomcat.sh
source ./lib/ftp_client.sh
source ./lib/ssl_security.sh
source ./lib/vsftpd.sh 
source ./lib/utils.sh

echo "=========================================="
echo "   Despliegue de Infraestructura Segura   "
echo "=========================================="
echo "Seleccione el servicio a instalar:"
echo "1) Apache"
echo "2) Nginx"
echo "3) Tomcat"
echo "4) vsftpd"
read -p "Opción (1-4): " servicio_opcion

case $servicio_opcion in
    1) SERVICIO="Apache" ;;
    2) SERVICIO="Nginx" ;;
    3) SERVICIO="Tomcat" ;;
    4) SERVICIO="vsftpd" ;;
    *) echo "Opción no válida."; exit 1 ;;
esac

echo "------------------------------------------"
echo "Seleccione el origen de la instalación:"
echo "1) WEB (Repositorios Oficiales / apt)"
echo "2) FTP Privado (Instalador local + Hash)"
read -p "Origen (1-2): " origen_opcion

echo "------------------------------------------"
echo "Iniciando despliegue de $SERVICIO..."

# ==========================================
# LÓGICA DE INSTALACIÓN (WEB vs FTP)
# ==========================================

if [ "$origen_opcion" -eq 1 ]; then
    echo ">> Modo seleccionado: WEB (Repositorio Oficial)"
    
    if [ "$SERVICIO" == "Nginx" ]; then
        # linux_nginx_flow
        echo "Saltando instalacion de Nginx, yendo a seguridad..."
    elif [ "$SERVICIO" == "Apache" ]; then
        # linux_apache_flow
        echo "Llamando a flujo de Apache..."
    elif [ "$SERVICIO" == "Tomcat" ]; then
        # linux_tomcat_flow
        echo "Llamando a flujo de Tomcat..."
    elif [ "$SERVICIO" == "vsftpd" ]; then
        linux_vsftpd_flow
    fi

elif [ "$origen_opcion" -eq 2 ]; then
    echo ">> Modo seleccionado: FTP Privado"
    
    # Pedir credenciales dinámicamente al usuario
    read -p "Ingrese la IP o Dominio del servidor FTP: " input_ftp_ip
    read -p "Ingrese el usuario FTP: " input_ftp_user
    read -s -p "Ingrese la contraseña FTP: " input_ftp_pass
    echo "" # Salto de línea limpio tras ingresar la contraseña oculta
    
    # Llamamos a la función y pasamos los datos como parámetros
    if linux_ftp_download_and_verify "$SERVICIO" "$input_ftp_ip" "$input_ftp_user" "$input_ftp_pass"; then
        echo "------------------------------------------"
        echo "Instalando paquete verificado: $ARCHIVO_DESCARGADO"
        
        # Instalación dinámica dependiendo del tipo de archivo
        if [[ "$ARCHIVO_DESCARGADO" == *.deb ]]; then
            export DEBIAN_FRONTEND=noninteractive
            dpkg -i "$ARCHIVO_DESCARGADO"
            apt-get install -f -y # Resuelve dependencias faltantes
        elif [[ "$ARCHIVO_DESCARGADO" == *.tar.gz && "$SERVICIO" == "Tomcat" ]]; then
            mkdir -p /opt/tomcat
            tar -xzf "$ARCHIVO_DESCARGADO" -C /opt/tomcat --strip-components=1
            echo "Tomcat extraído en /opt/tomcat"
        else
            echo "Formato de archivo no soportado para autoinstalación."
            exit 1
        fi
        
        echo "$SERVICIO instalado correctamente desde el repositorio FTP."
    else
        echo "Instalación abortada por fallos de integridad."
        exit 1
    fi
else
    echo "Origen no válido. Abortando."
    exit 1
fi

# ==========================================
# LÓGICA DE SEGURIDAD SSL (Se ejecutará al final)
# ==========================================
linux_ssl_flow "$SERVICIO"

echo "=========================================="
echo "   Despliegue finalizado con éxito.       "
echo "=========================================="