#!/bin/bash
set -e -m

echo "start configurating mysql database"
source /entrypoint.sh &

mysql=( mysql -uroot -p${MYSQL_ROOT_PASSWORD} )
sleep 20s
for i in {1..15}
do
  echo "connect to mysql: $i"
  if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null;
  then
    break
  else
    sleep 1m
  fi
done

mysqlpeter=( mysql -upeter -p123456 )
if ! echo 'SELECT 1' | "${mysqlpeter[@]}" &> /dev/null;
then
  echo "start creating slave user peter and users table in demo database"
  mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT SELECT,REPLICATION SLAVE ON *.* TO 'peter'@'%' IDENTIFIED BY '123456';"
  mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE demo; CREATE TABLE demo.users(user_id INT(4) PRIMARY KEY NOT NULL AUTO_INCREMENT, user_name VARCHAR(40), user_pass VARCHAR(40), email VARCHAR(100));"
fi

echo "end configurating mysql database"
fg
