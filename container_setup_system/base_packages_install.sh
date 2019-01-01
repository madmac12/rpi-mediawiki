#!/usr/bin/qemu-arm-static /bin/sh

# Find packages using google search
#    site:www.raspberryconnect.com/raspbian-packages-list thepackagename
# Most libraries are found here:
# http://www.raspberryconnect.com/raspbian-packages-list/item/110-raspbian-libs

apt-get -y update

apt-get -y install --no-install-recommends apt-utils

apt-get -y install --no-install-recommends ca-certificates

# wget is required to fetch the mediawiki install source package
# vim, less, net-tools are used for diagnostics when/if things aren't working
# gettext-base is required for config modification using envsubst
# patch is required for tweaks and fixes (if necessary)
# Supervisor is used to run multiple services (e.g. nginx and php-fpm) using a single docker ENTRYPOINT
# Netcat (nc command) is used in the start script to wait until the db host is up and listening
apt-get -y install --no-install-recommends \
    wget \
    cron \
    vim \
    less \
    net-tools \
    gettext-base \
    patch \
    supervisor \
    netcat

# By default, supervisor is enabled as a system service, but in the docker container
# it is only started manually by the docker ENTRYPOINT, so this disables the system service.
systemctl disable supervisor

