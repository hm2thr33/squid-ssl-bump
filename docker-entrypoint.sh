#!/bin/sh
set -e

CHOWN=$(command -v chown)
SQUID=$(command -v squid)

SSL_DIR="/etc/squid/ssl"
SSL_DB_DIR="/var/lib/squid/ssl_db"

prepare_folders() {
    echo "Preparing folders..."
    mkdir -p "$SSL_DIR" /var/cache/squid /var/log/squid /var/lib/squid
    "$CHOWN" -R squid:squid "$SSL_DIR" /var/cache/squid /var/log/squid /var/lib/squid
}

create_cert() {
    if [ ! -f "$SSL_DIR/ca-key.pem" ] || [ ! -f "$SSL_DIR/ca-cert.pem" ]; then
        echo "Creating certificate..."
        openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 \
            -extensions v3_ca -keyout "$SSL_DIR/ca-key.pem" \
            -out "$SSL_DIR/ca-cert.pem" \
            -subj "/CN=${CN:-squid.local}/O=${O:-squid}/OU=${OU:-squid}/C=${C:-US}" \
            -utf8 -nameopt multiline,utf8

        openssl x509 -in "$SSL_DIR/ca-cert.pem" -outform DER -out "$SSL_DIR/ca-cert.der"
        "$CHOWN" -R squid:squid "$SSL_DIR"
        chmod 600 "$SSL_DIR/ca-key.pem"
    else
        echo "Certificate found..."
    fi
}

clear_certs_db() {
    echo "Clearing generated certificate db..."
    rm -rf "$SSL_DB_DIR"
    /usr/lib/squid/security_file_certgen -c -s "$SSL_DB_DIR" -M 4MB
    "$CHOWN" -R squid:squid "$SSL_DB_DIR"
}

initialize_cache() {
    echo "Creating cache folder..."
    "$SQUID" -z
    sleep 2
}

run() {
    echo "Starting squid..."
    prepare_folders
    create_cert
    clear_certs_db
    initialize_cache
    exec "$SQUID" -NYCd 1 -f /etc/squid/squid.conf
}

run
