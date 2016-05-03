#!/bin/bash

mkdir -p /srv/salt-overlay/pillar
cat <<EOF > /srv/salt-overlay/pillar/cluster-params.sls
instance_prefix: '($echo "$INSTANCE_PREFIX" | sed -e "s/'/''/g")'
node_instance_prefix: $NODE_INSTANCE_PREFIX
service_cluster_ip_range: $SERVICE_CLUSTER_IP_RANGE
admission_control: '$(echo "$ADMISSION_CONTROL" | sed -e "s/'/''/g")'
enable_cluster_dns: '$(echo "$ENABLE_CLUSTER_DNS" | sed -e "s/'/''/g")'
dns_server: '$(echo "$DNS_SERVER" | sed -e "s/'/''/g")'
dns_domain: '$(echo "$DNS_DOMAIN" | sed -e "s/'/''/g")'
dns_replicas: '$(echo "$DNS_REPLICAS" | sed -e "s/'/''/g")'
master_floating_ip: '$(echo "$MASTER_FLOATING_IP" | sed -e "s/'/''/g")'
ops_server_ip: '$(echo "$OPS_SERVER_IP" | sed -e "s/'/''/g")'
docker_opts: '$(echo "$DOCKER_OPTS" | sed -e "s/'/''/g")'
http_proxy: '$(echo "$HTTP_PROXY" | sed -e "s/'/''/g")'
etcd_out: '$ETCD_OUT'
EOF

if [ "xtrue" == "x${USE_KUBEMARK}" ]; then
    echo "user_kubemark: 'true'" >> /srv/salt-overlay/pillar/cluster-params.sls
    echo "num_nodes: ${NUM_NODES:-20}" >> /srv/salt-overlay/pillar/cluster-params.sls
fi

known_tokens_file="/srv/salt-overlay/salt/kube-apiserver/known_tokens.csv"

if [[ ! -f "${known_tokens_file}" ]]; then
    mkdir -p /srv/salt-overlay/salt/kube-apiserver
    (umask u=rw,go= ;
     echo "$KUBELET_TOKEN,kubelet,kubelet" > $known_tokens_file
     echo "$KUBE_PROXY_TOKEN,kube_proxy,kube_proxy" >> $known_tokens_file)

    mkdir -p /srv/salt-overlay/salt/kubelet
    kubelet_kubeconfig_file="/srv/salt-overlay/salt/kubelet/kubeconfig"
    cert_dir=${CERT_DIR:-/srv/kubernetes}
    (umask 077;
     cat > "${kubelet_kubeconfig_file}" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${cert_dir}/ca.crt
  name: local
contexts:
- context:
    cluster: local
    user: kubelet
  name: service-account-context
current-context: service-account-context
users:
- name: kubelet
  user:
    client-certificate: ${cert_dir}/kubecfg.crt
    client-key: ${cert_dir}/kubecfg.key
EOF
    )

    mkdir -p /srv/salt-overlay/salt/kube-proxy
    kube_proxy_kubeconfig_file="/srv/salt-overlay/salt/kube-proxy/kubeconfig"

    (umask 077;
     cat > "${kube_proxy_kubeconfig_file}" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${cert_dir}/ca.crt
  name: local
contexts:
- context:
    cluster: local
    user: kube-proxy
  name: service-account-context
current-context: service-account-context
users:
- name: kube-proxy
  user:
    client-certificate: ${cert_dir}/kubecfg.crt
    client-key: ${cert_dir}/kubecfg.key
EOF
    )

    service_accounts=("system:scheduler" "system:controller_manager" "system:dns")
    for account in "${service_accounts[@]}"; do
        token=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
        echo "${token},${account},${account}" >> ${known_tokens_file}
    done
fi

readonly BASIC_AUTH_FILE="/srv/salt-overlay/salt/kube-apiserver/basic_auth.csv"
if [ ! -e "${BASIC_AUTH_FILE}" ]; then
    mkdir -p /srv/salt-overlay/salt/kube-apiserver
    (umask 077;
     echo "${KUBE_PASSWORD},${KUBE_USER},admin" > "${BASIC_AUTH_FILE}"
    )
fi
