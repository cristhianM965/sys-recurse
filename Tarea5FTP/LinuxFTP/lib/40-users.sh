#!/usr/bin/env bash
set -Eeuo pipefail

users::create_user() {
    local USERNAME="$1"
    local PASSWORD="$2"
    local GROUP="$3"

    id "$USERNAME" >/dev/null 2>&1 || useradd -m -s /usr/sbin/nologin "$USERNAME"

    echo "$USERNAME:$PASSWORD" | chpasswd

    usermod -aG "$COMMON_GROUP" "$USERNAME"
    usermod -aG "$GROUP" "$USERNAME"

    local USER_ROOT="$USERS_DIR/$USERNAME"
    local PERSONAL="$USER_ROOT/$USERNAME"
    local GROUP_DIR="$USER_ROOT/$GROUP"

    mkdir -p "$USER_ROOT"
    chown root:root "$USER_ROOT"
    chmod 755 "$USER_ROOT"

    core::bind_mount "$GENERAL_DIR" "$USER_ROOT/general"
    core::bind_mount "$GROUPS_DIR/$GROUP" "$GROUP_DIR"

    mkdir -p "$PERSONAL"
    chown "$USERNAME:$GROUP" "$PERSONAL"
    chmod 700 "$PERSONAL"

    core::log "Usuario configurado: $USERNAME"
}

users::wizard() {
    read -p "¿Cuántos usuarios crear? " N

    for ((i=1;i<=N;i++)); do
        echo "Usuario $i"
        read -p "Nombre: " U
        read -s -p "Contraseña: " P
        echo
        read -p "Grupo (1=reprobados,2=recursadores): " GOPT

        case "$GOPT" in
            1) G="$GROUP_A" ;;
            2) G="$GROUP_B" ;;
            *) echo "Grupo inválido"; exit 1 ;;
        esac

        users::create_user "$U" "$P" "$G"
    done
}