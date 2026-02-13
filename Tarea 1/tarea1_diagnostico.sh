#!/bin/bash

echo "====================================="
echo "  DIAGNOSTICO INICIAL DEL SISTEMA"
echo "====================================="

echo "Nombre del equipo:"
hostname
echo ""

echo "Direccion IP (IPv4 activas):"
ip -4 addr show | grep inet | grep -v 127.0.0.1
echo ""

echo "Espacio en disco (/):"
df -h / | awk 'NR==1 || NR==2'

echo "====================================="
