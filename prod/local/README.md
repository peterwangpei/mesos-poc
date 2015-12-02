
`Vagrantfile` 是一个通过 vagrant 来模拟真实部署环境的一个脚本。可以通过它来启动多个虚拟机，
然后通过运行 ansible 脚本来执行自动化安装

> 自动化脚本目前默认运行在 `ubuntu 14.04` 上， `centos` 将在有需要的时候支持

## 启动方法

你的电脑必须先安装 `vagrant` `virtualbox` 以及 `ansible`

> 安装过程中，需要下载 docker 镜像，由于网络问题（需要翻墙），可能会失败

1. 从github拉取最新代码，并将 `prod/ansible` 目录里的所有文件及文件夹复制到 `prod/local` 文件夹里
2. 在 `prod/local` 文件夹里运行命令 `vagrant up`, 启动虚拟机
3. [运行 ansible 脚本](https://github.com/peterwangpei/mesos-poc/tree/master/prod/ansible)
