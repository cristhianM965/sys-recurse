#!/usr/bin/env bash
set -e

NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"

require_root() {
if [[ $EUID -ne 0 ]]; then
echo "Ejecuta este script con sudo."
exit 1
fi
}

pause(){
read -p "Presiona ENTER para continuar..."
}

list_interfaces(){

echo
echo "Interfaces disponibles:"
ip -o link show | awk -F': ' '{print $2}' | grep -v lo
echo
}

show_ip(){

echo
ip a
echo
}

validate_ip(){

if [[ ! $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
echo "IP inválida"
return 1
fi
}

backup_netplan(){

echo "Creando respaldo..."
cp /etc/netplan/*.yaml /etc/netplan/backup.yaml 2>/dev/null || true
}

configure_static(){

list_interfaces

read -p "Interfaz: " IFACE
read -p "IP: " IP
validate_ip $IP || return

read -p "Prefijo (ej 24): " PREFIX
read -p "Gateway (opcional): " GW
read -p "DNS (ej 8.8.8.8): " DNS

backup_netplan

cat <<EOF > $NETPLAN_FILE
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      addresses:
        - $IP/$PREFIX
EOF

if [[ -n "$GW" ]]; then
cat <<EOF >> $NETPLAN_FILE
      routes:
        - to: default
          via: $GW
EOF
fi

cat <<EOF >> $NETPLAN_FILE
      nameservers:
        addresses: [$DNS]
EOF

netplan apply

echo
echo "Configuración aplicada."
show_ip
}

restore_dhcp(){

list_interfaces
read -p "Interfaz para DHCP: " IFACE

backup_netplan

cat <<EOF > $NETPLAN_FILE
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: true
EOF

netplan apply

echo
echo "DHCP activado."
show_ip
}

test_connection(){

read -p "IP a probar (ej 8.8.8.8): " TARGET

ping -c 4 $TARGET
}

menu(){

while true
do

clear

echo "=============================="
echo " Network Configuration Tool"
echo "=============================="
echo
echo "1) Mostrar interfaces"
echo "2) Configurar IP estática"
echo "3) Restaurar DHCP"
echo "4) Mostrar configuración actual"
echo "5) Probar conectividad"
echo "6) Salir"
echo

read -p "Seleccione una opción: " op

case $op in

1)
list_interfaces
pause
;;

2)
configure_static
pause
;;

3)
restore_dhcp
pause
;;

4)
show_ip
pause
;;

5)
test_connection
pause
;;

6)
exit
;;

*)
echo "Opción inválida"
pause
;;

esac

done

}

main(){

require_root
menu

}

main