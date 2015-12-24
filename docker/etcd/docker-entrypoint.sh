#!/bin/bash
set -e -m

if [ "${1:0:1}" = '-' ]; then
    set -- etcd "$@"
elif [[ -n $@ ]]; then
    set -- etcd
fi

#run command in background
if [ "$1" = 'etcd' ]; then

    if [ -z $ETCD_DATA_DIR ]; then
        EXPORT ETCD_DATA_DIR=/var/lib/etcd
    fi

    mkdir -p $ETCD_DATA_DIR
    
    exec "$@" &

    fg
else
    exec "$@"
fi
