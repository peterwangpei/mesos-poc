#!/bin/bash
set -e -m

echo "start configurating mysql database"
source /entrypoint.sh &
sleep 20s
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT SELECT,REPLICATION SLAVE ON *.* TO 'peter'@'%' IDENTIFIED BY '123456';"

echo "end configurating mysql database"
fg
