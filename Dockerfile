FROM alpine:3.6

ARG VERSION=1.31
LABEL version="${VERSION}" \
	description="librenms container with alpine" \
	maintainer="Veovis <veovis@kveer.fr>"

RUN apk update --no-cache && \
	apk upgrade --no-cache && \
	apk add --no-cache \
	ca-certificates \
	openssl \
	tzdata \
	bash \
	php7 \
	php7-ctype \
	php7-mysqli \
	php7-gd \
	php7-snmp \
	php7-pear \
	php7-curl \
	php7-fpm \
	php7-openssl \
	php7-mcrypt \
	php7-json \
	php7-session \
	php7-simplexml \
	net-snmp \
	net-snmp-tools \
	graphviz \
	nginx \
	fping \
	imagemagick \
	whois \
	nmap \
	rrdtool \
	python2 \
	py-mysqldb \
	runit \
	dcron \
	mysql-client \
	mtr && \
	update-ca-certificates && \
	pear channel-update pear.php.net && \
	pear install pear/Net_IPv4 && \
	pear install pear/Net_IPv6 && \
	mkdir -p /opt

RUN	rm /etc/nginx/conf.d/default.conf && \
	sed -i -e 's/^;pid/pid/' /etc/php7/php-fpm.conf && \
	sed -i -e 's!^; \?include_path.*!include_path=".:/usr/share/php7"!' /etc/php7/php.ini && \
	rm /etc/php7/php-fpm.d/www.conf

RUN	wget -q -O - -c "https://github.com/librenms/librenms/archive/${VERSION}.tar.gz" | tar -zx -f - -C /opt && \
	mv /opt/librenms-${VERSION} /opt/librenms && \
	sed -i -e 's/ALTER IGNORE TABLE/ALTER TABLE/' /opt/librenms/sql-schema/109.sql && \
	sed -i -e 's/ALTER IGNORE TABLE/ALTER TABLE/' /opt/librenms/sql-schema/181.sql && \
	adduser -D -h /opt/librenms librenms && \
	adduser nginx librenms && \
	install -m 775 -d /opt/librenms/rrd && \
	install -d /opt/librenms/logs && \
	chown -R librenms:librenms /opt/librenms && \
	cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf && \
	cp /opt/librenms/config.php.default /opt/librenms/config.php && \
	echo "\$config['fping'] = '/usr/sbin/fping';" >> /opt/librenms/config.php && \
	echo "if(file_exists(realpath(__DIR__) . '/config.d/config.php')) include realpath(__DIR__) . '/config.d/config.php';" >> /opt/librenms/config.php && \
	wget -q -O /usr/local/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro && \
	chmod +x /usr/local/bin/distro && \
	cp /opt/librenms/librenms.nonroot.cron /etc/crontabs/librenms && \
	sed -i -e 's/ librenms //' /etc/crontabs/librenms

COPY patches /tmp/patches
WORKDIR /opt/librenms
RUN patch -p 1 -i /tmp/patches/002_missing_menu_index.patch && \
	patch -p 1 -i /tmp/patches/003_missing_used_sensors_index.patch

COPY services /etc/service
COPY runit-bootstrap /usr/local/bin/docker-entrypoint
COPY nginx-librenms.conf /etc/nginx/conf.d/librenms.conf
COPY php-librenms.conf /etc/php7/php-fpm.d/librenms.conf

RUN chmod 755 /usr/local/bin/docker-entrypoint && \
	chmod -R 755 /etc/service

CMD ["/usr/local/bin/docker-entrypoint"]

EXPOSE 80
WORKDIR /
VOLUME ["/opt/librenms/logs", "/opt/librenms/rrd", "/opt/librenms/config.d"]
