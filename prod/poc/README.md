
## 在poc生产环境下运行 ansible 脚本

1. 登录到zk1，此机器必须先安装上 `ansible` 运行环境  
   
 - Ubuntu安装方法:

~~~~~~
$ sudo apt-get install software-properties-common
$ sudo apt-add-repository ppa:ansible/ansible
$ sudo apt-get update
$ sudo apt-get install ansible
~~~~~~

 - CentOS安装方法: 

 ~~~~~~
$ sudo yum install ansible
~~~~~~

2. 从github拉取最新代码，并将 `prod/ansible` 目录里的所有文件及文件夹复制到 `prod/poc` 文件夹里
3. 修改 `poc/ansible_inventory`， 分配角色（ansible group）给不同的计算机，并设置不同计算机登录密码
因为需要下载 docker 镜像，可能会遇到网络不通的问题。可以通过在 `ansible/ansible_inventory`设置 `docker_opts` 变量来设置 `docker registry mirror`,
并在 `registry mirror` 中预先下载好需要用到的镜像。需要用到的镜像可以在 `ansible/roles/*/tasks/main.yml` 文件下查看
4. [运行 ansible 脚本](https://github.com/peterwangpei/mesos-poc/tree/master/prod/ansible)
