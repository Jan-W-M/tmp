#!/bin/sh

USERNAME=${USERNAME:-jmondela}

if [ -f "/etc/nginx/conf.d/nginx.conf" ]; then
    sed -i 's/jmondela\.42\.fr/$(USERNAME)\.42\.fr/g' /etc/nginx/conf.d/nginx.conf
fi

if [ ! -f "/etc/ssl/certs/nginx_certificate.crt" ]; then
    openssl req -new -newkey rsa:4096 -x509 -sha512 -days 365 -nodes \
    -subj "/C=AT/ST=Vienna/O=42/OU=42/CN=${USERNAME}.42.fr" \
    -out /etc/ssl/certs/nginx_certificate.crt \
    -keyout /etc/ssl/private/nginx_certificate.key
fi

exec "$@"
