#!/bin/sh

echo "Checking required ENV variable values."
missing_required_fields=0
# Check vars that have to be set before the first time starting up
if [ -z "${MARIADB_HOST}" ]; then
    echo "ENV variable value for MARIADB_HOST is required."
    missing_required_fields=1
fi

if [ -z "${MARIADB_ROOT_PASSWORD}" ]; then
    echo "ENV variable value for MARIADB_ROOT_PASSWORD is required."
    missing_required_fields=1
fi

if [ "${missing_required_fields}" = 1 ]; then
    echo "Missing required ENV variables.  MediaWiki initialization stopped.  Set and restart."
    exit 100
fi

if [ -z "${MARIADB_MEDIAWIKI_USER}" ]; then
    echo "WARNING: No MediaWiki DB user provided. Defaulting mariadb user for mediawiki to same as root mariadb user."
    export MARIADB_MEDIAWIKI_USER="${MARIADB_ROOT_USER}"
fi
if [ -z "${MARIADB_MEDIAWIKI_PASSWORD}" ]; then
    echo "WARNING: No MediaWiki DB password provided. Defaulting mariadb password for mediawiki to same as root mariadb password."
    export MARIADB_MEDIAWIKI_PASSWORD="${MARIADB_ROOT_PASSWORD}"
fi
if [ -z "${MEDIAWIKI_SERVER_NAME}" ]; then
    echo "WARNING: No MediaWiki server_name provided. Defaulting to 'wikiserver'."
    export MEDIAWIKI_SERVER_NAME=wikiserver
fi

# Wait for mariadb host to show up before proceeding
# It would be nice if Docker compose would just wait based on the depends-on statement
# but it apparently doesn't wait for anything to init.
dbWaitLoopCount=$((0))
while ! nc -z ${MARIADB_HOST} 3306 2>/dev/null; do
    echo "DB Host/Listener not found yet.  Waiting a bit before re-trying..."
    sleep 10
    dbWaitLoopCount=$((dbWaitLoopCount+1))
    if [ $dbWaitLoopCount -ge 10 ]; then
        echo "DB Host/Listener never found.  Check to be sure mariadb is running on host: '${MARIADB_HOST}'."
        break
    fi
done

# configure nginx with docker env params
if [ ! -f /etc/nginx/sites-available/mediawiki ]; then
    echo "Nginx site config for mediawiki not found in container... generating it now."
    # Add defaults if they're missing from the env
    if [ ! -z "${NGINX_HTTPS_PORT_NUMBER}" ]; then
        export NGINX_HTTPS_PORT_NUMBER=443
    fi
    if [ ! -z "${NGINX_HTTPS_PORT_NUMBER}" ]; then
        export NGINX_HTTP_PORT_NUMBER=80
    fi
    
    envsubst '\$NGINX_HTTPS_PORT_NUMBER \$NGINX_HTTP_PORT_NUMBER \$MEDIAWIKI_SERVER_NAME' \
        < mediawiki_nginx_template.conf \
        > /etc/nginx/sites-available/mediawiki
    ln -s /etc/nginx/sites-available/mediawiki /etc/nginx/sites-enabled/mediawiki
    rm /etc/nginx/sites-enabled/default
fi

MEDIAWIKI_DOCKER_CONF_DIR=/opt/mediawiki_docker_conf
MEDIAWIKI_DOCKER_CONF_FILEPATH="${MEDIAWIKI_DOCKER_CONF_DIR}/LocalSettings.php"
# Note: Because of a docker timing issue mounting volumes, using the volume
# before it is available may result in a cryptic "too many levels of symbolic links"
# error.  This waits for it to become available before moving and linking stuff.
dockerVolumeWaitLoopCount=$((0))
while [ ! -d "${MEDIAWIKI_DOCKER_CONF_DIR}" ]; do
    echo "Docker volume not mounted yet.  Waiting a bit before re-trying..."
    sleep 10
    dockerVolumeWaitLoopCount=$((dockerVolumeWaitLoopCount+1))
    if [ $dockerVolumeWaitLoopCount -ge 10 ]; then
        echo "Volume never mounted. Giving up.  LocalSettings.php needs to be moved manually."
        break
    fi
