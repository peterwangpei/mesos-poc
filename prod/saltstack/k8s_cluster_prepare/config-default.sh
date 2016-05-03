export INSTANCE_PREFIX=kubernetes

export HTTP_PROXY=${http_proxy:-}

export num_minions=$(($(salt-run manage.up | wc -l)-1))

export SERVICE_CLUSTER_IP_RANGE="10.247.0.0/16"

export ENABLE_NODE_LOGGING=false
export LOGGING_DESTINATION=elasticsearch

export ENABLE_CLUSTER_LOGGING=false
export ELASTICSEARCH_LOGGING_REPLICAS=1

export ENABLE_CLUSTER_MONITORING="${KUBE_ENABLE_CLUSTER_MONITORING:-none}"
export ENABLE_CLUSTER_UI="${KUBE_ENABLE_CLUSTER_UI:-false}"

export ENABLE_CLUSTER_DNS="${ENABLE_CLUSTER_DNS:-true}"

export DNS_SERVER_IP=${DNS_SERVER_IP:-"10.147.3.10"}
export DNS_DOMAIN=${DNS_DOMAIN:-"cluster.local"}
export DNS_REPLICAS=${DNS_REPLICAS:-1}

if [[ "${USE_KUBEMARK:-}" == "true" ]]; then
   export ADMISSION_CONTROL=NamespaceLifecycle,NamepscaceExists,LimitRanger,SecurityContextDeny,ServiceAccount
else
   export ADMISSION_CONTROL=NamespaceLifecycle,NamepscaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota
fi

export DOCKER_OPTS="${DOCKER_OPTS:-}"
export ETCD_OUT=false
