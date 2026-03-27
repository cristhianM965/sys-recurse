#!/usr/bin/env bash

show_main_menu() {
  echo
  echo "========== TAREA 07 LINUX =========="
  echo "1) Instalar servicio"
  echo "2) Desinstalar servicio"
  echo "3) Ver estado de servicios"
  echo "4) Ver resumen"
  echo "5) Salir"
  echo "===================================="
}

choose_service() {
  local choice
  while true; do
    echo >&2
    echo "Seleccione un servicio:" >&2
    echo "1) Apache" >&2
    echo "2) Nginx" >&2
    echo "3) Tomcat" >&2
    echo "4) vsftpd" >&2
    read -r -p "Opción: " choice >&2

    case "$choice" in
      1) echo "Apache"; return 0 ;;
      2) echo "Nginx"; return 0 ;;
      3) echo "Tomcat"; return 0 ;;
      4) echo "vsftpd"; return 0 ;;
      *) echo "Opción inválida." >&2 ;;
    esac
  done
}

choose_source() {
  local choice
  while true; do
    echo >&2
    echo "Fuente de instalación:" >&2
    echo "1) WEB" >&2
    echo "2) FTP" >&2
    read -r -p "Opción: " choice >&2

    case "$choice" in
      1) echo "WEB"; return 0 ;;
      2) echo "FTP"; return 0 ;;
      *) echo "Opción inválida." >&2 ;;
    esac
  done
}