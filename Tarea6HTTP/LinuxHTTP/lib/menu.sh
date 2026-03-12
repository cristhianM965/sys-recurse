#!/usr/bin/env bash
set -Eeuo pipefail

linux_uninstall_menu() {
  local option
  while true; do
    linux_print_header
    echo "=========== DESINSTALAR SERVICIOS ==========="
    echo
    echo "1) Desinstalar Apache2"
    echo "2) Desinstalar Nginx"
    echo "3) Desinstalar Tomcat"
    echo "4) Volver"
    echo

    option="$(linux_safe_input_number "Selecciona una opción: " 4)"
    case "$option" in
      1)
        linux_uninstall_apache
        linux_pause
        ;;
      2)
        linux_uninstall_nginx
        linux_pause
        ;;
      3)
        linux_uninstall_tomcat
        linux_pause
        ;;
      4)
        break
        ;;
    esac
  done
}

linux_main_menu() {
  local option
  while true; do
    linux_print_header
    echo "1) Instalar Apache2"
    echo "2) Instalar Nginx"
    echo "3) Instalar Tomcat"
    echo "4) Desinstalar servicios"
    echo "5) Salir"
    echo

    option="$(linux_safe_input_number "Selecciona una opción: " 5)"
    case "$option" in
      1)
        linux_apache_flow
        linux_pause
        ;;
      2)
        linux_nginx_flow
        linux_pause
        ;;
      3)
        linux_tomcat_flow
        linux_pause
        ;;
      4)
        linux_uninstall_menu
        ;;
      5)
        echo "Saliendo..."
        break
        ;;
    esac
  done
}