# docker-librenms
Docker image for LibreNMS

# About
This is a docker container for LibreNMS build around Alpine Linux for compacity.
The container runs nginx 1.10 and PHP 7.0 FPM.

There is not SSL support (and so no HTTP/2 support) as I think this should be done by a reverse proxy and not by the container itself.
There is no memcached support for now.

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
* SNMP_COMMUNITY: the default snmp community. I'm not sure this is in use
* MYSQL_HOST: the hostname, alias name or ip of the mysql host
* MYSQL_USER: the mysql user name
* MYSQL_PASS: the mysql password
* MYSQL_NAME: the mysql database name

## Volumes
* /opt/librenms/rrd: the rrd database
* /opt/librenms/logs: the nginx and librenms logs
* /opt/librenms/conf.d: a mountpoint to override the librenms config.php. If this mountpoint contains a config.php file, it will be appended to the default config.php allowing advanced configuration.

# Initial setup

### Database configuration

* Before starting this container for the very first time, make sure the mysql server is fully initialized and ready.
* The database MUST already exists, there is currently no checks on the existence of the database. You can refer to [the librenms installation](http://docs.librenms.org/Installation/Installation-Ubuntu-1604-Nginx/#install-configure-mysql) regarding the required privileges and database specifications
* If the container does not found any tables in the specified database, it will create the schema and apply all updates, which can takes some times. You can follow the progress on the docker log.
* After the schema has been created, a default user is created. The username and password is librenms
* Regarding LibreNMS 1.26 and lower, the sql_mode STRICT_TRANS_TABLES MUST NOT be enabled. This is already managed during the database population, but not in the application yet. I suggest keeping this flag disabled in case of undiscovered bug caused by this for the 1.27 version.

# TODO
- There is absolutely no check on the passed environment variables
- Making the mountpoint /opt/librenms/conf.d a file mountpoint instead of a folder mountpoint.

# Maintenance tasks

* Creating the tables:

	docker exec veovis-librenms sh -c "cd /opt/librenms && php /opt/librenms/build-base.php"

* Creating an initial admin user (10 is the highest admin level):

	docker exec veovis-librenms php /opt/librenms/adduser.php admin admin 10 test@example.com

# Thanks
* To the librenms team
* jarischaefer for the initial docker container before making this one
