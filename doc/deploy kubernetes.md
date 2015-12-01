#Kubernetes安装指南
##编译Kubernetes
###本机编译Kubernetes
1. 下载Kubernetes源代码

	~~~
	#复制kubernetes代码仓库
	git clone https://github.com/kubernetes/kubernetes
	
	#检出代码到版本1.1.2
	git checkout tags/v1.1.2 -b v1.1.2
	~~~
2. 编译二进制文件

	~~~
	#编译所有平台二进制文件
	KUBERNETES_CONTRIB=mesos build/release.sh
	
	#编译当前主机平台二进制文件
	KUBERNETES_CONTRIB=mesos make
	
	#编译linux/amd64平台服务端二进制文件（当前主机不是Linux）
	KUBERNETES_CONTRIB=mesos build/run.sh hack/build-go.sh
	~~~
	**附加说明**
	- KUBERNETES_CONTRIB=mesos
	编译contrib/mesos二进制文件
	- hack/build-go.sh
	编译当前平台的GO二进制文件
	- make
	相当于调用`hack/build-go.sh`
	- build/run.sh
	在编译容器中执行一条命令
	- build/release.sh
	使用Docker编译kubernetes支持的所有平台的二进制文件（非常慢）
	
###使用Docker编译Kubernetes	

##启动本地Kubernetes集群
###必备环境

- Docker 1.3+
- etcd
- go 1.3+

###启动集群

~~~
#进入Kubernetes源代码目录
cd kubernetes

#启动集群
sudo hack/local-up-cluster.sh

#开启另外一个终端，配置集群
cluster/kubectl.sh config set-cluster local --server=http://127.0.0.1:8080 --insecure-skip-tls-verify=true

#然后可以通过cluster/kubectl.sh来对集群进行管理，具体命令可以直接运行cluster/kubectl.sh进行查看，例如创建pod
cluster/kubectl.sh create -f docs/user-guide/pod.yaml
~~~

##在Docker中部署Kubernetes集群
###All in one部署方式
![](k8s-docker.png)

####部署Master节点

~~~
#复制kubernetes代码仓库
git clone https://github.com/kubernetes/kubernetes
	
#检出代码到版本1.1.2
git checkout tags/v1.1.2 -b v1.1.2

#编译
KUBERNETES_CONTRIB=mesos make

#导出Kubernetes版本环境变量
export K8S_VERSION=1.1.2

#启动master节点（需要root权限）
cd kubernetes/docs/getting-started-guides/docker-multinode/

./master.sh
~~~

###添加工作节点

~~~
#导出kubernetes master地址环境变量
export MASTER_IP=<kubernetes master ip>

#启动工作节点（需要root权限）
cd kubernetes/docs/getting-started-guides/docker-multinode/

./worker.sh
~~~

###部署DNS

##将Kubernetes集群部署到Mesos环境

