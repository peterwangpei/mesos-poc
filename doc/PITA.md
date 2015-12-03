# 部署遇到的坑

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
