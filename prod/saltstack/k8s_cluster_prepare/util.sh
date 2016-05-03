KUBE_ROOT=$(dirname "${BASH_SOURCE}")../..
source "${KUBE_ROOT}/cluster/${KUBERNETES_PROVIDER}/${KUBE_CONFIG_FILE-"config-default.sh"}"
source "${KUBE_ROOT}/cluster/common.sh"


function verify-prereqs {
    echo "===> verify-prereqs: TODO"
}

function ensure-temp-dir {
    if [[ -z ${KUBE_SALT_TEMP-} ]]; then
        KUBE_SALT_TEMP=$(mktemp -d -t kubernetes.salt.XXXXXX)
        echo "KUBE_SALT_TEMP:${KUBE_SALT_TEMP}"
    fi
}

function unpack-release-tars {
    SERVER_BINARY_TAR="${KUBE_ROOT}/server/kubernetes-server-linux-amd64.tar.gz"
    if [[ ! -f "$SERVER_BINARY_TAR"  ]]; then
        SERVER_BINARY_TAR="${KUBE_ROOT}/_output/release-tars/kubernetes-server-linux-amd64.tar.gz"
    fi

    if [[ ! -f "$SERVER_BINARY_TAR"  ]]; then
        echo "!!! Cannot find kubernetes-server-linux-amd64.tar.gz"
        exit 1
    fi

    SALT_TAR="${KUBE_ROOT}/server/kubernetes-salt.tar.gz"
    if [[ ! -f "$SALT_TAR" ]]; then
        SALT_TAR="${KUBE_ROOT}/_output/release-tars/kubernetes-salt.tar.gz"
    fi

    if [[ ! -f "$SALT_TAR" ]]; then
        echo "!!! Cannot find kubernetes-salt.tar.gt"
        exit 1
    fi

    echo "Unpacking Salt tree"
    tar xzf "${SALT_TAR}" -C ${KUBE_SALT_TEMP}

    echo "Running release install script"
    sudo ${KUBE_SALT_TEMP}/kubernetes/saltbase/install.sh "${SERVER_BINARY_TAR}"
}

function detect-minions() {
    echo "===> TODO: Detect Minions"
}

function detect-master() {
    echo "===> Detect Master"
}

function get-password {
    get-kubeconfig-basicauth
    if [[ -z "${KUBE_USER}" || -z "${KUBE_PASSWORD}"  ]]; then
        export KUBE_USER=admin
        export KUBE_PASSWORD=$(python -c 'import string,random; print("".join(random.SystemRandom().choice(string.ascii_letters + string.digits) for _ in range(16)))')
    fi
}

function define-envs {
    export INSTANCE_PREFIX=${INSTANCE_PREFIX}
    export NODE_INSTANCE_PREFIX=${NODE_INSTANCE_PREFIX}
    export SERVICE_CLUSTER_IP_RANGE=${SERVICE_CLUSTER_IP_RANGE}
    export ADMISSION_CONTROL=${ADMISSION_CONTROL:-}
    export KUBELET_TOKEN=${KUBELET_TOKEN:-}
    export KUBE_PROXY_TOKEN=${KUBE_PROXY_TOKEN:-}
    export KUBE_USER=${KUBE_USER:-}
    export KUBE_PASSWORD=${KUBE_PASSWORD:-}
    export HTTP_PROXY=${HTTP_PROXY:-}
    export HTTPS_PROXY=${HTTPS_PROXY:-}
    export ENABLE_CLUSTER_DNS=${ENABLE_CLUSTER_DNS}
    export DNS_SERVER_IP=${DNS_SERVER_IP}
    export DNS_DOMAIN=${DNS_DOMAIN}
    export DNS_REPLICAS=${DNS_REPLICAS}
}

function kube-up {
    ensure-temp-dir

    get-password
    get-token

    define-envs

    bash ${kube_root}/cluster/${KUBERNETES_PROVIDER}/create-dynamic-salt-files.sh

    unpack-release-tars
}

function kube-down {
    echo "===> TODO: Bringing down cluster"
}

function validate-cluster {
    echo "===> TODO: validate cluster"
}

function test-build-release {
    "${kube_root}/build/release.sh"
}

function ssh-to-node {
    local node="$1"
    local cmd="$2"
    ssh --ssh_arg "-o LogLevel=quiet" "${node}" "${cmd}"
}

function restart-kube-proxy {
    ssh-to-node "$1" "sudo /etc/init.d/kube-proxy restart"
}

function restart-apiserver {
    ssh-to-node "$1" "sudo /etc/init.d/kube-apiserver restart"
}

function get-tokens {
    export KUBELET_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
    export KUBE_PROXY_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
}
