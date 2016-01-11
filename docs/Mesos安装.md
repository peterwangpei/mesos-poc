# Mesos 安装

## 搭建 zookeeper 集群

zookeeper 在生产环境上最好是5台机子，在所有要安装 zk 的主机上运行如下命令

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

通过命令 `telnet #{zk ip} 2181`(输入命令 `stat`), 来验证 zookeeper 的成功安装

可以通过 `docker logs -f zookeeper` 来查看日志

## 搭建 mesos-master 集群

在 mesos master 在生产环境中最好是 5 台，保证高可用

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

## 搭建 mesos-slave

> 注意： 考虑到 ceph fs 以 rbd 方式运行在 mesos 上，如果使用 docker 方式运行 mesos-slave 会产生一些各种问题，所以最终我们决定使用 以 mesos-slave 运行在进程上， 安装方式如下：

1. 运行脚本

    ~~~~~~
    wget http://downloads.mesosphere.io/master/ubuntu/14.04/mesos_0.24.0-1.0.27.ubuntu1404_amd64.deb
    sudo dpkg -i mesos_0.24.0-1.0.27.ubuntu1404_amd64.deb
    sudo apt-get install -f
    ~~~~~~
2. 配置 `/etc/default/mesos-slave`， 内容如下
    
    ~~~~~~
    MASTER={{mesos_zk_addrs}}
    SWITCH_USER=0
    CONTAINERIZERS=docker,mesos
    ISOLATION=cgroups/cpu,cgroups/mem
    LOGS=/var/log/mesos
    ~~~~~~
3. 配置文件 `/etc/mesos-slave/ip`， `/etc/mesos-slave/hostname`

    ~~~~~~
    {{ipaddr}}
    ~~~~~~
4. 配置 docker 启动参数, 配置文件 `/etc/default/docker`
    
    ~~~~~~
    DOCKER_OPTS="{{docker_opts}}"
    ~~~~~~
5. 每台机子 slave 机子加载 pause.tar `docker load -i pause.tar`, [pause.tar 下载地址](https://github.com/peterwangpei/mesos-poc/raw/master/prod/ansible/module/roles/mesos-slave/images/pause.tar)
6. 启动 mesos-slave, `service mesos-slave start`



参数说明

* `ipaddr`, 运行这条命令机子的 ip 地址
* `mesos_zk_addr`, mesos 利用 zookeeper 选举的地址，如 `zk://192.168.33.21:2181,192.168.33.22:2181,192.168.33.23:2181/mesos`
* `docker_opts`, 设置在 slave 当中启动 docker 时，需要用到的参数, 如设置 registry 地址 `--insecure-registry 192.168.33.10:5000 --registry-mirror http://192.168.33.10:5000`

通过访问地址 `http://#{mesosmaster ip}:5050` 来查看安装的 mesos slave 节点

调试方法，使用 `service mesos-slave status` 来查看 mesos-slave 运行状态， 可以通过 `/var/log/mesos/` 来查看运行日志

