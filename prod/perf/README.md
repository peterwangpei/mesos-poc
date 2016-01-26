
## 在poc生产环境下运行 ansible 脚本

1. 登录到10.63.119.36，此机器必须先安装上 `ansible` 运行环境  
    ```
$ sudo yum install ansible
    ```

2. 修改 `perf/ansible_inventory`， 分配角色（ansible group）给不同的计算机，并设置不同计算机登录密码
因为需要下载 docker 镜像，可能会遇到网络不通的问题。可以通过在 `ansible/ansible_inventory` 设置 `docker_opts` 变量来设置 `docker registry mirror`,
并在 `registry mirror` 中预先下载好需要用到的镜像。需要用到的镜像可以在 `ansible/roles/*/tasks/main.yml` 文件下查看
3. [运行 ansible 脚本](https://github.com/peterwangpei/mesos-poc/tree/master/prod/ansible)
