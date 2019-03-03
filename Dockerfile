FROM alpine:3.9

ARG VERSION=1.48.1
ARG librenms_base=/opt/librenms
LABEL version="${VERSION}" \
	description="librenms container with alpine" \
	maintainer="Veovis <veovis@kveer.fr>"

# install required packages
RUN apk upgrade --no-cache && \
	apk add --no-cache \
	acl \
	ca-certificates \
	openssl \
	tzdata \
	bash \
	git \
	php7 \
	php7-ctype \
	php7-curl \
	php7-fileinfo \
	php7-fpm \
	php7-gd \
	php7-iconv \
	php7-json \
	php7-mbstring \
	php7-mcrypt \
	php7-memcached \
	php7-mysqli \
	php7-openssl \
	php7-phar \
	php7-pdo \
	php7-pdo_mysql \
	php7-pear \
	php7-posix \
	php7-session \
	php7-simplexml \
	php7-snmp \
	php7-tokenizer \
	net-snmp \
	net-snmp-tools \
	graphviz \
	nginx \
	fping \
	imagemagick \
	sudo \
	whois \
	nmap \
	rrdtool \
	python2 \
	py-mysqldb \
	runit \
	dcron \
	mariadb-client \
	util-linux \
	mtr

# download librenms
RUN set -e; \
	git clone https://github.com/librenms/librenms.git --branch ${VERSION} --depth=1 --single-branch "$librenms_base"

# post-install system
RUN set -e; \
	update-ca-certificates; \
	ln -s fping /usr/sbin/fping6; \
	pear channel-update pear.php.net; \
	pear install pear/Net_IPv4; \
	pear install pear/Net_IPv6

RUN	rm /etc/nginx/conf.d/default.conf && \
	sed -i -e 's/^;pid/pid/' /etc/php7/php-fpm.conf && \
	sed -i -e 's!^; \?include_path.*!include_path=".:/usr/share/php7"!' /etc/php7/php.ini && \
	sed -i -e 's/^\(variables_order\).*/\1="EGPCS"/' /etc/php7/php.ini && \
	rm /etc/php7/php-fpm.d/www.conf

WORKDIR $librenms_base

RUN adduser -D -h $librenms_base librenms && \
	adduser nginx librenms && \
	install -m 775 -d $librenms_base/bootstrap/cache $librenms_base/cache $librenms_base/logs $librenms_base/rrd $librenms_base/storage $librenms_base/vendor && \
	chown -R librenms:librenms $librenms_base && \
	cp $librenms_base/snmpd.conf.example /etc/snmp/snmpd.conf && \
	install -o librenms -g librenms $librenms_base/config.php.default $librenms_base/config.php && \
	echo "\$config['fping'] = '/usr/sbin/fping';" >> $librenms_base/config.php && \
	echo "if(file_exists(realpath(__DIR__) . '/config.d/config.php')) include realpath(__DIR__) . '/config.d/config.php';" >> $librenms_base/config.php && \
	echo "if(file_exists(realpath(__DIR__) . '/config.d/_memcache.php')) include realpath(__DIR__) . '/config.d/_memcache.php';" >> $librenms_base/config.php && \
	wget -q -O /usr/local/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro && \
	chmod +x /usr/local/bin/distro && \
	cp $librenms_base/librenms.nonroot.cron /etc/crontabs/librenms && \
	sed -i -e 's/ librenms //' /etc/crontabs/librenms && \
	sed -i 's/^#\($config\['"'"'update'"'"'\].*\)/\1/' "$librenms_base/config.php"

# install php dependencies with composer
RUN sudo -u librenms ./scripts/composer_wrapper.php install --no-dev --no-scripts

COPY services /etc/sv
COPY docker-entrypoint.sh /
COPY nginx-librenms.conf /etc/nginx/conf.d/librenms.conf
COPY php-librenms.conf /etc/php7/php-fpm.d/librenms.conf

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "runsvdir", "-P /etc/sv" ]

EXPOSE 80
VOLUME ["$librenms_base/logs", "$librenms_base/rrd", "$librenms_base/storage"]
