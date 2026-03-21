#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# Módulo de Seguridad SSL/TLS y HSTS
# ==========================================

linux_ssl_flow() {
    local servicio="$1"
    
    echo "------------------------------------------"
    read -p "¿Desea activar SSL en este servicio ($servicio)? [S/N]: " activar_ssl
    
    if [[ "$activar_ssl" =~ ^[Ss]$ ]]; then
        echo "Generando infraestructura PKI (Certificados Autofirmados)..."
        
        mkdir -p /etc/ssl/reprobados
        
        if [[ ! -f /etc/ssl/reprobados/reprobados.crt ]]; then
            # Genera llave y certificado sin pedir datos interactivos
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/ssl/reprobados/reprobados.key \
                -out /etc/ssl/reprobados/reprobados.crt \
                -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=Reprobados/CN=www.reprobados.com" 2>/dev/null
            
            echo "Certificado para www.reprobados.com generado con éxito."
        else
            echo "El certificado ya existe. Reutilizando llaves..."
        fi
        
        # Enrutar a la configuración de cada servicio
        case "$servicio" in
            "Nginx") linux_ssl_nginx ;;
            "Apache") linux_ssl_apache ;;
            "Tomcat") linux_ssl_tomcat ;;
            "vsftpd") linux_ssl_vsftpd ;;
            *) echo "Servicio no soportado para configuración SSL automática." ;;
        esac
    else
        echo "Omitiendo configuración SSL/TLS."
    fi
}

linux_ssl_nginx() {
    echo "Aplicando configuración SSL y redirección HSTS en Nginx..."
    local config_file="/etc/nginx/sites-available/default"
    cp "$config_file" "${config_file}.ssl.bak" 2>/dev/null || true
    
    cat > "$config_file" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name www.reprobados.com;

    ssl_certificate /etc/ssl/reprobados/reprobados.crt;
    ssl_certificate_key /etc/ssl/reprobados/reprobados.key;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    root /var/www/nginx;
    index index.html index.htm index.nginx-debian.html;
    location / { try_files \$uri \$uri/ =404; }
}
EOF
    nginx -t
    systemctl restart nginx
    echo "SSL/TLS configurado correctamente en Nginx (Puerto 443)."
}

linux_ssl_apache() {
    echo "Aplicando configuración SSL y redirección en Apache..."
    a2enmod ssl >/dev/null 2>&1
    a2enmod headers >/dev/null 2>&1
    a2enmod rewrite >/dev/null 2>&1
    
    local config_file="/etc/apache2/sites-available/000-default.conf"
    cp "$config_file" "${config_file}.ssl.bak" 2>/dev/null || true

    cat > "$config_file" <<EOF
<VirtualHost *:80>
    ServerName www.reprobados.com
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

<VirtualHost *:443>
    ServerName www.reprobados.com
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/ssl/reprobados/reprobados.crt
    SSLCertificateKeyFile /etc/ssl/reprobados/reprobados.key

    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</VirtualHost>
EOF
    systemctl restart apache2
    echo "SSL/TLS configurado correctamente en Apache (Puerto 443)."
}

linux_ssl_tomcat() {
    echo "Aplicando configuración SSL en Tomcat..."
    local server_xml="/opt/tomcat/conf/server.xml" # Ajusta la ruta si tu Tomcat está en otro lado
    
    if [ -f "$server_xml" ]; then
        cp "$server_xml" "${server_xml}.ssl.bak"
        # Inyecta el conector SSL para Tomcat usando sed
        sed -i '/<Service name="Catalina">/a \
    <Connector port="443" protocol="org.apache.coyote.http11.Http11NioProtocol" \
               maxThreads="150" SSLEnabled="true"> \
        <SSLHostConfig> \
            <Certificate certificateFile="/etc/ssl/reprobados/reprobados.crt" \
                         certificateKeyFile="/etc/ssl/reprobados/reprobados.key" \
                         type="RSA" /> \
        </SSLHostConfig> \
    </Connector>' "$server_xml"
        
        # Reinicia Tomcat (ajusta el comando según cómo lo manejes, systemctl o startup.sh)
        systemctl restart tomcat 2>/dev/null || /opt/tomcat/bin/startup.sh
        echo "SSL/TLS configurado correctamente en Tomcat (Puerto 443)."
    else
        echo "Advertencia: No se encontró server.xml en $server_xml"
    fi
}

linux_ssl_vsftpd() {
    echo "Aplicando configuración FTPS en vsftpd..."
    local conf="/etc/vsftpd.conf"
    cp "$conf" "${conf}.ssl.bak" 2>/dev/null || true

    # Limpia configuraciones SSL viejas si existen
    sed -i '/rsa_cert_file/d' "$conf"
    sed -i '/rsa_private_key_file/d' "$conf"
    sed -i '/ssl_enable/d' "$conf"

    # Inyecta la configuración FTPS
    cat >> "$conf" <<EOF

# Configuracion SSL/TLS agregada por Orquestador
rsa_cert_file=/etc/ssl/reprobados/reprobados.crt
rsa_private_key_file=/etc/ssl/reprobados/reprobados.key
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
EOF
    systemctl restart vsftpd
    echo "FTPS configurado correctamente en vsftpd (Canal seguro)."
}