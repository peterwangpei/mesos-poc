# 在 CentOS 上安装 Docker #

    此安装说明针对的版本是 CentOS 7.X
    并且安装的是统一版本 Docker 1.9.1
    如有任何其他问题，请参考官方安装文档 https://docs.docker.com/engine/installation/centos/

## 版本要求

Docker 需要你安装在 `64-bit` 的 CentOS 版本上，且 Linux 的最小内核版本应该为 3.10.

可以通过命令 `uname -r` 来查看你的内核版本

~~~~~~
$ uname -r
3.10.0-229.el7.x86_64
~~~~~~

## 使用 yum 安装 Docker

1. 运行命令 `yum update`，更新 yum 包
2. 增加仓库

    ~~~~~~
    $ cat >/etc/yum.repos.d/docker.repo <<-EOF
    [dockerrepo]
    name=Docker Repository
    baseurl=https://yum.dockerproject.org/repo/main/centos/7
    enabled=1
    gpgcheck=1
    gpgkey=https://yum.dockerproject.org/gpg
    EOF
    ~~~~~~
3. 安装 Docker 包

    ~~~~~~
    $ yum install docker-engine-1.9.1-1.el7.centos # todo 指定版本号 1.9.1
    ~~~~~~
4. 启动 Docker 服务

    ~~~~~~
    $ service docker start
    ~~~~~~
5. 查看 Docker daemon 的信息

    ~~~~~~
    $ docker -D info
    ~~~~~~
6. 验证 docker 是否正确运行

    ~~~~~~
    $ docker run hello-world
    ~~~~~~

## 设置 Docker 开机启动

为了保证 Docker 随着系统启动，可以运行以下命令

~~~~~~
$ systemctl enable docker.service
~~~~~~

## 卸载 Docker

1. 查找已经 Docker 的包

    ~~~~~~
    $ yum list installed | grep docker
    
    docker-engine.x86_64   1.7.1-1.el7 @/docker-engine-1.7.1-1.el7.x86_64.rpm
    ~~~~~~
2. 移除包

    ~~~~~~
    yum -y remove docker-engine.x86_64
    ~~~~~~
3. 删除 images、containters、volumns 以及用户创建的一些配置文件

    ~~~~~~
    $ rm -rf /var/lib/docker
    ~~~~~~

### Todo

CentOS-7 中 Docker 默认采用 devicemapper 的文件系统，但是 devicemapper 文件系统还是有一定的缺陷(当metadata和data空间被耗尽时，需要重启Docker来扩充空间)。
可以 点击[这里](https://docs.docker.com/engine/userguide/storagedriver/btrfs-driver/)查看使用 btrfs 来作为 devicemapper 的替代品。
考虑到 btrfs 还在还在不断演进当中，不够稳定，建议在 devicemapper 出现明显瓶颈或者问题的时候，作为备选方案。

## 管理 Docker

因为 `CentOS 7.x` 是采用 `systemd` 作为任务管理工具

你可以在 `/etc/systemd/service`、`/lib/systemd/system` 或 `/usr/lib/systemd/system`
这三个文件中找到 `docker.service`，是 Docker 的启动配置文件

可以通过命令来启动、停止、重启、查看 `docker` 进程

~~~~~~
$ sudo systemctl start docker

$ sudo systemctl stop docker

$ sudo systemctl restart docker

$ sudo systemctl status docker
~~~~~~

如果你想开机启动 `docker`，可以设置

~~~~~~
$ sudo systemctl enable docker
~~~~~~

### 配置 Docker

1. 查看文件 `/etc/sysconfig/docker`, 如果不存在，可以创建它
2. 在 `/etc/sysconfig/docker` 文件中，添加变量 `OPTIONS`，当 `docker` 进程启动时，会应用这些参数，例子如下

    ~~~~~~
    OPTIONS="-D --tls=true --tlscert=/var/docker/server.pem --tlskey=/var/docker/serverkey.pem -H tcp://192.168.59.3:2376"
    ~~~~~~
    * `-D` 开启 debug 模式
    * 监听连接 `tcp://192.168.59.3:2376`

    可以在 [这里](https://docs.docker.com/engine/reference/commandline/daemon/) 查看这些命令的具体意义
3. 保存文件，并重启服务
    
    ~~~~~~
    $ sudo systemctl restart docker
    ~~~~~~

### 查看 Logs 信息

可以通过 `journalctl -u docker` 查看日志

~~~~~~
$ sudo journalctl -u docker
May 06 00:22:05 localhost.localdomain systemd[1]: Starting Docker Application Container Engine...
May 06 00:22:05 localhost.localdomain docker[2495]: time="2015-05-06T00:22:05Z" level="info" msg="+job serveapi(unix:///var/run/docker.sock)"
May 06 00:22:05 localhost.localdomain docker[2495]: time="2015-05-06T00:22:05Z" level="info" msg="Listening for HTTP on unix (/var/run/docker.sock)"
May 06 00:22:06 localhost.localdomain docker[2495]: time="2015-05-06T00:22:06Z" level="info" msg="+job init_networkdriver()"
May 06 00:22:06 localhost.localdomain docker[2495]: time="2015-05-06T00:22:06Z" level="info" msg="-job init_networkdriver() = OK (0)"
May 06 00:22:06 localhost.localdomain docker[2495]: time="2015-05-06T00:22:06Z" level="info" msg="Loading containers: start."
May 06 00:22:06 localhost.localdomain docker[2495]: time="2015-05-06T00:22:06Z" level="info" msg="Loading containers: done."
May 06 00:22:06 localhost.localdomain docker[2495]: time="2015-05-06T00:22:06Z" level="info" msg="docker daemon: 1.5.0-dev fc0329b/1.5.0; execdriver: native-0.2; graphdriver: devicemapper"
May 06 00:22:06 localhost.localdomain docker[2495]: time="2015-05-06T00:22:06Z" level="info" msg="+job acceptconnections()"
May 06 00:22:06 localhost.localdomain docker[2495]: time="2015-05-06T00:22:06Z" level="info" msg="-job acceptconnections() = OK (0)"
~~~~~~

### 其他

* [配置运行时参数](https://docs.docker.com/engine/articles/runmetrics/)
* [连接安全配置](https://docs.docker.com/engine/articles/https/)
