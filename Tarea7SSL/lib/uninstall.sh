#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

uninstall_apache() {
  systemctl stop apache2 2>/dev/null || true
  apt-get purge -y apache2 apache2-common apache2-bin
  apt-get autoremove -y
  rm -f /etc/apache2/sites-available/reprobados.conf
  log "Apache desinstalado"
}

uninstall_nginx() {
  systemctl stop nginx 2>/dev/null || true
  apt-get purge -y nginx nginx-common
  apt-get autoremove -y
  rm -f /etc/nginx/sites-available/reprobados-nginx
  rm -f /etc/nginx/sites-enabled/reprobados-nginx
  log "Nginx desinstalado"
}

uninstall_tomcat() {
  systemctl stop tomcat 2>/dev/null || true
  systemctl stop tomcat10 2>/dev/null || true
  apt-get purge -y tomcat10 tomcat10-common tomcat9
  apt-get autoremove -y
  rm -rf /opt/tomcat
  rm -f /etc/systemd/system/tomcat.service
  systemctl daemon-reload
  log "Tomcat desinstalado"
}

uninstall_vsftpd() {
  systemctl stop vsftpd 2>/dev/null || true
  apt-get purge -y vsftpd
  apt-get autoremove -y
  log "vsftpd desinstalado"
}

uninstall_service() {
  local service="$1"

  case "$service" in
    Apache) uninstall_apache ;;
    Nginx) uninstall_nginx ;;
    Tomcat) uninstall_tomcat ;;
    vsftpd) uninstall_vsftpd ;;
    *) die "Servicio no soportado para desinstalación: $service" ;;
  esac
}