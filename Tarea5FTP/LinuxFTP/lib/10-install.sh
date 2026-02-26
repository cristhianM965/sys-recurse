#!/usr/bin/env bash
set -Eeuo pipefail

install::vsftpd() {
    core::banner "Instalando vsftpd"
    core::pkg_install vsftpd
    systemctl enable --now vsftpd
}