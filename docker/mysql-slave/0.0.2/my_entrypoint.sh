#!/bin/bash
set -e -m

echo "start configurating mysql database"
source /entrypoint.sh &

mysql=( mysql -uroot -p${MYSQL_ROOT_PASSWORD} )
mysqlpeter=( mysql -upeter -p123456 )
sleep 20s
for i in {1..15}
do
  echo "connect to mysql: $i"
  if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null;
  then
    echo "start running in slave mode"
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CHANGE MASTER TO MASTER_HOST='${MYSQL_MASTER_SERVICE_HOST}', MASTER_USER='peter', MASTER_PASSWORD='123456'; START SLAVE;"
    break
  elif echo 'SELECT 1' | "${mysqlpeter[@]}" &> /dev/null;
  then
    break
  else
    sleep 1m
  fi
done

echo "end configurating mysql database"
fg
