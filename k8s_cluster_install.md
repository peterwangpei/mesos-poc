
# kubernetes-mesos 高可用集群搭建指南 #

> 请先在所有宿主机上安装 docker 环境， 安装步骤请参考 `doc/docker-install` 文件夹  
> 以下所有脚本都通过 ansible 脚本实现过，可以在 [prod/ansible/module/roles](./prod/ansible/module/roles) 查看各个模块的ansible脚本  
> 所有脚本的参数可以参考 [prod/local/inventory_cluster](./prod/local/inventory_cluster)


## 一、搭建 zookeeper 集群 ##

在所有主机上运行如下命令

~~~~~~
docker pull mesoscloud/zookeeper:3.4.6-ubuntu-14.04

docker run -d \
-e MYID=#{zk_id} \
-e SERVERS=#{servers} \
-p 2181:2181 \
-p 2888:2888 \
-p 3888:3888 \
-v /var/lib/zookeeper:/tmp/zookeeper \
--net=host --name zookeeper --restart=always \
mesoscloud/zookeeper:3.4.6-ubuntu-14.04
~~~~~~

参数说明

* `zk_id`, 从 1 开始往上加，比如 第一台机子是 1, 第二台就是 2，以此类推
* `servers`, 所有安装 zookeeper 机子的IP， 如 `192.168.33.21,192.168.33.22,192.168.33.23`

通过命令 `telnet #{zk ip} 2181`(输入命令 `stat`), 来验证 zookeeper 的成功安装, 

## 二、搭建 mesos master 集群 ##

~~~~~~
docker pull mesoscloud/mesos-master:0.24.1-ubuntu-14.04
    
docker run -d \
-e MESOS_HOSTNAME=#{ipaddr} \
-e MESOS_IP=#{ipaddr} \
-e MESOS_ZK=#{mesos_zk_addr} \
-e MESOS_QUORUM=#{ mesos_quorum  } \
-e MESOS_LOG_DIR=/var/log/mesos \
-v /var/log/mesos:/var/log/mesos \
-v /var/lib/mesos:/var/lib/mesos \
--name master --net=host --restart always \
mesoscloud/mesos-master:0.24.1-ubuntu-14.04
~~~~~~

参数说明

* `ipaddr`, 运行这条命令机子的 ip 地址
* `mesos_zk_addr`, mesos 利用 zookeeper 选举的地址，如 `zk://192.168.33.21:2181,192.168.33.22:2181,192.168.33.23:2181/mesos`
* `mesos_quorum`, master 集群投票最小通过数， 默认为 1, 伪代码 `max(1, mesos_master_cluster.size/2)`, 比如有三台 mesos master 值就为 2

通过访问地址 `http://#{mesosmaster ip}:5050` 来验证安装成功

## 三、搭建 mesos slave 集群 ##

> 注意：因为要用到动态加载网络磁盘，所以换了一个镜像，跟搭建单节点 不同

~~~~~~
docker pull mesosphere/mesos-slave-dind:0.2.4_mesos-0.24.0_docker-1.8.2_ubuntu-14.04.3

docker run -d \
-e MESOS_HOSTNAME=#{ipaddr} \
-e MESOS_IP=#{ipaddr} \
-e MESOS_MASTER=#{mesos_zk_addrs} \
-e MESOS_SWITCH_USER=0 \
-e MESOS_CONTAINERIZERS=docker,mesos \
-e DOCKER_DAEMON_ARGS=#{docker_opts} \
-e MESOS_ISOLATION=cgroups/cpu,cgroups/mem \
-e MESOS_LOG_DIR=/var/log/mesos \
-v /var/log/mesos:/var/log/mesos \
--name slave --pid host --net host --privileged \
--restart always \
mesosphere/mesos-slave-dind:0.2.4_mesos-0.24.0_docker-1.8.2_ubuntu-14.04.3
~~~~~~

参数说明

* `ipaddr`, 运行这条命令机子的 ip 地址
* `mesos_zk_addr`, mesos 利用 zookeeper 选举的地址，如 `zk://192.168.33.21:2181,192.168.33.22:2181,192.168.33.23:2181/mesos`
* `docker_opts`, 设置在 slave 当中启动 docker 时，需要用到的参数, 如设置 registry 地址 `--insecure-registry 192.168.33.10:5000 --registry-mirror http://192.168.33.10:5000`

通过访问地址 `http://#{mesosmaster ip}:5050` 来查看安装的 mesos slave 节点

## 四、etcd 集群的搭建

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

## 五、k8s 集群搭建

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


### k8s api_server 前端负均衡

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