done
if [ ! -s "${MEDIAWIKI_DOCKER_CONF_FILEPATH}" ]; then
    # See: https://www.mediawiki.org/wiki/Manual:Install.php
    # Run PHP from the command line (since the actual nginx and php-fpm won't be running yet).
    # Running as www-data so that all the files created during setup are not owned by root
    # (as they would be if the PHP silent install were run without sudo).  This is to avoid
    # permissions problems later when MediaWiki tries to create files in {MEDIA_WIKI_HOME}/images/....
    cd /opt/mediawiki/wiki
    php_install_args="${php_install_args} --dbuser=${MARIADB_ROOT_USER}"
    php_install_args="${php_install_args} --dbpass=${MARIADB_ROOT_PASSWORD}"
    php_install_args="${php_install_args} --dbserver=${MARIADB_HOST}"
    php_install_args="${php_install_args} --dbname=mediawiki"
    php_install_args="${php_install_args} --pass=${MEDIAWIKI_ADMIN_PASSWORD}"  # wiki admin pw
    echo "php_install_args = '${php_install_args}'"
    sudo -u www-data php maintenance/install.php ${php_install_args} \
          "MediaWiki Powered by Raspberry Pi and Docker" \
          "${MEDIAWIKI_ADMIN_USER}"
    
    # Since MediaWiki uses a single file in its root directory named LocalSettings.php
    # and, even if it is possible, it isn't exactly straightforward to map a single 
    # file into the overlay file-system before the volume mappings get created, the 
    # following is a makeshift workaround.

    # This should be mounted as a volume, so the LocalSettings.php file can be moved
    # to a location outside the container, and managed there.
    # mkdir /opt/mediawiki_docker_conf
    echo "Re-locating LocalSettings.php to the Docker 'mediawiki_docker_conf' volume path."
    mv /opt/mediawiki/wiki/LocalSettings.php "${MEDIAWIKI_DOCKER_CONF_FILEPATH}"
    cp /mediawikicontainerlogo.png "${MEDIAWIKI_DOCKER_CONF_DIR}/"
    mv /opt/mediawiki/wiki/resources/assets/wiki.png /opt/mediawiki/wiki/resources/assets/wiki_original.png
    sudo -u www-data ln -s "${MEDIAWIKI_DOCKER_CONF_DIR}/mediawikicontainerlogo.png" /opt/mediawiki/wiki/resources/assets/wiki.png

    # This sym-link lets MediaWiki find the LocalSettings.php _file_ in the mediawiki_docker_conf volume _dir_
    sudo -u www-data ln -s "${MEDIAWIKI_DOCKER_CONF_FILEPATH}" /opt/mediawiki/wiki/LocalSettings.php
    cd /
    
elif [ ! -f /opt/mediawiki/wiki/LocalSettings.php ]; then
    # re-link existing config in case the container was re-created from the image 
    echo "Re-linking existing LocalSettings.php (from mapped volume)."
    sudo -u www-data ln -s "${MEDIAWIKI_DOCKER_CONF_FILEPATH}" /opt/mediawiki/wiki/LocalSettings.php
    # Also assume that the LocalSettings.php was found in the mounted volume
    # the logo .png file was probably already copied there too, so redo the process
    # of moving the default out the way and linking to the external one.
    mv /opt/mediawiki/wiki/resources/assets/wiki.png /opt/mediawiki/wiki/resources/assets/wiki_original.png
    sudo -u www-data ln -s "${MEDIAWIKI_DOCKER_CONF_DIR}/mediawikicontainerlogo.png" /opt/mediawiki/wiki/resources/assets/wiki.png
fi

# put the supervisord config where it goes (substituting if necessary)
if [ ! -f /opt/mediawiki_supervisord.conf ]; then
    # run envsubst if necessary
    cp mediawiki_supervisord.conf /opt/mediawiki_supervisord.conf
fi

supervisord -c /opt/mediawiki_supervisord.conf