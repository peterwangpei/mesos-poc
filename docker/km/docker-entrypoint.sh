#!/bin/bash
set -e -m

wait_for_url() {
  
    local url=$1
    local prefix=${2:-}
    local wait=${3:-0.5}
    local times=${4:-25}

    local i
    for i in $(seq 1 $times); do
        
        local out
        if out=$(curl -fs $url 2>/dev/null); then
          echo "On try ${i}, ${prefix}: ${out}"
          return 0
        fi
        sleep ${wait}
    done
    echo "Timed out waiting for ${prefix} to answer at ${url}; tried ${times} waiting ${wait} between each"
    return 1
}

prepare_cloud_config() {
  if [ ! -f ${CLOUD_CONFIG} ];then
`cat >mesos-cloud.conf <<EOF
[mesos-cloud]
  mesos-master = ${MESOS_MASTER}
EOF`
  fi
}

start_etcd() {
    mkdir -p ${ETCD_DATA_DIR}

    etcd \
        -data-dir ${ETCD_DATA_DIR} \
        --bind-addr ${ETCD_HOST}:${ETCD_PORT} >${LOG_PATH}/etcd.log 2>&1 &

    wait_for_url "http://${ETCD_HOST}:${ETCD_PORT}/v2/machines" "etcd: " 0.25 80 || exit 1
}

start_apiserver() {
    prepare_cloud_config

    km apiserver \
        --address=${KUBERNETES_MASTER_IP} \
        --port=${KUBERNETES_MASTER_PORT} \
        --etcd-servers=${ETCD_SERVERS} \
        --service-cluster-ip-range=10.10.10.0/24 \
        --cloud-provider={CLOUD_PROVIDER} \
        --cloud-config={CLOUD_CONFIG} \
        --secure-port=0 \
        --v=${LOG_LEVEL} >${LOG_PATH}/apiserver.log 2>&1 &
}

start_controller() {
    prepare_cloud_config

    km controller-manager \
        --master=${KUBERNETES_MASTER_IP}:${KUBERNETES_MASTER_PORT} \
        --cloud-provider=${CLOUD_PROVIDER} \
        --cloud-config=${CLOUD_CONFIG}  \
        --v=${LOG_LEVEL} >${LOG_PATH}/controller.log 2>&1 &
}

start_scheduler() {
    km scheduler \
        --address=${KUBERNETES_MASTER_IP} \
        --mesos-master=${MESOS_MASTER} \
        --etcd-servers=${ETCD_SERVERS} \
        --mesos-user=root \
        --api-servers=${KUBERNETES_MASTER_IP}:${KUBERNETES_MASTER_IP} \
        --cluster-dns=10.10.10.10 \
        --cluster-domain=cluster.local \
        --v=${LOG_LEVEL} >${LOG_PATH}/scheduler.log 2>&1 &
}

ETCD_HOST=${ETCD_HOST:-0.0.0.0}
ETCD_PORT=${ETCD_PORT:-4001}
ETCD_DATA_DIR=${ETCD_DATA_DIR-/var/lib/etcd}
ETCD_SERVERS=${ETCD_SERVERS:-http://${ETCD_HOST}:${ETCD_PORT}}
MESOS_MASTER=${MESOS_MASTER:-zk://zookeeper:2181/mesos}
CLOUD_CONFIG=${CLOUD_CONFIG:-/mesos.conf}
KUBERNETES_MASTER_IP=${KUBERNETES_MASTER_IP:-0.0.0.0}
KUBERNETES_MASTER_PORT=${KUBERNETES_MASTER_PORT:-8080}
LOG_LEVEL=${LOG_LEVEL:-3}
LOG_PATH=${LOG_PATH:-/var/log}
CLOUD_PROVIDER=${CLOUD_PROVIDER:-"mesos"}

if [[ "$1" = "apiserver" ]]; then
  echo "start apiserver"
  start_apiserver
  fg
elif [[ "$1" = "controller" ]]; then
  echo "start controller manager"
  start_controller
  fg
elif [[ "$1" = "scheduler" ]]; then
  echo "start scheduler"
  start_scheduler
  fg
elif [[ "$1" = "etcd" ]]; then
  echo "start etcd"
  start_etcd
  fg
else
  echo "start all in one"
  start_etcd
  start_apiserver
  start_controller
  start_scheduler
  fg
fi