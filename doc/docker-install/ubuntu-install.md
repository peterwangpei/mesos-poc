# 在 Ubuntu 上安装 Docker #

    此安装说明针对的版本是 Ubuntu Trusty 14.04 (LTS)
    并且安装的是统一版本 Docker 1.9.1
    如有任何其他问题，请参考官方安装文档 https://docs.docker.com/engine/installation/ubuntulinux/

## 版本要求 ##

Docker 需要你安装在 `64-bit` 的 Ubuntu 版本上，且 Linux 的最小内核版本应该为 3.10.

可以通过命令 `uname -r` 来查看你的内核版本

~~~~~~
$ uname -r
3.11.0-15-generic
~~~~~~

## 更新 apt 资源 ##

1. 打开命令行（terminal）窗口
2. 添加 `gpg` key

    ~~~~~~
    $ sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    ~~~~~~
3. 打开文件 `/etc/apt/sources.list.d/docker.list`，如果不存在此文件，就新建一个
4. 删掉里面的内容，并添加如下内容

    ~~~~~~
    # Ubuntu Trusty 14.04 (LTS)
    deb https://apt.dockerproject.org/repo ubuntu-trusty main
    ~~~~~~
5. 保存文件，并升级 `apt` 包
    
    ~~~~~~
    $ apt-get update
    ~~~~~~
6. 清除掉旧的包
    
    ~~~~~~
    $ apt-get purge lxc-docker*
    ~~~~~~
7. 验证 `apt` 命令是从正确的地址去拉 `docker-engine`
    
    ~~~~~~
    $ apt-cache policy docker-engine
    ~~~~~~

## 安装 `linux-image-extra` ##

为了可以使用 `aufs` 存储驱动，建议安装 `linux-image-extra`

~~~~~~
$ sudo apt-get install linux-image-extra-$(uname -r)
~~~~~~

## 安装 Docker 并指定版本号

1. 运行命令行 `sudo apt-get install docker-engine=1.9.1-0~trusty`， **注意加上版本号 1.9.1**
2. 启动 `dokcer` 服务，`$ sudo service docker start`
3. 验证 `dokcer` 成功运行

    ~~~~~~
    $ sudo docker run hello-world
    ~~~~~~

## 卸载 Docker

卸载 Docker 包

~~~~~~
$ sudo apt-get purge docker-engine
~~~~~~

卸载 Docker 包以及相关依赖

~~~~~~
$ sudo apt-get autoremove --purge docker-engine
~~~~~~

删除 images、containters、volumns 以及用户创建的一些配置文件

~~~~~~
$ rm -rf /var/lib/docker
~~~~~~

## 管理 Docker

因为 `Ubuntu-14.04` 采用的是 `Upstart` 作为任务管理工具， 所以可以在 `/etc/init/docker.conf` 查看 Docker 的启动脚本

可以通过命令来启动、停止、重启 `docker` 进程

~~~~~~
$ sudo start docker

$ sudo stop docker

$ sudo restart docker
~~~~~~


### 配置 Docker

1. 查看文件 `/etc/default/docker`, 如果不存在，可以创建它
2. 在 `/etc/default/docker` 文件中，添加变量 `DOCKER_OPTS`，当 `docker` 进程启动时，会应用这些参数，例子如下

    ~~~~~~
    DOCKER_OPTS="-D -H tcp://192.168.59.3:2376"
    ~~~~~~
    * `-D` 开启 debug 模式
    * 监听连接 `tcp://192.168.59.3:2376`

    可以在 [这里](https://docs.docker.com/engine/reference/commandline/daemon/) 查看这些命令的具体意义
3. 保存文件，并重启服务 `restart docker`

### 查看 Logs 信息

默认情况下 docker 的日志是放到 `/var/log/upstart/docker.log` 下的

~~~~~~
$ tail -f /var/log/upstart/docker.log
INFO[0000] Loading containers: done.
INFO[0000] docker daemon: 1.6.0 4749651; execdriver: native-0.2; graphdriver: aufs
INFO[0000] +job acceptconnections()
INFO[0000] -job acceptconnections() = OK (0)
INFO[0000] Daemon has completed initialization
~~~~~~

### 其他

* [配置运行时参数](https://docs.docker.com/engine/articles/runmetrics/)
* [连接安全配置](https://docs.docker.com/engine/articles/https/)
