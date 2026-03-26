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
    local protocolo="$1"      # Ej: HTTP, HTTPS, Tomcat
    local puerto_default="$2" # Ej: 80, 443, 8080
    local input_port
    local puerto_final

    while true; do
        # 1. Mostramos el prompt hacia stderr (>&2)
        read -p "Ingrese el puerto $protocolo a usar (Ej. $puerto_default): " input_port >&2
        
        # 2. Si da Enter vacío, usamos el default
        puerto_final=${input_port:-$puerto_default}

        # 3. Validar si el puerto ya está en uso en el sistema
        # Usamos grep -qw para buscar la coincidencia exacta del puerto
        if ss -tuln | grep -qw ":$puerto_final"; then
            echo "⚠️  ERROR: El puerto $puerto_final ya está ocupado por otro servicio. Por favor, elige otro." >&2
        else
            echo "✅ Puerto $protocolo ($puerto_final) disponible y reservado." >&2
            
            # 4. Imprimimos el puerto final a stdout para que la variable lo capture
            echo "$puerto_final"
            break # Salimos del bucle
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

desinstalar_todo() {
    echo "=========================================="
    echo "🧹 INICIANDO PROTOCOLO DE LIMPIEZA TOTAL..."
    echo "=========================================="
    
    # 1. Detener servicios si están corriendo
    systemctl stop apache2 nginx tomcat9 vsftpd > /dev/null 2>&1
    
    # 2. Purgar paquetes (Elimina el software y configuraciones base)
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y apache2* nginx* tomcat* vsftpd* > /dev/null 2>&1
    apt-get autoremove -y > /dev/null 2>&1
    
    # 3. Eliminar carpetas residuales
    rm -rf /etc/apache2 /etc/nginx /var/lib/tomcat* /etc/vsftpd* /etc/ssl/reprobados* /tmp/*.deb /tmp/*.sha256
    
    echo "✅ Sistema limpio. Puertos liberados. ¡Listo para una instalación fresca!"
    echo "=========================================="
}