# Overview
This repo includes the files to set up a MediaWiki installation on
a Raspberry Pi 3 with Docker.

# Database
The config for MediaWiki is set up to use MySQL.  Using a MariaDB
container works if the networking is set up correctly within
docker (but with DHCP swapping IP addresses each time you start up, 
that can be a challenge).  

# Portainer Stack
To make it easier to set up a mini-network with a MariaDB container
networked by DNS the docker-compose.yml file can be used to create
a "stack" in Portainer.  (Portainer is a Docker management console
that also runs in a container.)