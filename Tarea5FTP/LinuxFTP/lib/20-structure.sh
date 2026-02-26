#!/usr/bin/env bash
set -Eeuo pipefail

structure::create_base() {
    core::banner "Creando estructura base"

    core::ensure_group "$GROUP_A"
    core::ensure_group "$GROUP_B"
    core::ensure_group "$COMMON_GROUP"

    core::ensure_dir "$GENERAL_DIR"
    core::ensure_dir "$GROUPS_DIR/$GROUP_A"
    core::ensure_dir "$GROUPS_DIR/$GROUP_B"
    core::ensure_dir "$USERS_DIR"
    core::ensure_dir "$ANON_DIR"

    chown root:$COMMON_GROUP "$GENERAL_DIR"
    chmod 1775 "$GENERAL_DIR"

    chown root:$GROUP_A "$GROUPS_DIR/$GROUP_A"
    chmod 2775 "$GROUPS_DIR/$GROUP_A"

    chown root:$GROUP_B "$GROUPS_DIR/$GROUP_B"
    chmod 2775 "$GROUPS_DIR/$GROUP_B"
}

structure::anon_bind() {
    core::banner "Configurando acceso anónimo"

    core::ensure_dir "$ANON_DIR/general"
    core::bind_mount "$GENERAL_DIR" "$ANON_DIR/general"
}