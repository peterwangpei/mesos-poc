# Kubernetes-mesos Framework 安装

[请先搭建 mesos 高可用平台](./Mesos安装.md)

参考文档
* [k8s手动安装文档](https://github.com/kubernetes/kubernetes/blob/master/docs/getting-started-guides/mesos.md)

## 搭建 etcd 集群

etcd

~~~~~~
docker pull zhpooer/etcd:v2.2.1

docker run -d \
-p 4001:4001 \
-p 2379:2379 \
-p 2380:2380 \
--name slave --restart always \
zhpooer/etcd:v2.2.1 \
-name {{hostname}} \
-advertise-client-urls http://{{ipaddr}}:2379,http://{{ipaddr}}:4001 \
-listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
-initial-advertise-peer-urls http://{{ipaddr}}:2380 \
-listen-peer-urls http://0.0.0.0:2380 \
-initial-cluster-token etcd-cluster \
-initial-cluster {{etcd_cluster}} \
-initial-cluster-state new
~~~~~~

参考可以 ansible 脚本 [prod/ansible/module/roles/etcd/tasks/main.yml](./prod/ansible/module/roles/etcd/tasks/main.yml)

参数说明

* `hostname`, 顾名思义，没有硬性规定，一般取 `etcd#{n}`
* `ipaddr`， 本机地址
* `etcd_cluster`, 所有 etcd 节点的IP地址，如  `etcd1=http://192.168.33.21:2380,etcd2=http://192.168.33.22:2380,etcd3=http://192.168.33.23:2380`

通过命令 `curl -L http://#{etcdip}:4001/v2/stats/leader`, 来查看是否安装成功



## 制作 k8s-mesos 镜像

k8s 作为 mesos 的一个 framework 运行在mesos上，所以要针对 mesos 进行编译，编译出 `km` 二进制可执行文件。

在 Ubuntu 或者 CentOs 上运行如下命令，必须先安装 Docker 和 golang 

~~~~~~
git clone https://github.com/kubernetes/kubernetes.git
cd kubernetes
git checkout $TargetTag
KUBERNETES_CONTRIB=mesos make
docker build -t kubernetes-mesos cluster/mesos/docker/km 
~~~~~~

> 构建好的包可以在 DockerHub 上得到: zhpooer/kubernetes-mesos:v1.1.3_ubuntu_14

## 搭建简单 k8s master 集群(非官方推荐)

> 简单搭建只是给搭建k8s高可用集群做一个参考，理解原理之后可以直接跳到搭建k8s高可用集群; 但是先扫一眼以下参考文档

参考文档
* [k8s-mesos 架构](https://github.com/kubernetes/kubernetes/blob/master/contrib/mesos/docs/architecture.md)
* [k8s-mesos schedule 整体说明](https://github.com/kubernetes/kubernetes/blob/master/contrib/mesos/docs/scheduler.md)
* [k8s 集群基本架构图](http://kubernetes.io/v1.0/docs/admin/high-availability.html)
* [k8s-mesos schedule 集群](https://github.com/kubernetes/kubernetes/blob/master/contrib/mesos/docs/ha.md)


整体架构图如下，每台 k8s_master 安装 api_server、controller manager， 以及 schedule (schedule 因为已经经过 mesos 重写，所以可以不用按 k8s 集群部署， 最终按 [k8s-mesos schedule 集群](https://github.com/kubernetes/kubernetes/blob/master/contrib/mesos/docs/ha.md) 来部署)



       +-----------------------+    +----------------------+                  +-------------------+
       |  api_server_haproxy   |    |      mesos master    |                  |      slave        |
       |  ceph                 |    |      zookeeper       |   x 3            +-------------------+
       |  nfs                  |    |      etcd            |
       +-----------------------+    +----------------------+
                                                                              +-------------------+
                                    +--------------------------------+        |      slave        |
                                    |      k8s_matster               |        +-------------------+
                                    |        api_server              |
                                    |        schedule                | x 3
                                    |        controller manager      |        +-------------------+
                                    +--------------------------------+        |      slave        |
                                                                              +-------------------+
     

                                                                         +-------------------+
                                                                         |      slave        |
                                                                         +-------------------+


创建文件 `/etc/kubernetes/mesos-cloud.cfg`, 内容如下

~~~~~~
[mesos-cloud]
mesos-master        = {{mesos_zk_addrs}}
http-client-timeout = 5s
state-cache-ttl     = 20s
~~~~~~

后面用到的一些变量，可用以下替换

~~~~~~
k8s_cluster_ip_range: 10.10.10.0/24
k8s_dns_server: 10.10.10.10
k8s_dns_replicas: 1
k8s_dns_domain: cluster.local
~~~~~~

### 运行 Api-server

~~~~~~
docker run --net host -v /etc/kubernetes:/etc/kubernetes \
--name kube-apiserver \
zhpooer/kubernetes-mesos:v1.1.3_ubuntu_14 \
km apiserver
--address=0.0.0.0 \
--etcd-servers={{etcd_servers}} \
--admission-control='ServiceAccount' \
--authorization-mode=AlwaysAllow \
--service-cluster-ip-range={{k8s_cluster_ip_range}} \
--port={{k8s_api_port}} \
--cloud-provider=mesos \
--cloud-config=/etc/kubernetes/mesos-cloud.cfg \
--secure-port=0
~~~~~~

### 运行 Controller Manager

必须和 api-server 运行在同一台机子上

~~~~~~
docker run --net host -v /etc/kubernetes:/etc/kubernetes \
--name kube-cm \
zhpooer/kubernetes-mesos:v1.1.3_ubuntu_14 \
km controller-manager \
--master=http://127.0.0.1:{{k8s_api_port}} \
--cloud-provider=mesos \
--cloud-config=/etc/kubernetes/mesos-cloud.cfg
~~~~~~


### 搭建 Schedule

必须和 api-server 运行在同一台机子上

~~~~~~
docker run --net host -v /etc/kubernetes:/etc/kubernetes \
--name kube-sche \
zhpooer/kubernetes-mesos:v1.1.3_ubuntu_14 \
km scheduler \
--address={{ipaddr}} \
--mesos-master={{mesos_zk_addrs}} \
--etcd-servers={{etcd_servers}} \
--mesos-user=root \
--api-servers={{k8s_api_servers}} \
--cluster-dns={{k8s_dns_server}} \
--cluster-domain={{k8s_dns_domain}}
~~~~~~

在运行完 api-server, Controller manager 以及 schedule 之后，
访问 `http://#{mesosmaster ip}:5050` 可以查看到有新的 frameworks

## 搭建 k8s-mesos 高可用（k8s 官方推荐）

可参考如下文档

* [http://kubernetes.io/v1.1/docs/admin/high-availability.html](http://kubernetes.io/v1.1/docs/admin/high-availability.html)
* [https://github.com/kubernetes/kubernetes/blob/master/contrib/mesos/docs/ha.md](https://github.com/kubernetes/kubernetes/blob/master/contrib/mesos/docs/ha.md)

本步骤需要用到的docker镜像

~~~~~~
zhpooer/kubernetes-mesos:v1.1.3_ubuntu_14
zhpooer/podmaster:1.1
zhpooer/pause:0.8.0
~~~~~~

简介： 通过 Linux 服务 `kubelet`(我们自己创建的)，监控 `/etc/kubernetes/manifests/` 下的 yalm 文件(k8s 各个组件的运行配置，用 docker 运行)，
然后 `kubelet` 会启动 k8s 的组件，如 `apiserver`、`scheduler`、`controller-manager`, 并监控他们的的运行

1. 运行以下命令

    ~~~~~~
    mkdir -p /var/log/k8s /etc/kubernetes/
    wget -c -t 0 https://storage.googleapis.com/kubernetes-release/release/v1.1.2/bin/linux/amd64/kubelet
    chmod a+x kubelet && mv kubelet /usr/local/bin/
    mkdir -p /var/log/kubernetes /etc/kubernetes/manifests /srv/kubernetes/manifests
    ~~~~~~

2. 将以下内容加到文件 `/etc/kubernetes/mesos-cloud.cfg`， 每台 k8s master 机子上都要添加如下文件

    ~~~~~~
    [mesos-cloud]
    # 如 zk://192.168.33.21:2181,192.168.33.22:2181,192.168.33.23:2181/mesos
    mesos-master        = {{mesos_zk_addrs}} 
    http-client-timeout = 5s
    state-cache-ttl     = 20s
    ~~~~~~
3. 复制文件, 将以下文件复制到 所有 k8s master 主机上, `记得替换模板里面的变量`, 文件位置在 [prod/ansible/module/roles/k8s-ha/templates](./prod/ansible/module/roles/k8s-ha/templates)

    ~~~~~~
    HOME=prod/ansible/module/roles/k8s-ha
    cp $HOME/templates/kube-apiserver.yaml.j2          dest=/etc/kubernetes/manifests/kube-apiserver.yaml     mode=0644
    cp $HOME/templates/podmaster.yaml.j2               dest=/etc/kubernetes/manifests/podmaster.yaml          mode=0644
    cp $HOME/templates/kube-scheduler.yaml.j2          dest=/etc/kubernetes/manifests/kube-scheduler.yaml     mode=0644
    cp $HOME/templates/kube-controller-manager.yaml.j2 dest=/srv/kubernetes/manifests/kube-controller-manager.yaml mode=0644
    cp $HOME/templates/kubeletconf.j2                  dest=/etc/default/kubelet                  mode=0644
    cp $HOME/templates/kubelet.init.j2                 dest=/etc/init.d/kubelet                   mode=0755
    ~~~~~~
4. 运行命令 

    ~~~~~~
    update-rc.d kubelet defaults
    service kubelet start
    ~~~~~~

第三步，模板参数说明

* `mesos_zk_addrs`, 如 `zk://192.168.33.21:2181,192.168.33.22:2181,192.168.33.23:2181/mesos`
* `etcd_servers`, 如 `http://192.168.33.21:4001,192.168.33.22:4001,192.168.33.23:4001`
* `k8s_api_servers`, 如 `http://192.168.33.21:8888,192.168.33.22:8888,192.168.33.23:8888`
* `k8s_api_port`, 对外开放的 api_server 的端口地址，要与 `k8s_api_servers` 参数的端口相同，如 `8888`
* `ipaddr`, 本机地址

> 在每台机子上运行 docker ps -a 来查看各个服务的运行情况

运行完成以后可以在 mesos master 上看到 scheduler 注册情况

可以在 `/var/log/kubelet` 查看日志


### api_server 负载均衡

选一台机子作为 k8s 的负载均衡服务器， 在客户端通过 负载均衡 可以和 api_server 通讯

~~~~~~
# 默认 80 端口
kubectl get pod events ep  --server=http://#{负载均衡地址}:#{k8s_api_server_lb_port}
~~~~~~

添加以下内容到 `/etc/haproxy/haproxy.cfg`

~~~~~~
frontend webserver
    bind *:{{k8s_api_server_lb_port}}
    default_backend appservs

backend appservs
    balance roundrobin
    option forwardfor
    option httpchk HEAD / HTTP/1.1\r\nHost:localhost
    
    server k8s{{loop.index}} {{ip}}:{{k8s_api_port}} check

listen stats 
    bind 127.0.0.1:1936
    mode http
    log global
    
    stats enable
    stats uri /
    stats hide-version
    stats auth someuser:password
~~~~~~

参数说明

* `k8s_api_server_lb_port`, haproxy 监听地址，可以这是为 80
* `server k8s{{loop.index}} {{ip}}:{{k8s_api_port}} check`;
`k8s_api_port`, 为所有 k8s master api_server 端口地址，使用前面已经定义好的参数； 最终生成的配置可能如下

   ~~~~~~
   server k8s0 192.168.33.21:{{k8s_api_port}} check
   server k8s1 192.168.33.22:{{k8s_api_port}} check
   server k8s2 192.168.33.23:{{k8s_api_port}} check
   ~~~~~~

**最后运行容器**

~~~~~~
docker pull library/haproxy:1.6.2

docker run -d \
--net host --name haproxy --restart always \
-v /etc/haproxy:/usr/local/etc/haproxy \
library/haproxy:1.6.2
~~~~~~

验证脚本 `kubectl get pod events ep  --server=http://#{负载均衡地址}:#{k8s_api_server_lb_port}`
