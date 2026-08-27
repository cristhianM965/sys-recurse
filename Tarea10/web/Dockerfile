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