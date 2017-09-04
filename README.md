![nginx 1.13](https://img.shields.io/badge/nginx-1.12-brightgreen.svg) [![License: GPL v3](https://img.shields.io/github/license/LordVeovis/docker-librenms.svg)](https://www.gnu.org/licenses/gpl-3.0) [![](https://img.shields.io/docker/pulls/veovis/librenms.svg)](https://hub.docker.com/r/veovis/librenms/ 'Docker Hub') [![](https://img.shields.io/docker/build/veovis/librenms.svg)](https://hub.docker.com/r/veovis/librenms/builds/ 'Docker Hub')

# docker-librenms
Docker image for LibreNMS

# About
This is a docker container for LibreNMS build around Alpine Linux for compacity.

There is not SSL support (and so no HTTP/2 support) as I think this should be done by a reverse proxy and not by the container itself.

# Technical stack

* Alpine 3.6
* nginx 1.12
* PHP 7.1
* dillon's cron 4.5

# Sample commands
	docker run \
		-e TIMEZONE=Europe/Paris \
		-e SNMP_COMMUNITY=kveer \
		-e MYSQL_HOST=mysql \
		-e MYSQL_USER=librenms \
		-e MYSQL_PASS=toto \
		-e MYSQL_NAME=librenms \
		--link mysql1:mysql \
		-v /volume1/docker/librenms/rrd:/opt/librenms/rrd \
		-v /volume1/docker/librenms/logs:/opt/librenms/logs \
		-v /volume1/docker/librenms/app-conf.d:/opt/librenms/conf.d \
		-p 5580:80 \
		--tmpfs /tmp \
		--name veovis-librenms \
	veovis/librenms

You can start with the [run-sample](run-sample) in the repo that I use to tests the builds.

# Parameters

## Environment variables
* TIMEZONE: the timezone
* SNMP_COMMUNITY: the default snmp community. I'm not sure this parameter is used
* MYSQL_HOST: the hostname, alias name or ip of the mysql host
* MYSQL_USER: the mysql user name
* MYSQL_PASS: the mysql password
* MYSQL_PASS_FILE: a file containing the mysql password
* MYSQL_NAME: the mysql database name
* MEMCACHE_HOST: the hostname of a memcache server. The port is hardcoded to 11211.

## Volumes
* /opt/librenms/rrd: the rrd database
* /opt/librenms/logs: the nginx and librenms logs
* /opt/librenms/conf.d: a mountpoint to override the librenms config.php. If this mountpoint contains a config.php file, it will be appended to the default config.php allowing advanced configuration.

# Initial setup

### Database configuration

* The database MUST already exists, there is currently no checks on the existence of the database. You can refer to [the librenms installation](http://docs.librenms.org/Installation/Installation-Ubuntu-1604-Nginx/#install-configure-mysql) regarding the required privileges and database specifications
* If the container find an empty database, it will create the schema and apply all updates. You can follow the progress on the docker log.
* After the schema has been created, a default user is created. The username and password is librenms
* Regarding LibreNMS 1.26 and lower, the sql_mode STRICT_TRANS_TABLES MUST NOT be enabled. This is already managed during the database population, but not in the application yet. I suggest keeping this flag disabled in case of undiscovered bug caused by this for the 1.27 version.

# TODO
- There is absolutely no checks on the passed environment variables
- Making the mountpoint /opt/librenms/conf.d a file mountpoint instead of a folder mountpoint.

# Maintenance tasks

* Creating the tables:

	docker exec veovis-librenms sh -c "cd /opt/librenms && php /opt/librenms/build-base.php"

* Creating an initial admin user (10 is the highest admin level):

	docker exec veovis-librenms php /opt/librenms/adduser.php admin admin 10 test@example.com

# Thanks
* To the librenms team
* jarischaefer for the initial docker container before making this one
