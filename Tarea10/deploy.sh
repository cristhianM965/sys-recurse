#!/bin/bash
set -e

# =========================================================================
# VARIABLES DE CONFIGURACIÓN (Edita esto en VS Code antes de clonar)
# =========================================================================
# Detecta automáticamente la interfaz principal, pero puedes forzarla (ej. IFACE="enp0s3")
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)
IP="192.168.1.100"
PREFIX="24"
GW="192.168.1.254"
DNS="8.8.8.8"

NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
# =========================================================================

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: Ejecuta este script con sudo."
        exit 1
    fi
}

pause(){
    echo ""
    read -p "Presiona ENTER para tomar la captura y continuar a la siguiente prueba..."
}

configurar_red() {
    echo "=== 1. CONFIGURANDO RED (NETPLAN) ==="
    echo "Creando respaldo de netplan..."
    cp /etc/netplan/*.yaml /etc/netplan/backup.yaml 2>/dev/null || true

    echo "Aplicando IP $IP/$PREFIX a la interfaz $IFACE..."
    cat <<EOF > $NETPLAN_FILE
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      addresses:
        - $IP/$PREFIX
      routes:
        - to: default
          via: $GW
      nameservers:
        addresses: [$DNS]
EOF

    netplan apply
    sleep 3
    ip a | grep $IP
    echo "Red configurada correctamente."
    echo "----------------------------------------"
}

preparar_docker() {
    echo "=== 2. PREPARANDO ARCHIVOS DOCKER ==="
    mkdir -p web

    # Crear index.html
    cat << 'EOF' > web/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Servidor Web - Práctica 10</title>
</head>
<body>
    <h1>¡Contenedor Web Funcionando!</h1>
    <p>Servidor Apache corriendo sobre Alpine Linux de forma segura y sin privilegios root.</p>
</body>
</html>
EOF

    # Crear Dockerfile
    cat << 'EOF' > web/Dockerfile
FROM alpine:latest
RUN apk update && apk add --no-cache apache2
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/httpd.conf
RUN sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/httpd.conf
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/httpd.conf
RUN addgroup -S webgroup && adduser -S webuser -G webgroup
RUN chown -R webuser:webgroup /var/www/localhost/htdocs/ \
    && chown -R webuser:webgroup /var/log/apache2/ \
    && chown -R webuser:webgroup /run/apache2/
COPY index.html /var/www/localhost/htdocs/
USER webuser
EXPOSE 8080
CMD ["httpd", "-D", "FOREGROUND"]
EOF

    # Crear docker-compose.yml
    cat << 'EOF' > docker-compose.yml
version: '3.8'
services:
  web:
    build: ./web
    container_name: servidor_web
    ports:
      - "80:8080"
    volumes:
      - web_content:/var/www/localhost/htdocs/
    networks:
      - infra_red
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.50'

  db:
    image: postgres:15-alpine
    container_name: servidor_bd
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password123
      POSTGRES_DB: practica10_db
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - infra_red
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.50'

  ftp:
    image: delfer/alpine-ftp-server
    container_name: servidor_ftp
    environment:
      USERS: "kami|Sistemas.2026!"
    ports:
      - "21:21"
      - "21000-21010:21000-21010"
    volumes:
      - web_content:/ftp/kami
    networks:
      - infra_red
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.25'

networks:
  infra_red:
    external: true

volumes:
  db_data:
    external: true
  web_content:
    external: true
EOF
    echo "Archivos generados con éxito."
    echo "----------------------------------------"
}

desplegar_infraestructura() {
    echo "=== 3. LEVANTANDO INFRAESTRUCTURA ==="
    docker network create infra_red 2>/dev/null || true
    docker volume create db_data 2>/dev/null || true
    docker volume create web_content 2>/dev/null || true

    docker compose up -d --build
    echo "Contenedores en línea."
    echo "----------------------------------------"
}

ejecutar_pruebas() {
    echo "=== 4. EJECUCIÓN DE PRUEBAS (PREPARA TUS CAPTURAS) ==="
    
    echo -e "\n[Prueba 10.1] Persistencia de BD"
    docker exec -t servidor_bd psql -U admin -d practica10_db -c "CREATE TABLE test (id int);"
    docker rm -f servidor_bd > /dev/null
    docker compose up -d db > /dev/null
    sleep 2
    docker exec -t servidor_bd psql -U admin -d practica10_db -c "\dt"
    echo "---> [CAPTURA LA SALIDA ANTERIOR PARA EL TEST 10.1]"
    pause

    clear
    echo -e "\n[Prueba 10.2] Aislamiento de Red"
    docker exec -t servidor_web ping -c 3 servidor_bd
    echo "---> [CAPTURA LOS PINGS PARA EL TEST 10.2]"
    pause

    clear
    echo -e "\n[Prueba 10.3] Permisos FTP"
    echo "Conéctate por FileZilla a la IP: $IP"
    echo "Usuario: kami | Contraseña: Sistemas.2026!"
    echo "Sube un archivo y revisa http://$IP/tu_archivo"
    echo "---> [TOMA CAPTURA DE FILEZILLA Y DEL NAVEGADOR PARA EL TEST 10.3]"
    pause

    clear
    echo -e "\n[Prueba 10.4] Límites de Recursos"
    echo "---> [TOMA CAPTURA DE LA SIGUIENTE TABLA (Ctrl+C para finalizar el script)]"
    sleep 2
    docker stats
}

main(){
    require_root
    clear
    echo "Iniciando despliegue automatizado..."
    configurar_red
    preparar_docker
    desplegar_infraestructura
    ejecutar_pruebas
}

main