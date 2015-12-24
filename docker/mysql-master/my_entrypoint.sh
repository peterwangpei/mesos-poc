#!/bin/bash
set -e -m

echo "start configurating mysql database"
source /entrypoint.sh &
sleep 20s
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT SELECT,REPLICATION SLAVE ON *.* TO 'peter'@'%' IDENTIFIED BY '123456';"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE demo; CREATE TABLE demo.users(user_id INT(4) PRIMARY KEY NOT NULL AUTO_INCREMENT, user_name VARCHAR(40), user_pass VARCHAR(40), email VARCHAR(100));"

echo "end configurating mysql database"
fg
