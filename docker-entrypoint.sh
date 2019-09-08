#!/bin/sh

# setting the timezone
[ -n $TZ ] || TZ=Europe/Paris
cp /usr/share/zoneinfo/$TZ /etc/localtime
echo "$TZ" >> /etc/timezone
sed -i -e "s!^;\?\(date.timezone\).*!\1 = $TZ!" /etc/php7/php.ini

# setting MYSQL_PASS from MYSQL_PASS_FILE if set
if [ -f "$MYSQL_PASS_FILE" ]; then
	export DB_PASSWORD=$(cat "$MYSQL_PASS_FILE")
fi

librenms_base=/opt/librenms
librenms_config="$librenms_base/config.php"

# to assure compatibility
[ -f "$librenms_base/.env" ] || sudo -u librenms touch "$librenms_base/.env"
sed -i -e '/^\(DB_|APP\)/d' -e '/^APP_/d' "$librenms_base/.env"
sed -i -e "/^\$config\['db_.*/d" "$librenms_config"

# settings the memcache
librenms_config_memcache="$librenms_base/config.d/_memcache.php"
if [ ! -z "MEMCACHE_HOST" ]; then
	install -d -o librenms -g librenms `dirname $librenms_config_memcache`
	cat > "$librenms_config_memcache" <<EOF
<?php
\$config['memcached']['enable'] = true;
\$config['memcached']['host'] = '$MEMCACHE_HOST';
\$config['memcached']['port'] = 11211;
EOF
	chown librenms:librenms "$librenms_config_memcache"
else
	[ -f "$librenms_config_memcache" ] && rm "$librenms_config_memcache"
fi

# TODO: checks that we have all necessary ENV variables

# waiting for mysql to be up
# https://stackoverflow.com/a/37300565/878381
until nc -z -v -w30 $DB_HOST 3306
do
  echo "Waiting 5 seconds for mysql to be ready..."
  # wait for 5 seconds before check again
  sleep 5
done

# unsetting sensitive variables
unset MYSQL_PASS_FILE

# exporting variables to be availables to services
export > /etc/envvars
[ ! -f /etc/envvars ] && echo "/etc/envvars does not exists" && exit

# initializes the database if empty
mysql_cmd="mysql -h $DB_HOST -u "$DB_USERNAME" "-p$DB_PASSWORD" -B"

tables=$(echo 'SHOW TABLES' | $mysql_cmd --database "$DB_DATABASE" | wc -l)
if [ "$tables" -eq '0' ]; then

	echo Creating initial sql schema
	(echo $new_sql_mode; cat "$librenms_base/build.sql") | $mysql_cmd --database "$DB_DATABASE"

	# it seems the order is alphabetical
	# i'm note very sure of that certainty
	for i in `ls "$librenms_base"/sql-schema/*.sql | sort`; do
		echo Updating schema with $i
		(echo $new_sql_mode; cat "$i") | $mysql_cmd --database "$DB_DATABASE"
	done

	$mysql_cmd --database "$DB_DATABASE" -e 'ALTER TABLE `ports_fdb` DROP INDEX `mac_address_2`' 2> /dev/null
	$mysql_cmd --database "$DB_DATABASE" -e 'ALTER TABLE `users` DROP `remeber_token`' 2> /dev/null

	# creating the first user
	echo Creating the first user
	cd "$librenms_base"
	php adduser.php librenms librenms 10 admin@librenms.local
	echo Your credentials: librenms / librenms
fi

cd "$librenms_base"

# ensure $librenms_base/storage is suitable
install -d -o librenms -g librenms $librenms_base/framework/cache
install -d -o librenms -g librenms $librenms_base/framework/sessions
install -d -o librenms -g librenms $librenms_base/framework/testing
install -d -o librenms -g librenms $librenms_base/framework/views

# run the post-install scripts
sudo -u librenms ./scripts/composer_wrapper.php install --no-dev

# update the database schema
sudo -u librenms ./daily.sh

exec $@
