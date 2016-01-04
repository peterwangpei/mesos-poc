# 部署遇到的坑

- **现象**：运行ansible脚本后，输出`fatal: => SSH Error: Permission denied (publickey,password)`
- **问题**：密码里如果有关键字（如`#`），需要转义（如`\#`）
- **对策**：修改ansible_inventory，将密码转义

---

- **现象**：运行ansible脚本安装完mesos之后，slave没有被注册上
- **问题**：mesos slave的机器曾经启动过slave镜像，而最新的slave的镜像信息被修改过，导致不兼容
- **对策**：运行`rm -f /tmp/mesos/meta/slaves/latest`删除旧的注册信息，然后重启slave镜像

---

- **问题**：镜像下载慢，如nginx
- **对策**：运行如下脚本提前下载好，并push到本地的docker registry上

 ```
docker pull nginx
docker tag nginx:latest 10.229.51.58:5050/nginx:latest
docker push 10.229.51.58:5050/nginx:latest
docker rmi nginx:latest 10.229.51.58:5050/nginx:latest
```


---

- **问题**：gcr.io被墙
- **对策**：手动将下面的包复制并导入到mesos-slave上  

 ```
gcr.io/google_containers/pause:0.8.0
gcr.io/google_containers/kube-ui:v2
gcr.io/google_containers/kube2sky:1.11
gcr.io/google_containers/skydns:2015-10-13-8c72f8c
```

---

- **现象**：启动mesosphere/kubernetes:v0.7.0-v1.1.1-alpha容器后，mesos页面无反应
- **期望**：mesos页面应该新增kubernetes的Frameworks
- **问题**：mesos-master的机器没有FQDN。运行`hostname -f`只能看到`hostname: Name or service not known`
- **对策**：运行`cat /etc/hostname`查看本机的机器名，然后将其增加到`/etc/hosts`里面去。如本机IP为192.168.33.21，`/etc/hostname`里面为mm1，需要在`/etc/hosts`里面增加一行`192.168.33.21  mm1.localdomain.local  mm1`。保存后运行`hostname -f`就能看到`mm1.localdomain.local`了

---

- **现象**：kubernetes容器启动后，在mesos首页的Active Tasks点击Sandbox链接报错：`Failed to connect to slave ...`
- **期望**：能够打开Slaves的Sandbox的页面
- **问题**：kubernetes默认所有Slave的机器名都已经写在`/etc/hosts`里面
- **对策**：可以修改`/etc/hosts`，也可以在mesos slave的启动参数中把主机名修改成IP地址。我们现在用的是后一种方案

---

- **现象**：ansible运行`playboox.yml`后，在这一行停住了：`TASK: [mesos-slave | shell if [ ! -f /dev/rbd/rbd/mysql ]; then rbd map mysql --pool rbd --name client.admin; fi] ***`
- **对策**：重启cepf容器

---

- **现象**：ansible运行`mysql-replication.yml`后，mysql-master pod起不来，describe pod显示：`rbd: image mysql is locked by other nodes`
- **对策**：运行`rbd lock list mysql`，将会看见mysql镜像上的锁。用`rbd lock remove mysql <ID> <Locker>`将锁删除即可。

---

- **现象**：ansible运行`mysql-replication.yml`后，mysql-master pod起不来，describe pod显示：`Could not map image: Timeout after 10s`
- **对策**：到所有mesos-slave-dind的容器里，运行`lsblk`，如果看到一堆的rbd加数字，就把它们全部解除映射。

 ```
rbd unmap /dev/rbd2
rbd unmap /dev/rbd3
...
```
