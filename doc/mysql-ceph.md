# 配置 ceph
如果ceph环境是由其他部门提供的，我们就可以忽略下面自己创建ceph环境的部分。

## 创建ceph环境
运行以下命令启动ceph容器：
```sh
docker run -d --net=host -v /etc/ceph:/etc/ceph -e MON_IP=192.168.0.20 -e CEPH_NETWORK=192.168.0.0/24 --name=ceph ceph/demo
```
如果要作为块设备加载，需要安装ceph-common包，根据自己的系统选择下面的安装命令：
```sh
apt-get install -y ceph-common
或
yum install -y ceph-common
```
创建一个名为mysql的image，占1G空间，映射到本机并格式化：
```sh
rbd create mysql --size 1024
sudo rbd map mysql
sudo mkfs.ext4 -m0 /dev/rbd/rbd/mysql
```
加载并删除里面的`lost+found`文件夹（mysql可能因为文件夹不是空的而拒绝启动）：
```sh
sudo mkdir -p /mnt/rbd/mysql
sudo mount /dev/rbd1 /mnt/rbd/mysql
ls /mnt/rbd/mysql/
sudo rm -rf /mnt/rbd/mysql/lost+found
sudo umount /mnt/rbd/qqq
```

##
不管ceph环境是怎么来的，我们都应该都有一个`/etc/ceph`文件夹。运行`cat /etc/ceph/ceph.client.admin.keyring`可以看到`key`，如`AQBF+oBWDbRnLxAADhPPuRl2p3ksGTbLXUJ+Xw==`。再运行下面的命令得到base64编码的`key`：
```sh
echo AQBF+oBWDbRnLxAADhPPuRl2p3ksGTbLXUJ+Xw== | base64
```
得到的结果`QVFCRitvQldEYlJuTHhBQURoUFB1UmwycDNrc0dUYkxYVUorWHc9PQo=`就是`ceph_client_secret`。接着运行`cat /etc/ceph/ceph.conf`可以看到`mon host`，这是个ip地址，如：`192.168.33.11`。有了它就能组装出`ceph_mon_addrs`：["192.168.33.11:6789"]。6789是默认的ceph端口。现在我们有了两个变量：`ceph_client_secret`和`ceph_mon_addrs`。使用下面几个yaml，就可以用`kubectl create -f`命令来构建自己的mysql replication主从环境了。

- [ceph-secret.yaml](https://github.com/peterwangpei/mesos-poc/blob/master/prod/ansible/module/addons/ceph-secret.yaml.j2)
- [mysqlmaster.yaml](https://github.com/peterwangpei/mesos-poc/blob/master/prod/ansible/module/addons/mysqlmaster.yaml.j2)
- [mysqlslave.yaml](https://github.com/peterwangpei/mesos-poc/blob/master/prod/ansible/module/addons/mysqlslave.yaml.j2)
- [mysql-tomcat.yaml](https://github.com/peterwangpei/mesos-poc/blob/master/prod/ansible/module/addons/mysql-tomcat.yaml.j2)
- 