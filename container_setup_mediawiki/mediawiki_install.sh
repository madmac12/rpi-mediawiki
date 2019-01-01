#!/usr/bin/qemu-arm-static /bin/sh

wget --no-verbose https://releases.wikimedia.org/mediawiki/1.31/mediawiki-1.31.1.tar.gz

cd /opt
tar -xzvf /mediawiki-1.31.1.tar.gz
cd /

# Create a parent directory to serve as the document root under which the "wiki"
# default location path will be located.  This makes the nginx config WAY easier.
mkdir /opt/mediawiki
mv /opt/mediawiki-1.31.1 /opt/mediawiki/wiki


# This is just a reminder of which version is installed
ln -s /opt/mediawiki/wiki /opt/mediawiki-1.31.1

chown -R www-data:www-data /opt/mediawiki/wiki

# We're done with download tar/archive file now, so drop it to shrink the container size.
rm mediawiki-1.31.1.tar.gz

