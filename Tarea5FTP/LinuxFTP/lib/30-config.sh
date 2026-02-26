#!/usr/bin/env bash
set -Eeuo pipefail

config::apply_vsftpd() {
    core::banner "Configurando vsftpd"

    cp "$VSFTPD_CONF" "${VSFTPD_CONF}.bak" 2>/dev/null || true

    cat > "$VSFTPD_CONF" <<EOF
listen=YES
listen_ipv6=NO

anonymous_enable=YES
local_enable=YES
write_enable=YES

anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO

chroot_local_user=YES
allow_writeable_chroot=YES

user_sub_token=\$USER
local_root=$USERS_DIR/\$USER

anon_root=$ANON_DIR

pasv_enable=YES
pasv_min_port=$PASV_MIN
pasv_max_port=$PASV_MAX

local_umask=022
xferlog_enable=YES
EOF

    systemctl restart vsftpd
    core::open_firewall
}