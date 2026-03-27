#!/usr/bin/env bash

linux_run_apt_update() {
    echo "Actualizando repositorios..."
    apt-get update -y >/dev/null 2>&1 || true
}

linux_choose_version_from_apt() {
    # Simplificamos devolviendo el nombre del paquete base para que instale el de por defecto
    echo "$1"
}

linux_read_valid_port() {
    local protocolo="$1"
    local puerto_default="$2"
    local input_port
    local puerto_final

    while true; do
        read -p "Ingrese el puerto $protocolo a usar (Ej. $puerto_default): " input_port >&2
        puerto_final=${input_port:-$puerto_default}

        # La etiqueta \b asegura que busque exactamente el puerto (80 no coincidirá con 8080)
        if ss -tuln | grep -E -q ":$puerto_final\b"; then
            echo "⚠️ ERROR: El puerto $puerto_final ya está ocupado en el sistema." >&2
        else
            echo "✅ Puerto $protocolo ($puerto_final) disponible y reservado." >&2
            echo "$puerto_final"
            break
        fi
    done
}

linux_confirm() {
    local msg="$1"
    local response
    read -p "$msg [S/n]: " response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        return 1 # Falso (Abortar)
    fi
    return 0 # Verdadero (Continuar)
}

linux_configure_firewall() {
    local port="$1"
    echo "Configurando firewall para el puerto $port..."
    ufw allow "$port/tcp" >/dev/null 2>&1 || true
}

linux_restrict_web_permissions() {
    local user="$1"
    local dir="$2"
    mkdir -p "$dir"
    chown -R "$user:$user" "$dir" 2>/dev/null || true
}

linux_prepare_webroot() {
    local dir="$1"
    local user="$2"
    local group="$3"
    mkdir -p "$dir"
    chown -R "$user:$group" "$dir" 2>/dev/null || true
    chmod -R 755 "$dir" 2>/dev/null || true
}

linux_validate_service_active() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "Servicio $service está ACTIVO."
    else
        echo "Advertencia: El servicio $service no arrancó correctamente."
    fi
}

linux_print_http_validation() {
    local port="$1"
    echo "Puede validar el servicio usando: curl -I http://localhost:$port"
}

menu_desinstalar() {
    echo "=========================================="
    echo "🧹 MENÚ DE DESINSTALACIÓN SELECTIVA"
    echo "=========================================="
    echo "1) Apache"
    echo "2) Nginx"
    echo "3) Tomcat"
    echo "4) vsftpd"
    echo "5) TODOS los servicios"
    echo "6) Cancelar"
    read -p "Seleccione qué desea desinstalar (1-6): " opt_del

    export DEBIAN_FRONTEND=noninteractive
    case $opt_del in
        1)
            sudo systemctl stop apache2 2>/dev/null || true
            sudo apt-get purge -y apache2* >/dev/null 2>&1
            sudo rm -rf /etc/apache2
            echo "✅ Apache desinstalado correctamente."
            ;;
        2)
            sudo systemctl stop nginx 2>/dev/null || true
            sudo apt-get purge -y nginx* >/dev/null 2>&1
            sudo rm -rf /etc/nginx
            echo "✅ Nginx desinstalado correctamente."
            ;;
        3)
            sudo systemctl stop tomcat9 2>/dev/null || true
            sudo apt-get purge -y tomcat9* >/dev/null 2>&1
            sudo rm -rf /var/lib/tomcat9 /etc/tomcat9
            echo "✅ Tomcat desinstalado correctamente."
            ;;
        4)
            sudo systemctl stop vsftpd 2>/dev/null || true
            sudo apt-get purge -y vsftpd* >/dev/null 2>&1
            sudo rm -rf /etc/vsftpd.conf*
            echo "✅ vsftpd desinstalado correctamente."
            ;;
        5)
            sudo systemctl stop apache2 nginx tomcat9 vsftpd 2>/dev/null || true
            sudo apt-get purge -y apache2* nginx* tomcat9* vsftpd* >/dev/null 2>&1
            sudo rm -rf /etc/apache2 /etc/nginx /var/lib/tomcat9 /etc/tomcat9 /etc/vsftpd.conf* /etc/ssl/reprobados*
            echo "✅ Todos los servicios han sido desinstalados."
            ;;
        6) 
            echo "Operación cancelada."
            return 0 
            ;;
        *) 
            echo "Opción inválida." 
            ;;
    esac
    sudo apt-get autoremove -y >/dev/null 2>&1
}