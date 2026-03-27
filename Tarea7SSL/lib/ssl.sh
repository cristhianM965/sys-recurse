#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

CERT_CRT="$CERT_DIR/reprobados.crt"
CERT_KEY="$CERT_DIR/reprobados.key"
CERT_P12="$CERT_DIR/reprobados.p12"
OPENSSL_CNF="$CERT_DIR/openssl-san.cnf"

generate_self_signed_cert() {
  mkdir -p "$CERT_DIR"

  cat >"$OPENSSL_CNF" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = MX
ST = Sinaloa
L = Los Mochis
O = UAS
OU = SysAdmin
CN = $DOMAIN

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = $ALT_DOMAIN
EOF

  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$CERT_KEY" \
    -out "$CERT_CRT" \
    -config "$OPENSSL_CNF"

  openssl pkcs12 -export \
    -inkey "$CERT_KEY" \
    -in "$CERT_CRT" \
    -out "$CERT_P12" \
    -passout pass:"$TOMCAT_P12_PASS"

  chmod 644 "$CERT_CRT"
  chmod 640 "$CERT_KEY" "$CERT_P12"

  if id tomcat >/dev/null 2>&1; then
  chown root:tomcat "$CERT_KEY" "$CERT_P12"
  fi

  log "Certificado autofirmado generado en $CERT_DIR"
}

ensure_certificate_exists() {
  if [[ -f "$CERT_CRT" && -f "$CERT_KEY" && -f "$CERT_P12" ]]; then
    log "Certificado existente detectado. Se reutilizará."
    return 0
  fi

  generate_self_signed_cert
}

configure_apache_custom_ports() {
  local http_port="$1"
  local https_port="${2:-}"
  local use_ssl="$3"

  mkdir -p /var/www/reprobados
  echo "<h1>Apache - $DOMAIN</h1>" >/var/www/reprobados/index.html

  a2enmod rewrite headers >/dev/null 2>&1 || true

  if [[ "$use_ssl" == "yes" ]]; then
    [[ -n "$https_port" ]] || die "Falta puerto HTTPS para Apache"
    ensure_certificate_exists
    a2enmod ssl >/dev/null 2>&1 || true

    cat >/etc/apache2/ports.conf <<EOF
Listen $http_port
Listen $https_port
EOF

    cat >/etc/apache2/sites-available/reprobados.conf <<EOF
<VirtualHost *:$http_port>
    ServerName $DOMAIN
    ServerAlias $ALT_DOMAIN
    RewriteEngine On
    RewriteRule ^/(.*)$ https://%{HTTP_HOST}:$https_port/\$1 [R=301,L]
</VirtualHost>

<VirtualHost *:$https_port>
    ServerName $DOMAIN
    ServerAlias $ALT_DOMAIN
    DocumentRoot /var/www/reprobados

    SSLEngine on
    SSLCertificateFile $CERT_CRT
    SSLCertificateKeyFile $CERT_KEY

    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

    <Directory /var/www/reprobados>
        Require all granted
        AllowOverride All
    </Directory>
</VirtualHost>
EOF
  else
    cat >/etc/apache2/ports.conf <<EOF
Listen $http_port
EOF

    cat >/etc/apache2/sites-available/reprobados.conf <<EOF
<VirtualHost *:$http_port>
    ServerName $DOMAIN
    ServerAlias $ALT_DOMAIN
    DocumentRoot /var/www/reprobados

    <Directory /var/www/reprobados>
        Require all granted
        AllowOverride All
    </Directory>
</VirtualHost>
EOF
  fi

  a2dissite 000-default.conf >/dev/null 2>&1 || true
  a2ensite reprobados.conf >/dev/null 2>&1 || true

  apache2ctl configtest || die "La configuración de Apache es inválida"
  systemctl restart apache2
  log "Apache configurado en puerto HTTP $http_port ${https_port:+y HTTPS $https_port}"
}

configure_nginx_custom_ports() {
  local http_port="$1"
  local https_port="${2:-}"
  local use_ssl="$3"

  mkdir -p /var/www/reprobados-nginx
  echo "<h1>Nginx - $DOMAIN</h1>" >/var/www/reprobados-nginx/index.html

  if [[ "$use_ssl" == "yes" ]]; then
    [[ -n "$https_port" ]] || die "Falta puerto HTTPS para Nginx"
    ensure_certificate_exists

    cat >/etc/nginx/sites-available/reprobados-nginx <<EOF
server {
    listen $http_port;
    server_name $DOMAIN $ALT_DOMAIN;
    return 301 https://\$host:$https_port\$request_uri;
}

server {
    listen $https_port ssl;
    server_name $DOMAIN $ALT_DOMAIN;

    ssl_certificate $CERT_CRT;
    ssl_certificate_key $CERT_KEY;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    root /var/www/reprobados-nginx;
    index index.html;
}
EOF
  else
    cat >/etc/nginx/sites-available/reprobados-nginx <<EOF
server {
    listen $http_port;
    server_name $DOMAIN $ALT_DOMAIN;

    root /var/www/reprobados-nginx;
    index index.html;
}
EOF
  fi

  ln -sf /etc/nginx/sites-available/reprobados-nginx /etc/nginx/sites-enabled/reprobados-nginx
  rm -f /etc/nginx/sites-enabled/default

  nginx -t || die "La configuración de Nginx es inválida"
  systemctl restart nginx
  log "Nginx configurado en puerto HTTP $http_port ${https_port:+y HTTPS $https_port}"
}

