#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$DIR/lib/00-core.sh"
source "$DIR/lib/10-install.sh"
source "$DIR/lib/20-structure.sh"
source "$DIR/lib/30-config.sh"
source "$DIR/lib/40-users.sh"
source "$DIR/lib/50-change-group.sh"

core::need_root
core::banner "TAREA 5 - FTP LINUX (vsftpd)"

install::vsftpd
structure::create_base
structure::anon_bind
config::apply_vsftpd

users::wizard

core::banner "Configuración finalizada correctamente"