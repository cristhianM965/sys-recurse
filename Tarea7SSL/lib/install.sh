#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/repo.sh"

install_from_web() {
  local service="$1"

  case "$service" in
    Apache)
      apt-get update -y
      apt-get install -y apache2
      systemctl enable --now apache2
      ;;
    Nginx)
      apt-get update -y
      apt-get install -y nginx
      systemctl enable --now nginx
      ;;
    Tomcat)
      apt-get update -y
      apt-get install -y tomcat10 || apt-get install -y tomcat9
      systemctl enable --now tomcat10 2>/dev/null || systemctl enable --now tomcat9
      ;;
    vsftpd)
      apt-get update -y
      apt-get install -y vsftpd
      systemctl enable --now vsftpd
      ;;
    *)
      die "Servicio WEB no soportado: $service"
      ;;
  esac

  log "Instalación WEB completada para $service"
}

install_from_ftp() {
  local service="$1"
  local file local_file

  file="$(ftp_select_installer "$service")"
  local_file="$(ftp_download_with_hash "$service" "$file")"

  case "$file" in
    *.deb)
      dpkg -i "$local_file" || apt-get install -f -y
      ;;
    *.tar.gz)
      if [[ "$service" == "Tomcat" ]]; then
        install_tomcat_from_tarball "$local_file"
      else
        die "Instalación tar.gz no definida para $service"
      fi
      ;;
    *.zip)
      die "ZIP aún no implementado para Linux"
      ;;
    *)
      die "Formato de instalador no soportado: $file"
      ;;
  esac

  case "$service" in
    Apache) systemctl enable --now apache2 ;;
    Nginx) systemctl enable --now nginx ;;
    Tomcat) systemctl enable --now tomcat 2>/dev/null || systemctl enable --now tomcat10 2>/dev/null || true ;;
    vsftpd) systemctl enable --now vsftpd ;;
  esac

  log "Instalación FTP completada para $service"
}