# Dockerfile using Alpine with latest packages
FROM alpine:3.20

ENV CN=proxy.squid.com \
    O=squid \
    OU=squid \
    C=US

RUN apk add --no-cache \
    squid \
    openssl \
    ca-certificates && \
    update-ca-certificates

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3128 4128

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
