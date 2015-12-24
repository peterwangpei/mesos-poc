#!/bin/bash
set -e -m

API_PORT=${API_PORT:-8080}
API_HOST=${API_HOST:-127.0.0.1}
TEMPLATE_FILE=${TEMPLATE_FILE:-/template.cfg}
CONFIG_FILE=${CONFIG_FILE:-/etc/haproxy/haproxy.cfg}

echo python ./loadbalancer.py -s ${API_HOST}:${API_PORT} -t ${TEMPLATE_FILE} -c ${CONFIG_FILE}
python ./loadbalancer.py -s ${API_HOST}:${API_PORT} -t ${TEMPLATE_FILE} -c ${CONFIG_FILE}