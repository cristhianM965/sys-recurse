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
    local port
    # Mostramos el prompt hacia stderr para que no se mezcle con la captura de la variable
    read -p "Ingrese el puerto HTTP (ej. 80): " port >&2
    # Si el usuario da Enter vacío, usamos el 80 por defecto
    echo "${port:-80}"
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