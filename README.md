# kubernetes-mesos 安装指南 #

> 以下安装方法针对的是单节点集群，不是高可用集群，如需安装高可用集群的，  
> 在熟悉单节点集群的安装方法下，参考 `prod/ansible` 下的安装脚本  
> 在条件满足的情况下，可以使用 virtualbox 来模拟高可用集群，具体方法参考 `prod/local`

1. 在所有宿主机上安装 docker， 安装步骤请参考 `doc/docker-install` 文件夹
2. 安装 zookeeper 镜像，命令如下

    ~~~~~~
    docker pull mesoscloud/zookeeper:3.4.6-ubuntu-14.04
  
    docker run -d \
    -e MYID=1 \
    -e SERVERS=#{zookeeper ip地址} \
    -p 2181:2181 \
    -p 2888:2888 \
    -p 3888:3888 \
    -v /var/lib/zookeeper:/tmp/zookeeper \
    --net=host --name zookeeper --restart=always \
    mesoscloud/zookeeper:3.4.6-ubuntu-14.04
    ~~~~~~
    详细的配置 zookeeper, mesos 配置安装，请参考 `doc/install mesos.md`
3. 启动 mesos master 镜像，命令如下

    ~~~~~~
    docker pull mesoscloud/mesos-master:0.24.1-ubuntu-14.04
    
    docker run -d \
    -e MESOS_HOSTNAME=#{master ip地址} \
    -e MESOS_IP=#{master ip地址} \
    -e MESOS_ZK=#{mesos_zk地址，如 zk://127.0.0.0:2181/mesos} \
    -e MESOS_QUORUM=#{ master 集群投票最小通过数， 默认为 1 [1, mesos_master_cluster.size/2].max } \
    -e MESOS_LOG_DIR=/var/log/mesos \
    -v /var/log/mesos:/var/log/mesos \
    -v /var/lib/mesos:/var/lib/mesos \
    --name master --net=host --restart always \
    mesoscloud/mesos-master:0.24.1-ubuntu-14.04
    ~~~~~~
4. 启动 mesos slave 镜像，可以启动多台， 命令如下

    ~~~~~~
    docker pull mesoscloud/mesos-slave:0.24.1-ubuntu-14.04

    docker run -d \
    -e MESOS_HOSTNAME=#{本机ip地址} \
    -e MESOS_IP=#{本机ip地址} \
    -e MESOS_MASTER=#{mesos_zk地址，如 zk://127.0.0.0:2181/mesos} \
    -e MESOS_ISOLATION=cgroups/cpu,cgroups/mem \
    -e MESOS_LOG_DIR=/var/log/mesos \
    -v /usr/bin/docker:/usr/bin/docker \
    -v /sys/fs/cgroup:/sys/fs/cgroup \
    -v /usr/lib/x86_64-linux-gnu/libapparmor.so.1:/usr/lib/x86_64-linux-gnu/libapparmor.so.1:ro \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/log/mesos:/var/log/mesos \
    -v /tmp/mesos:/tmp/mesos \
    --name slave --pid host --net host --privileged \
    --restart always \
    mesoscloud/mesos-slave:0.24.1-ubuntu-14.04
    ~~~~~~
5. 启动 kubernetes master （etcd 都在也打包到里面了）

    ~~~~~~
    docker pull mesosphere/kubernetes:v0.7.0-v1.1.1-alpha
    
    docker run -d \
    -e HOST=#{hostname 最好是ip地址} \
    -e DEFAULT_DNS_NAME=#{hostname 最好是ip地址}  \
    -e K8SM_MESOS_MASTER=#{mesos_zk地址，如 zk://127.0.0.0:2181/mesos} \
    -e MESOS_SANDBOX=/tmp \
    mesosphere/kubernetes:v0.7.0-v1.1.1-alpha
    ~~~~~~
    详细的 kubernete，及原理 请参考 `doc/deploy kubernetes.md` `doc/kubernetes.md`


> 再部署过程中 可能会遇到的问题 请参考 `doc/PITA.md`

## 验证运行情况

1. 验证 zookeeper, `echo stat | nc zookeeper_host 2181`
2. 验证 mesos master 和 mesos slave， 打开网页 `http://<mesosmaster>:5050`, 查看 master、slave 和 framework 的运行情况
3. 验证 kubernetes， 打开网页 `http://<mesosmaster>:8888`, 查看 kubernetes 的运行界面

