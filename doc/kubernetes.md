# 通过容器启动kubernetes单机服务
1. 运行如下命令下载mesosphere/kubernetes:v0.7.0-v1.1.1-alpha镜像。

	```
docker pull mesosphere/kubernetes:v0.7.0-v1.1.1-alpha
```
2. 运行如下命令确认虚拟机上已经安装了kubernetes的镜像。

	```
docker images
```
3. 运行如下命令启动kubernetes容器。  
 - 将`<docker-host-IP>`改为本机IP。  
 - 将`<mesos-master>`改为mesos的master地址，如`zk://192.168.43.10:2181/mesos`。

	```
docker run -d \
  --name=k8s \
  -e GLOG_v=3 \
  -e HOST=<docker-host-IP> \
  -e DEFAULT_DNS_NAME=<docker-host-IP> \
  -e K8SM_MESOS_MASTER=<mesos-master> \
  -e MESOS_SANDBOX=/tmp \
  --net=host -it mesosphere/kubernetes:v0.7.0-v1.1.1-alpha
```
若提示`Error response from daemon: Conflict. The name "k8s" is already in use by container...`，可先运行`docker rm -f k8s`将其删除。
4. 访问如下页面查看kubernetes的界面。

	```
http://<docker-host-IP>:8888/
```