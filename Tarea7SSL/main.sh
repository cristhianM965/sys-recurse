#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/menu.sh"
source "$SCRIPT_DIR/lib/ports.sh"
source "$SCRIPT_DIR/lib/repo.sh"
source "$SCRIPT_DIR/lib/install.sh"
source "$SCRIPT_DIR/lib/ssl.sh"
source "$SCRIPT_DIR/lib/uninstall.sh"
source "$SCRIPT_DIR/lib/verify.sh"

main_install() {
  local service source use_ssl port_http port_https port_ftp

  service="$(choose_service)"

  case "$service" in
    Apache|Nginx|Tomcat)
      port_http="$(ask_for_port "HTTP para $service")"

      if ask_yes_no "¿Desea activar SSL para $service?"; then
        use_ssl="yes"
        port_https="$(ask_for_port "HTTPS para $service")"
      else
        use_ssl="no"
      fi
      ;;
    vsftpd)
      port_ftp="$(ask_for_port "FTP para vsftpd")"

      if ask_yes_no "¿Desea activar SSL/FTPS para vsftpd?"; then
        use_ssl="yes"
      else
        use_ssl="no"
      fi
      ;;
  esac

  source="$(choose_source)"

  case "$source" in
    WEB) install_from_web "$service" ;;
    FTP) install_from_ftp "$service" ;;
  esac

  if [[ "$service" == "Apache" ]]; then
    configure_apache_custom_ports "$port_http" "${port_https:-}" "$use_ssl"
    verify_service apache2
    verify_port "$port_http"
    [[ "$use_ssl" == "yes" ]] && verify_port "$port_https" && verify_https apache "$port_https" || verify_http apache "$port_http"
  fi

  if [[ "$service" == "Nginx" ]]; then
    configure_nginx_custom_ports "$port_http" "${port_https:-}" "$use_ssl"
    verify_service nginx
    verify_port "$port_http"
    [[ "$use_ssl" == "yes" ]] && verify_port "$port_https" && verify_https nginx "$port_https" || verify_http nginx "$port_http"
  fi

  if [[ "$service" == "Tomcat" ]]; then
    configure_tomcat_custom_ports "$port_http" "${port_https:-}" "$use_ssl"
    systemctl is-active --quiet tomcat10 && verify_service tomcat10 || verify_service tomcat
    verify_port "$port_http"
    [[ "$use_ssl" == "yes" ]] && verify_port "$port_https" && verify_https tomcat "$port_https" || verify_http tomcat "$port_http"
  fi

  if [[ "$service" == "vsftpd" ]]; then
    configure_vsftpd_custom_port "$port_ftp" "$use_ssl"
    verify_service vsftpd
    verify_port "$port_ftp"
    [[ "$use_ssl" == "yes" ]] && verify_ftps "$port_ftp"
  fi
}

main_uninstall() {
  local service
  service="$(choose_service)"

  if ask_yes_no "¿Seguro que desea desinstalar $service?"; then
    uninstall_service "$service"
  else
    log "Desinstalación cancelada para $service"
  fi
}

main_status() {
  echo
  echo "========== ESTADO =========="
  systemctl is-active apache2 2>/dev/null && echo "Apache: activo" || echo "Apache: inactivo/no instalado"
  systemctl is-active nginx 2>/dev/null && echo "Nginx: activo" || echo "Nginx: inactivo/no instalado"
  systemctl is-active tomcat10 2>/dev/null && echo "Tomcat10: activo" || systemctl is-active tomcat 2>/dev/null && echo "Tomcat: activo" || echo "Tomcat: inactivo/no instalado"
  systemctl is-active vsftpd 2>/dev/null && echo "vsftpd: activo" || echo "vsftpd: inactivo/no instalado"
  echo
  echo "Puertos en escucha:"
  ss -tuln
}

main() {
  require_root
  ensure_dirs
  install_base_tools

  local option
  while true; do
    show_main_menu
    read -r -p "Seleccione una opción: " option

    case "$option" in
      1) main_install ;;
      2) main_uninstall ;;
      3) main_status ;;
      4) show_summary ;;
      5) exit 0 ;;
      *) echo "Opción inválida." ;;
    esac
  done
}

main "$@"