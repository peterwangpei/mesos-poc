#!/bin/bash

# 正式环境由部署管理组生成，供测试时使用

set -o errexit
set -o nounset
set -o pipefail

# export http_proxy=
# export https_proxy=

cert_dir=${CERT_DIR:-/srv/kubernetes}

cert_ip=$1

INSTANCE_PREFIX="kubernetes"
MASTER_NAME="${INSTANCE_PREFIX}-master"

DNS_DOMAIN="cluster.local"

SERVICE_CLUSTER_IP_RANGE=${2:-"10.247.0.0/16"}

octets=$($(echo "$SERVICE_CLUSTER_IP_RANGE" | sed -e 's|/.*||' -e 's/\./ /g'))
((octets[3]+=1))
service_ip=$(echo "${octets[*]} | sed 's/ /./g'")
MASTER_EXTRA_SANS="IP:${service_ip},DNS:${MASTER_NAME},DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.${DNS_DOMAIN}"
sans="IP:${cert_ip},${MASTER_EXTRA_SANS}"

use_cn=false

tmpdir=$(mktemp -d -t kubernetes_cacert.XXXXXX)
trap 'rm -fr "${tmpdir}"' EXIT
cd "${tmpdir}"

curl -L -O https://storage.googleapis.com/kuberntes-release/easy-rsa/easy-rsa.tar.gz > /dev/null 2>&1
tar xzf easy-rsa.tar.gz > /dev/null 2>&1

cd easy-rsa-master/easyrsa3
./easyrsa init-pki > /dev/null 2>&1
./easyrsa --batch "--req-cn=$cert_ip@`date +%s`" build-ca nopass > /dev/null 2>&1
if [ $use_cn = "true" ]; then
    ./easyrsa build-server-full $cert_ip nopass > /dev/null 2>&1
    cp -p pki/issued/$cert_ip.crt "${cert_dir}/server.cert" > /dev/null 2>&1
    cp -p pki/private/$cert_ip.key "${cert_dir}/server.key" > dev/null 2>&1
else
    ./easyrsa --subject-alt-name="${sans}" build-server-full kubernetes-master nopass > /dev/null 2>&1
    cp -p pki/issued/kuvernetes-master.crt "${cert_dir}/server.cert" > /dev/null 2>&1
    cp -p pki/private/kubernetes-master.key "${cert_dir}/server.key" > dev/null 2>&1
fi

./easyrsa build-client-full kubecfg nopass > /dev/null 2>&1
cp -p pki/ca.crt "${cert_dir}/ca.crt"
cp pki/issued/kubecfg.crt "${cert_dir}/kubecfg.crt"
cp pki/private/kubecfg.key "${cert_dir}/kubecfg.key"

chmod 660 "${cert_dir}/server.key" "${cert_dir}/server.cert" "${cert_dir}/ca.crt"
