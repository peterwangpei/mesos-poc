
`Vagrantfile` 是一个通过 vagrant 来模拟真实部署环境的一个脚本。可以通过它来启动多个虚拟机，
然后通过运行 ansible 脚本来执行自动化安装

> 自动化脚本目前默认运行在 `ubuntu 14.04` 上， `centos` 将在有需要的时候支持

## 启动方法

你的电脑必须先安装 `vagrant` `virtualbox` 以及 `ansible`

> 安装过程中，需要下载 docker 镜像，由于网络问题（需要翻墙），可能会失败

1. 在 `prod/local` 文件夹里运行命令 `vagrant up`, 启动虚拟机
2. 配合文件`Vagrantfile` 配置 `ansible_inventory`（默认配置好的）
3. [运行 ansible 脚本](https://github.com/peterwangpei/mesos-poc/tree/master/prod/ansible)，
具体操作也可查看 `registry使用` 章节

### Vagrantfile 说明

vagrant 会启动，7个虚拟机，并做如下配置：

~~~~~~
"reg" => { :ip => "192.168.33.10", :mem => 512,  :cpu => 1},
"zk1" => { :ip => "192.168.33.11", :mem => 512,  :cpu => 1},
"mm1" => { :ip => "192.168.33.21", :mem => 512,  :cpu => 1},
"ms1" => { :ip => "192.168.33.31", :mem => 1024, :cpu => 1},
"ms2" => { :ip => "192.168.33.32", :mem => 512,  :cpu => 1},
"ms3" => { :ip => "192.168.33.33", :mem => 512,  :cpu => 1},
"km"  => { :ip => "192.168.33.41", :mem => 512,  :cpu => 1}
~~~~~~

可以通过命令 `vagrant ssh zk1` 命令来登录 `zk1` 这台机器

`zk1`, `mm1`, `ms1`, `ms2`, `ms3` 分别来模拟 poc 环境的五台机子，
分别安装 `zookeeper`, `mesos-master`, `mesos-slave`

`reg` 用来做 registry-mirror，方便快速开发，使用方法在文章后面

在做 cluster 的 demo 的时候，`km` 用来单独装 `kubernets-cluster` 环境，
需要在 `zk1` 上安装 etcd； 在 poc 环境下 会将 `kubernetes`（不是 cluster） 都装到 `mm1` 这台机子下。

这些安装 可以通过文件 `ansible_inventory` 和 `ansible/playbook.xml` 来配置

## registry 使用

因为在每次重建虚拟机并运行脚本的时候需要重新下载 docker 镜像，
导致每次都需要重新下载 镜像，导致浪费流量并浪费时间；所以先可以把镜像放到本地的 registry-mirror.

启动步骤如下：

1. 运行命令 `vagrant up`
2. 修改 `ansible/playbook.xml`, 先运行  `ansible-playbook -i ansible_inventory ../ansible/playbook.yml` 安装好 registry

    ~~~~~~
     - include: module/docker.yml
     - include: module/docker-configuration.yml
     - include: module/registry.yml
    ~~~~~~
3. 通过 `vagrant ssh reg` 登录到 registry 的虚拟机，拷贝 `docker_share.sh` 到 registry 虚拟机，
通过如下命令下载，并将镜像注册到 registry; 对于以后重用的镜像都可以先做如下的操作

~~~~~~
./docker_share.sh mesoscloud/mesos-slave:0.24.1-ubuntu-14.04
./docker_share.sh mesoscloud/mesos-master:0.24.1-ubuntu-14.04
./docker_share.sh mesoscloud/zookeeper:3.4.6-ubuntu-14.04
./docker_share.sh mesosphere/kubernetes:v0.7.0-v1.1.1-alpha

# ./docker_share.sh quay.io/coreos/etcd:v2.2.1
# ./docker_share.sh peterwang115/kubernetes-mesos:1.1.2-ubuntu-14.04
# ./docker_share.sh gcr.io/google_containers/skydns:2015-10-13-8c72f8c
~~~~~~

4. 当镜像注册完之后，重新修改 `ansible/playbook.xml`; 并运行 `ansible-playbook -i ansible_inventory ../ansible/playbook.yml`

~~~~~~
- include: module/zookeeper.yml
- include: module/mesos_slave.yml
- include: module/mesos_master.yml

## all in one docker kubernets
- include: module/k8s.yml
~~~~~~



       +-----------------------+    +----------------------+                  +-------------------+
       |  api_server_haproxy   |    |      mesos master    |                  |      slave        |
       |  ceph                 |    |      zookeeper       |                  +-------------------+
       |  nfs                  |    |      etcd            |
       +-----------------------+    +----------------------+
                                                                              +-------------------+
                                    +--------------------------------+        |      slave        |
                                    |      k8s_matster               |        +-------------------+
                                    |        api_server              |
                                    |        schedule                |
                                    |        controller manager      |        +-------------------+
                                    +--------------------------------+        |      slave        |
                                                                              +-------------------+
     

                                                                         +-------------------+
                                                                         |      slave        |
                                                                         +-------------------+


## 安装 ceph
1. 将 `/prod/ansible/ceph/` 文件夹复制至ceph安装机器上的 `/etc/ceph/`
2. 通过ansible脚本运行ceph/demo
3. 安装 `ceph-common` 包
4. 运行 `sudo rbd create mysql --size 100000 -k /etc/ceph/ceph.client.admin.keyring` 创建 mysql image
5. 运行 `sudo mkfs.ext4 -m0 /dev/rbd/rbd/mysql` 将 mysql image 格式化
6. 运行如下命令检测是否可以正常加载 mysql image

    ```
sudo mkdir -p /mnt/rdb/mysql
sudo mount -t ext4 /dev/rbd/rbd/mysql /mnt/rdb/mysql
ls /mnt/rdb/mysql/
sudo umount /mnt/rdb/mysql
    ```
