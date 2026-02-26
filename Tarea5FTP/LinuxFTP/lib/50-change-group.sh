#!/usr/bin/env bash
set -Eeuo pipefail

changegroup::apply() {
    read -p "Usuario a modificar: " U
    read -p "Nuevo grupo (1=reprobados,2=recursadores): " OPT

    case "$OPT" in
        1) G="$GROUP_A" ;;
        2) G="$GROUP_B" ;;
        *) echo "Grupo inválido"; exit 1 ;;
    esac

    usermod -aG "$G" "$U"
    core::log "Grupo actualizado: $U -> $G"
}