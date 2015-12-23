#!/bin/bash

echo load haproxy pid
pid=`cat /var/run/haproxy.pid`

echo "Reload haproxy"
haproxy -f $1 -p /var/run/haproxy.pid -sf ${pid}
