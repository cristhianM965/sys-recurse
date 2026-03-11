#!/usr/bin/env bash
set -Eeuo pipefail

linux_main_menu() {
  local option
  while true; do
    linux_print_header
    echo "1) Instalar Apache2"
    echo "2) Instalar Nginx"
    echo "3) Instalar Tomcat"
    echo "4) Salir"
    echo

    option="$(linux_safe_input_number "Selecciona una opción: " 4)"
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
        echo "Saliendo..."
        break
        ;;
    esac
  done
}