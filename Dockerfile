FROM alpine:3.5
LABEL version="1.26" \
	description="librenms container with alpine" \
	maintainer="Veovis <veovis@kveer.fr>"
EXPOSE 80
RUN apk update --no-cache && \
	apk upgrade --no-cache && \
	apk add --no-cache \
	php7 \
	php7-mysqli \
	php7-gd \
	php7-snmp \
	php7-pear \
	php7-curl \
	php7-fpm \
	php7-mcrypt \
	php7-json \
	net-snmp \
	graphviz \
	nginx \
	fping \
	imagemagick \
	whois \
	nmap \
	rrdtool \
	git \
	curl \
	runit \
	dcron \
	mtr && \
	mkdir -p /opt && \
	curl --progress-bar -L 'https://github.com/librenms/librenms/archive/1.26.tar.gz' | tar -zx -f - -C /opt && \
	mv /opt/librenms-1.26 /opt/librenms && \
	adduser -D -h /opt/librenms librenms && \
	install -m 775 -d /opt/librenms/rrd && \
	install -d /opt/librenms/logs && \
	cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf && \
	curl -o /usr/local/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro && \
	chmod +x /usr/local/bin/distro && \
	cp /opt/librenms/librenms.nonroot.cron /etc/crontabs/librenms && \
	sed -i -e 's/ librenms //' /etc/crontabs/librenms && \
	rm /etc/nginx/conf.d/default.conf && \
	apk del git curl

WORKDIR /
COPY services/runit-* /etc/service/
COPY runit-bootstrap /usr/sbin/
COPY nginx-librenms.conf /etc/nginx/conf.d/
RUN chmod 755 /usr/sbin/runit-bootstrap

VOLUME ["/opt/librenms/logs", "/opt/librenms/rrd"]
CMD ["/usr/sbin/runit-bootstrap"]