configure_vsftpd_custom_port() {
  local ftp_port="$1"
  local use_ssl="$2"

  if [[ "$use_ssl" == "yes" ]]; then
    ensure_certificate_exists

    cat >/etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
listen_port=$ftp_port

anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022

dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

chroot_local_user=YES
allow_writeable_chroot=YES

ssl_enable=YES
rsa_cert_file=$CERT_CRT
rsa_private_key_file=$CERT_KEY
force_local_logins_ssl=YES
force_local_data_ssl=YES
require_ssl_reuse=NO
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40010
EOF
  else
    cat >/etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
listen_port=$ftp_port

anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022

dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

chroot_local_user=YES
allow_writeable_chroot=YES

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40010
EOF
  fi

  systemctl restart vsftpd
  log "vsftpd configurado en puerto $ftp_port con SSL=$use_ssl"
}

configure_tomcat_custom_ports() {
  local http_port="$1"
  local https_port="${2:-}"
  local use_ssl="$3"

  local server_xml=""
  local webxml=""
  local tomcat_svc=""

  if [[ -f /etc/tomcat10/server.xml ]]; then
    server_xml="/etc/tomcat10/server.xml"
    tomcat_svc="tomcat10"
  elif [[ -f /var/lib/tomcat10/conf/server.xml ]]; then
    server_xml="/var/lib/tomcat10/conf/server.xml"
    tomcat_svc="tomcat10"
  elif [[ -f /opt/tomcat/conf/server.xml ]]; then
    server_xml="/opt/tomcat/conf/server.xml"
    tomcat_svc="tomcat"
  else
    die "No se encontró server.xml de Tomcat"
  fi

  if [[ -f /etc/tomcat10/web.xml ]]; then
    webxml="/etc/tomcat10/web.xml"
  elif [[ -f /var/lib/tomcat10/conf/web.xml ]]; then
    webxml="/var/lib/tomcat10/conf/web.xml"
  elif [[ -f /opt/tomcat/conf/web.xml ]]; then
    webxml="/opt/tomcat/conf/web.xml"
  fi

  cp "$server_xml" "$server_xml.bak.$(date +%s)"

  # Elimina conectores previos insertados por el script
  sed -i '/<Connector port="[0-9]\+" protocol="HTTP\/1\.1" connectionTimeout="20000" redirectPort="[0-9]\+" \/>/d' "$server_xml"
  sed -i '/SSLEnabled="true"/,/<\/Connector>/d' "$server_xml"

  # Inserta conector HTTP personalizado
  sed -i "/<Service name=\"Catalina\">/a\\
    <Connector port=\"$http_port\" protocol=\"HTTP/1.1\" connectionTimeout=\"20000\" redirectPort=\"${https_port:-8443}\" />" "$server_xml"

  if [[ "$use_ssl" == "yes" ]]; then
    [[ -n "$https_port" ]] || die "Falta puerto HTTPS para Tomcat"
    ensure_certificate_exists

    sed -i "/<Service name=\"Catalina\">/a\\
    <Connector port=\"$https_port\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" maxThreads=\"200\" SSLEnabled=\"true\" scheme=\"https\" secure=\"true\">\\
        <SSLHostConfig>\\
            <Certificate certificateKeystoreFile=\"$CERT_P12\" certificateKeystorePassword=\"$TOMCAT_P12_PASS\" certificateKeystoreType=\"PKCS12\" />\\
        </SSLHostConfig>\\
    </Connector>" "$server_xml"

    if [[ -n "$webxml" ]] && ! grep -q "HttpHeaderSecurityFilter" "$webxml"; then
      cp "$webxml" "$webxml.bak.$(date +%s)"
      sed -i '/<\/web-app>/i\
  <filter>\
    <filter-name>httpHeaderSecurity</filter-name>\
    <filter-class>org.apache.catalina.filters.HttpHeaderSecurityFilter</filter-class>\
    <init-param><param-name>hstsEnabled</param-name><param-value>true</param-value></init-param>\
    <init-param><param-name>hstsMaxAgeSeconds</param-name><param-value>31536000</param-value></init-param>\
    <init-param><param-name>hstsIncludeSubDomains</param-name><param-value>true</param-value></init-param>\
  </filter>\
  <filter-mapping>\
    <filter-name>httpHeaderSecurity</filter-name>\
    <url-pattern>/*</url-pattern>\
  </filter-mapping>' "$webxml"
    fi
  fi

  systemctl restart "$tomcat_svc" || die "No se pudo reiniciar $tomcat_svc"

  sleep 2

  if ! systemctl is-active --quiet "$tomcat_svc"; then
    die "Tomcat no quedó activo después de aplicar la configuración"
  fi

  log "Tomcat configurado en puerto HTTP $http_port ${https_port:+y HTTPS $https_port}"
}

remove_ssl_artifacts() {
  rm -f "$CERT_CRT" "$CERT_KEY" "$CERT_P12" "$OPENSSL_CNF"
  log "Archivos SSL eliminados de $CERT_DIR"
}