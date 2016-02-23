# 安装marathon和bamboo运行环境

## 简介
Apache Mesos把自己定位成一个数据中心操作系统，它能管理上万台的从机（slave）。Framework相当于这个操作系统的应用程序，每当应用程序需要执行，Framework就会在Mesos中选择一台有合适资源（cpu、内存等）的从机来运行。[Marathon](https://mesosphere.github.io/marathon/)是Framework的一种，被设计来支持长时间运行的服务。如果我们在marathon上部署了一个tomcat服务并希望它能暴露给外网，应该怎么做呢？[Bamboo](https://github.com/QubitProducts/bamboo)提供了一个非常方便运行的办法帮我们做到这一点。它集成了HAproxy，当marathon检测到应用挂掉并重启应用时，bamboo能够检测到并更新HAproxy的配置文件，然后自动重启HAproxy，从而无须人工干预便能持续不断地对外提供服务。

## 搭建环境
准备两台机器，一台叫做**master**，假设它的IP是**192.168.33.18**；另一台叫做**slave**，假设它的IP是**192.168.33.19**，之间网络互通。如果你是其他IP，请全文替换下面的所有命令。首先在master的虚拟机上启动zookeeper：
```sh master
docker run -d \
    --net=host \
    --name=zk \
    -e MYID=1 \
    -e SERVERS=192.168.33.18 \
    mesoscloud/zookeeper:3.4.6-ubuntu-14.04
```

可以用`docker ps`看到名为zk的容器已经启动起来了。有兴趣的话，可以用下面的命令验证：
```sh master
docker exec -it zk zkCli.sh -server 127.0.0.1:2181
```
这里就不详细介绍zookeeper的命令了，`ls /`可以查看根节点，`help`可以查看所有命令，`quit`退出客户端。

接下来在master的虚拟机上启动mesos master：
```sh master
docker run -d \
    --net=host \
    --name=mm \
    -e MESOS_HOSTNAME=192.168.33.18 \
    -e MESOS_IP=192.168.33.18 \
    -e MESOS_ZK=zk://192.168.33.18:2181/mesos \
    -e MESOS_QUORUM=1 \
    -e MESOS_LOG_DIR=/var/log/mesos \
    mesoscloud/mesos-master:0.24.1-ubuntu-14.04
```

顺利的话，打开`http://192.168.33.18:5050/`应该能看到mesos的页面了。然后在slave的虚拟机上启动mesos slave：
```sh slave
docker run -d \
    --net=host \
    --pid=host \
    --privileged=true \
    --name=ms1 \
    -v /usr/bin/docker:/usr/bin/docker \
    -v /dev:/dev \
    -v /usr/lib/x86_64-linux-gnu/libapparmor.so.1:/usr/lib/x86_64-linux-gnu/libapparmor.so.1:ro \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/log/mesos:/var/log/mesos \
    -v /tmp/mesos:/tmp/mesos \
    -e MESOS_HOSTNAME=192.168.33.19 \
    -e MESOS_IP=192.168.33.19 \
    -e MESOS_MASTER=zk://192.168.33.18:2181/mesos \
    -e MESOS_CONTAINERIZERS=docker,mesos \
    mesoscloud/mesos-slave:0.24.1-ubuntu-14.04
```

点击mesos页面上的**Slaves**应该能看到slave已经加入到集群中了。最后在master的虚拟机上启动marathon：
```sh master
docker run -d \
    --net=host \
    --name=ma \
    mesosphere/marathon:v0.15.0 \
    --master zk://192.168.33.18:2181/mesos \
    --zk zk://192.168.33.18:2181/marathon \
    --event_subscriber http_callback
```

现在启动Bamboo镜像，在里面指定marathon的地址：
```sh master
docker run -d \
    -p 8000:8000 \
    -p 80:80 \
    --name=bam \
    -e MARATHON_ENDPOINT=http://192.168.33.18:8080 \
    -e BAMBOO_ENDPOINT=http://192.168.33.18:8000 \
    -e BAMBOO_ZK_HOST=192.168.33.18:2181 \
    -e BAMBOO_ZK_PATH=/bamboo \
    -e BIND=":8000" \
    -e CONFIG_PATH="config/production.example.json" \
    -e BAMBOO_DOCKER_AUTO_HOST=true \
    gregory90/bamboo:0.2.11
```

在浏览器打开`http://192.168.33.18:8000/`应该能看到bamboo的页面。

## 服务发现
现在用marathon来启动一个tomcat服务。在任意一台机器上运行以下命令，把创建tomcat服务的请求发送给marathon的REST api：
```sh
curl -X POST http://192.168.33.18:8080/v2/apps \
    -H "Content-type: application/json" \
    -d '{"cpus":0.5,"mem":200,"disk":0,"instances":1,"id":"tomcat", 
    "container":{"docker":{"image":"tomcat","network":"BRIDGE","portMappings": 
    [{"containerPort":8080,"hostPort":0,"servicePort":0,"protocol":"tcp"}]}}}'
```

分别刷新marathon和bamboo，就能看到它们各自多了个tomcat的服务。点击bamboo页面上的**/tomcat**记录最右边的加号按钮，在**acl**里输入`path_beg -i /`（表示运行在根目录上，有兴趣的话可以参考HAproxy的[ACL语法](http://cbonte.github.io/haproxy-dconv/configuration-1.5.html#7)），然后点击**Create**按钮。顺利的话，打开`http://192.168.33.18/`应该能看到tomcat首页。这个时候，在marathon的页面上点击tomcat这行记录，便会到tomcat application页面里。如下图选中当前的tomcat实例，点击**Kill**按钮，稍等几秒，就会看到tomcat的服务运行地址从`192.168.33.19:31071`变成了`192.168.33.19:31571`，端口因机而异。再回去刷新tomcat的`http://192.168.33.18/`页面，应该仍然能够提供服务。如果你手快，应该能看到**503 Service Unavailable**，那就多刷新两下。到slave虚拟机上用命令删除tomcat容器，再观察一下，应该依旧能够照常提供服务。

## 其他服务发现方法
Marathon官方还支持其它[三种服务发现的方法](https://mesosphere.github.io/marathon/docs/service-discovery-load-balancing)：
1. Mesos-DNS：Mesosphere公司提供的DNS产品，不仅适用于marathon，而且适用于其它Mesos Framework。
2. Marathon-lb：感觉上跟k8s的[NodePort](http://kubernetes.io/v1.1/docs/user-guide/services.html#type-nodeport)有点像，不过它像Bamboo那样包含了HAproxy。
3. haproxy-marathon-bridge：现在已经不推荐了。需要在每个slave上安装HAproxy，定时更新HAproxy的配置文件。
