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

function print_success {
cat <<EOF
Local Kubernetes cluster is running. Press Ctrl-C to shut it down.

Logs:
  ${APISERVER_LOG}
  ${CTLRMGR_LOG}
  ${PROXY_LOG}
  ${SCHEDULER_LOG}
  ${KUBELET_LOG}

To start using your cluster, open up another terminal/tab and run:

  cluster/kubectl.sh config set-cluster local --server=http://${API_HOST}:${API_PORT} --insecure-skip-tls-verify=true
  cluster/kubectl.sh config set-context local --cluster=local
  cluster/kubectl.sh config use-context local
  cluster/kubectl.sh
EOF
}

start_etcd() {

    mkdir -p ${ETCD_DATA_DIR}

    etcd -data-dir ${ETCD_DATA_DIR} --bind-addr ${ETCD_HOST}:${ETCD_PORT} >/dev/null 2>/dev/null &

    echo "Waiting for etcd to come up."
    wait_for_url "http://${ETCD_HOST}:${ETCD_PORT}/v2/machines" "etcd: " 0.25 80 || exit 1
}

function start_apiserver {
    
    if [[ ! -f "${SERVICE_ACCOUNT_KEY}" ]]; then
      mkdir -p "$(dirname ${SERVICE_ACCOUNT_KEY})"
      openssl genrsa -out "${SERVICE_ACCOUNT_KEY}" 2048 2>/dev/null
    fi

    if [[ -z "${ALLOW_SECURITY_CONTEXT}" ]]; then
      ADMISSION_CONTROL=NamespaceLifecycle,NamespaceAutoProvision,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota
    else
      ADMISSION_CONTROL=NamespaceLifecycle,NamespaceAutoProvision,LimitRanger,ServiceAccount,ResourceQuota
    fi

    ADMISSION_CONTROL=AlwaysAdmit

    #demo code
    #ADMISSION_CONTROL=AlwaysAdmit

    # This is the default dir and filename where the apiserver will generate a self-signed cert
    # which should be able to be used as the CA to verify itself
    CERT_DIR=/var/run/kubernetes
    ROOT_CA_FILE=$CERT_DIR/apiserver.crt

    if [[ -n "${ALLOW_PRIVILEGED}" ]]; then
      priv_arg="--allow-privileged "
    fi
    runtime_config=""
    if [[ -n "${RUNTIME_CONFIG}" ]]; then
      runtime_config="--runtime-config=${RUNTIME_CONFIG}"
    fi

      #--insecure-bind-address="${API_HOST}" \
      #--insecure-port="${API_PORT}" \
      #--service-account-key-file="${SERVICE_ACCOUNT_KEY}" \
      #--service-account-lookup="${SERVICE_ACCOUNT_LOOKUP}" \

    APISERVER_LOG=${LOG_PATH}/kube-apiserver.log
    sudo -E "${MASTER_PATH}/kube-apiserver" \ #${priv_arg} ${runtime_config} \
      --address=${API_HOST} \
      --port=${API_PORT} \
      --secure-port=0 \
      --v=${LOG_LEVEL} \
      --etcd-servers="http://${ETCD_HOST}:${ETCD_PORT}" \
      --service-cluster-ip-range="10.0.0.0/24" \
      --admission-control="${ADMISSION_CONTROL}" >"${APISERVER_LOG}" 2>&1 &
      
    # Wait for kube-apiserver to come up before launching the rest of the components.
    echo "Waiting for apiserver to come up"
    wait_for_url "http://${API_HOST}:${API_PORT}/api/v1/pods" "apiserver: " 1 10 || exit 1
}

      #--service-account-private-key-file="${SERVICE_ACCOUNT_KEY}" \
function start_controller_manager {
    CTLRMGR_LOG=${LOG_PATH}/kube-controller-manager.log
    sudo -E "${MASTER_PATH}/kube-controller-manager" \
      --v=${LOG_LEVEL} \
      --master="${API_HOST}:${API_PORT}" >"${CTLRMGR_LOG}" 2>&1 &
}

function start_scheduler {
    SCHEDULER_LOG=${LOG_PATH}/kube-scheduler.log
    sudo -E "${MASTER_PATH}/kube-scheduler" \
      --v=${LOG_LEVEL} \
      --master="${API_HOST}:${API_PORT}" >"${SCHEDULER_LOG}" 2>&1 &
}

function start_proxy {
    PROXY_LOG=${LOG_PATH}/kube-proxy.log
    sudo -E "${WORKER_PATH}/kube-proxy" \
      --v=${LOG_LEVEL} \
      --master="http://${API_HOST}:${API_PORT}" >"${PROXY_LOG}" 2>&1 &
}
 #     --hostname-override="${HOST_NAME_OVERRIDE}" \
#      --allow-privileged=false \
function start_kubelet {
    KUBELET_LOG=${LOG_PATH}/kubelet.log
    sudo -E "${WORKER_PATH}/kubelet" \
      --v=${LOG_LEVEL} \
      --container-runtime="${CONTAINER_RUNTIME}" \
      --api-servers="${API_HOST}:${API_PORT}" \
      --containerized=true \
      --resource-container="" \
      --port="$KUBELET_PORT" ${KUBELET_ARGS} >"${KUBELET_LOG}" 2>&1 &
}

HOST_NAME_OVERRIDE=${HOST_NAME_OVERRIDE:""}
SERVICE_ACCOUNT_LOOKUP=${SERVICE_ACCOUNT_LOOKUP:-false}
SERVICE_ACCOUNT_KEY=${SERVICE_ACCOUNT_KEY:-"/host.key"}
MASTER_PATH=${MASTER_PATH:-/kube-master}
WORKER_PATH=${WORKER_PATH:-/kube-worker}
ETCD_HOST=${ETCD_HOST:-127.0.0.1}
ETCD_PORT=${ETCD_PORT:-4001}
ETCD_DATA_DIR=${ETCD_DATA_DIR-/var/lib/etcd}
API_PORT=${API_PORT:-8080}
API_HOST=${API_HOST:-0.0.0.0}
API_CORS_ALLOWED_ORIGINS=${API_CORS_ALLOWED_ORIGINS:-"/127.0.0.1(:[0-9]+)?$,/localhost(:[0-9]+)?$"}
LOG_LEVEL=${LOG_LEVEL:-3}
LOG_PATH=${LOG_PATH:-/var/log}
KUBELET_PORT=${KUBELET_PORT:-10250}
KUBELET_ARGS=${KUBELET_ARGS:-""}
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-"docker"}
RUNTIME_CONFIG=${RUNTIME_CONFIG:-""}

if [ "$1" = "master" ]; then
  echo "start master"
  echo "start etcd"
  start_etcd
  echo "start apiserver"
  start_apiserver
  echo "start controller manager"
  start_controller_manager
  echo "start scheduler"
  start_scheduler
  echo "kubernete master is running"
  fg
elif [ "$1" = "worker" ]; then
  echo "start worker"
  echo "start proxy"
  start_proxy
  echo "start kubelet"
  start_kubelet
  echo "kubernete worker is running"
  fg
fi
 