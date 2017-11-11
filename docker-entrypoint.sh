#!/bin/sh

# setting the timezone
cp /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo "$TIMEZONE" >> /etc/timezone

# setting MYSQL_PASS from MYSQL_PASS_FILE if set
if [ -f "$MYSQL_PASS_FILE" ]; then
	MYSQL_PASS=$(cat "$MYSQL_PASS_FILE")
fi

librenms_base=/opt/librenms
librenms_config="$librenms_base/config.php"

# setting mysql access for librenms
sed -i -e "s!^;\?\(date.timezone\).*!\1 = $TIMEZONE!" /etc/php7/php.ini
sed -i -e "s/^\(\$config\['db_host'\]\).*/\1 = '$MYSQL_HOST';/" "$librenms_config"
sed -i -e "s/^\(\$config\['db_user'\]\).*/\1 = '$MYSQL_USER';/" "$librenms_config"
sed -i -e "s/^\(\$config\['db_pass'\]\).*/\1 = '$MYSQL_PASS';/" "$librenms_config"
sed -i -e "s/^\(\$config\['db_name'\]\).*/\1 = '$MYSQL_NAME';/" "$librenms_config"

# settings the memcache
librenms_config_memcache="$librenms_base/config.d/_memcache.php"
if [ ! -z "MEMCACHE_HOST" ]; then
	cat > "$librenms_config_memcache" <<EOF
<?php
\$config['memcached']['enable'] = true;
\$config['memcached']['host'] = '$MEMCACHE_HOST';
\$config['memcached']['port'] = 11211;
EOF
else
	[ -f "$librenms_config_memcache" ] && rm "$librenms_config_memcache"
fi

# TODO: checks that we have all necessary ENV variables

# waiting for mysql to be up
# https://stackoverflow.com/a/37300565/878381
until nc -z -v -w30 $MYSQL_HOST 3306
do
  echo "Waiting 5 seconds for mysql to be ready..."
  # wait for 5 seconds before check again
  sleep 5
done

# initializes the database if empty
mysql_cmd="mysql -h $MYSQL_HOST -u "$MYSQL_USER" "-p$MYSQL_PASS" -B"

# unsetting sensitive variables
unset MYSQL_PASS
unset MYSQL_PASS_FILE

# exporting variables to be availables to services
export > /etc/envvars
[ ! -f /etc/envvars ] && echo "/etc/envvars does not exists" && exit

tables=$(echo 'SHOW TABLES' | $mysql_cmd "$MYSQL_NAME" | wc -l)
if [ "$tables" -eq '0' ]; then

	# as of 1.26, librenms can't use MySQL with STRICT_TRANS_TABLES, which is included by default in mysql 5.7
	# this piece of code temporary remove the STRICT_TRANS_TABLES from sql_mode during the database creation
	sql_mode=$($mysql_cmd -e 'select @@GLOBAL.sql_mode;' | tail -n 1)
	if [ "${sql_mode#*STRICT_TRANS_TABLES}" != "$sql_mode" ]; then
		new_sql_mode="SET SESSION sql_mode = '$(echo $sql_mode | sed -e 's/STRICT_TRANS_TABLES//' -e 's/,,/,/')';"
	else
		new_sql_mode=
	fi

	echo Creating initial sql schema
	(echo $new_sql_mode; cat "$librenms_base/build.sql") | $mysql_cmd "$MYSQL_NAME"

	# it seems the order is alphabetical
	# i'm note very sure of that certainty
	for i in `ls "$librenms_base"/sql-schema/*.sql | sort`; do
		echo Updating schema with $i
		(echo $new_sql_mode; cat "$i") | $mysql_cmd "$MYSQL_NAME"
	done

	# creating the first user
	echo Creating the first user
	cd "$librenms_base"
	php adduser.php librenms librenms 10 admin@librenms.local
	echo Your credentials: librenms / librenms
fi

exec $@
