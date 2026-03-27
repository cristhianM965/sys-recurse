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
    echo
    echo "Seleccione un servicio:"
    echo "1) Apache"
    echo "2) Nginx"
    echo "3) Tomcat"
    echo "4) vsftpd"
    read -r -p "Opción: " choice

    case "$choice" in
      1) echo "Apache"; return ;;
      2) echo "Nginx"; return ;;
      3) echo "Tomcat"; return ;;
      4) echo "vsftpd"; return ;;
      *) echo "Opción inválida." ;;
    esac
  done
}

choose_source() {
  local choice
  while true; do
    echo
    echo "Fuente de instalación:"
    echo "1) WEB"
    echo "2) FTP"
    read -r -p "Opción: " choice

    case "$choice" in
      1) echo "WEB"; return ;;
      2) echo "FTP"; return ;;
      *) echo "Opción inválida." ;;
    esac
  done
}