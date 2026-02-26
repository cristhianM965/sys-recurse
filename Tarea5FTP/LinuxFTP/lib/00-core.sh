#!/usr/bin/env bash
set -Eeuo pipefail

FTP_ROOT="/srv/ftp"
GENERAL_DIR="$FTP_ROOT/general"
GROUPS_DIR="$FTP_ROOT/groups"
USERS_DIR="$FTP_ROOT/users"
ANON_DIR="$FTP_ROOT/anon"

GROUP_A="reprobados"
GROUP_B="recursadores"
COMMON_GROUP="ftpusers"

VSFTPD_CONF="/etc/vsftpd.conf"
PASV_MIN=40000
PASV_MAX=40100

LOG_FILE="/var/log/tarea5_ftp.log"

core::log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

core::banner() {
    echo
    echo "==============================="
    echo "$1"
    echo "==============================="
    core::log "$1"
}

core::need_root() {
    [[ $EUID -eq 0 ]] || { echo "Ejecuta como root"; exit 1; }
}

core::ensure_dir() {
    mkdir -p "$1"
}

core::ensure_group() {
    getent group "$1" >/dev/null || groupadd "$1"
}

core::pkg_install() {
    dpkg -s "$1" >/dev/null 2>&1 || {
        apt update -y
        apt install -y "$1"
    }
}

core::bind_mount() {
    local SRC="$1"
    local DST="$2"

    mkdir -p "$SRC" "$DST"

    if ! mountpoint -q "$DST"; then
        echo "$SRC $DST none bind 0 0" >> /etc/fstab
        mount "$DST" || mount -a
    fi
}

core::open_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "active"; then
            ufw allow 21/tcp
            ufw allow ${PASV_MIN}:${PASV_MAX}/tcp
        fi
    fi
}