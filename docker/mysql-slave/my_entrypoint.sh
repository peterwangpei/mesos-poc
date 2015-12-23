#!/bin/bash
set -e -m

echo "start configurating mysql database"
source /entrypoint.sh &
sleep 20s
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "drop database mysql; CHANGE MASTER TO MASTER_HOST='${MYSQL_MASTER_SERVICE_HOST}', MASTER_USER='peter', MASTER_PASSWORD='123456'; start slave;"

echo "end configurating mysql database"
fg
