FROM raspbian/stretch

ENV LANG C.UTF-8
ENV TZ America/Denver

COPY rpi_bin/qemu-arm-static /usr/bin/
RUN chmod +x /usr/bin/qemu-arm-static

ARG DEBIAN_FRONTEND=noninteractive

# Main System Layer
COPY container_setup_system/* ./container_setup_system/
RUN chmod +x container_setup_system/base_packages_install.sh \
    && container_setup_system/base_packages_install.sh

# Web and App Server Layer
COPY container_setup_server/* ./container_setup_server/
RUN chmod +x container_setup_server/install_nginx_php_mariadb_client.sh \
    && container_setup_server/install_nginx_php_mariadb_client.sh

# MediaWiki Application Layer
COPY container_setup_mediawiki/* ./container_setup_mediawiki/
RUN chmod +x container_setup_mediawiki/mediawiki_install.sh \
    && container_setup_mediawiki/mediawiki_install.sh

ENV NGINX_HTTPS_PORT_NUMBER="443" \
    NGINX_HTTP_PORT_NUMBER="80" \
    MARIADB_HOST="localhost" \
    MARIADB_ROOT_USER="root" \
    MARIADB_ROOT_PASSWORD="" \
    MEDIAWIKI_ADMIN_USER="admin" \
    MEDIAWIKI_ADMIN_PASSWORD="wikiadmin" \
    MEDIAWIKI_SERVER_NAME="wikiserver"
    
EXPOSE 80

COPY container_startup/* ./
COPY VERSION ./
RUN chmod +x mediawiki-entrypoint.sh
ENTRYPOINT ["/mediawiki-entrypoint.sh"]
