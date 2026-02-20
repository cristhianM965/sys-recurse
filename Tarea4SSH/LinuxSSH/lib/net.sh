#!/usr/bin/env bash
set -euo pipefail

is_ubuntu_debian() {
  [[ -f /etc/debian_version ]]
}

apt_update_once() {
  # evita repetir apt update en el mismo run
  if [[ -z "${_APT_UPDATED:-}" ]]; then
    export _APT_UPDATED=1
    apt-get update -y
  fi
}

install_pkg() {
  local pkg="$1"
  apt_update_once
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
}