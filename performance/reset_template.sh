#!/usr/bin/env bash

API_SERVER=${API_SERVER:-"{API_SERVER}"}
CONCURRENT=${CONCURRENT:-{CONCURRENT}}
KUBECTL=${KUBECTL:-"{KUBECTL}"}
RC_NAME=${RC_NAME:-"{RC_NAME}"}
NAMESPACE=${NAMESPACE:-"{NAMESPACE}"}

if [ -z "$API_SERVER" ]; then
    API_SERVER="192.168.0.101:8080"
fi

if [ -z "$CONCURRENT" ]; then
    CONCURRENT=100
fi

if [ -z "$KUBECTL" ]; then
    KUBECTL="./kubectl"
fi

if [ -z "$RC_NAME" ]; then
    RC_NAME="performance"
fi

if [ -z "$NAMESPACE" ]; then
    NAMESPACE="demo"
fi

#loop to kill all test namespace and rc
for index in $(seq $CONCURRENT)
do
    #Kill all python process
    killall python
    #kill rc
    $KUBECTL -s $API_SERVER --namespace=$NAMESPACE delete rc $RC_NAME
    #kill namespace
    $KUBECTL -s $API_SERVER --namespace=$NAMESPACE delete namespace $NAMESPACE
done