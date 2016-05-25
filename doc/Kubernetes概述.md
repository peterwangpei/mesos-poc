# Kubernetes概述

## 基本概念

### Cluster
一组被Kubernetes托管，用来运行应用的物理机、虚拟机以及其它基础架构资源的集合被称之为集群（Cluster）。在集群中，单台物理机或者虚拟机都被称为节点（Node），节点是集群最重要的组成部分，代表了集群的计算资源和规模。目前，Kubernetes大概能够管理一千台节点的集群。

### Node
用来组成集群的物理机或者虚拟机。在Kubernetes中所有的应用都会被调度到节点上，或者换句话说，节点就是Kubernetes中用来运行应用的计算资源。

### Pod
一组一起部署的容器和卷的集合。在Kubernetes中，Pod是Kubernetes中应用组织和操作的最小单元，同一个Pod中的所有容器和卷被当做一个整体看待，同一个Pod的容器和卷同时只能调度到同一个节点上。此外，同一个Pod中的所有容器，共享同一个网络地址，同一个Pod中的容器可以很方便的通过`localhost`上映射的不同端口，实现Pod内容器的互访。

### Label
标签（Label）是一个简单的名值对，用来给资源附加自定义的标识属性（Attribute）。通过在资源上附加标签，可以用来组织或者选择特定的资源。例如，可以在节点上打标签，标识出那些Node挂载了SSD硬盘。

### Selector
选择器（Selector）可以简单的理解为标签表达式，利用标签来对资源进行过滤和分组，以挑选出具有特定标签的资源。例如，下面的选择器`"selector": { "k8s-app": "kube-dns" }`，就表示所有附加了标签`"k8s-app": "kube-dns"`的资源。在Kubernetes中，选择器一般用来关联服务和Pod。

### Replication Controller
Replication Controller简称RC，主要用来控制同一类Pod同时运行的副本数。在实际的生产环境中，基于性能、可用性以及容灾等方面的考虑，同一个应用可能同时需要运行一个或者多个实例，对于这种情况，映射到Kubernetes中，则表现为创建一个RC以及指定RC的副本数。此外，通过RC可以非常简单的实现应用的扩容、缩容以及滚动升级。

### Job
任务（Job）用来执行一些不需要长期运行的任务，例如编译等，下面是任务的例子：
	
	apiVersion: batch/v1
	kind: Job
	metadata:
	  name: pi
	spec:
	  template:
	    metadata:
	      name: pi
	    spec:
	      containers:
	      - name: pi
	        image: perl
	        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
	      restartPolicy: Never

在未来的版本中，可能会增加定时任务的支持。
	      
### Service
服务（Service）是一个比较抽象的概念，可以简单的理解为一组Pod的**集群内**统一访问入口。在Kubernetes集群中，由于扩容、缩容以及故障转移等原因，会导致组成某一应用的Pod的数量、地址和名称不断的发生变化，所以希望通过Pod的地址和名称来访问Pod是不太现实的（当然可以通过API动态的查询Pod的地址和名称），为了在集群内部能够方便访问这些Pod，Kubernetes提供了一种名为“服务”的机制，将这些Pod组织为一个逻辑上的统一体，这样其它Pod就可以通过服务的地址和服务的DNS名来访问服务了。

下面为一个服务定义文件的例子：

    apiVersion: v1
	 kind: Service
	 metadata:
	    name: nginx-service
		 spec:
		    ports:
		      - port: 8000 
		        targetPort: 80
		        protocol: TCP
		    selector:
		        app: nginx
		         
### Volume
Kubernetes的Volume可以简单的理解为是Docker Volumes的简单包装，具体的能力可以查看[Docker Volumes](https://docs.docker.com/engine/userguide/containers/dockervolumes/)。

### Secret
秘密（Secret）用来存储诸如认证令牌（Authentication Token）、SSH秘钥等敏感数据，利用秘密可以以一种统一的方式来管理和维护需要传递给容器的敏感数据。当根据敏感数据创建秘密并且将秘密指定给Pod之后，不管Pod运行在集群中的任何一个节点上，容器都可以通过环境变量、文件等方式优雅的读取关联秘密的内容。

### Namespace
命名空间（Namespace）可以用来给资源和容器进行分组，一般用来实现多租户。

### Annotation
注释（Annotation）与标签类似，也是一个名值对，也可以用来将自定义数据附加到资源上。与标签相比，注释能够保存的数据量要大一些，但是不支持通过选择器来过滤注释。此外，也可以利用注释来存储版本信息、服务名、服务地址等配置信息。

### Ingress
在默认情况下，服务的IP地址，只能够在集群网络中访问，而无法在集群之外访问。Ingress提供了一种机制，用于实现在集群之外访问集群之内的服务。

### Port Proxy
通过`gcr.io/google_containers/proxy-to-service:v2`镜像，实现将节点上的指定端口映射到特定的服务，例如下面的定义文件定义了将端口53映射到服务`kube-dns`的代理:

	apiVersion: v1
	kind: Pod
	metadata:
	  name: dns-proxy
	spec:
	  containers:
	  - name: proxy-udp
	    image: gcr.io/google_containers/proxy-to-service:v2
	    args: [ "udp", "53", "kube-dns.default", "1" ]
	    ports:
	    - name: udp
	      protocol: UDP
	      containerPort: 53
	      hostPort: 53
	  - name: proxy-tcp
	    image: gcr.io/google_containers/proxy-to-service:v2
	    args: [ "tcp", "53", "kube-dns.default" ]
	    ports:
	    - name: tcp
	      protocol: TCP
	      containerPort: 53
	      hostPort: 53
	      
### ClusterIP
Kubernetes为服务创建的虚拟IP，通过此虚拟IP可以访问服务后端的Pod。ClusterIP的范围由API Server的启动参数`service-cluster-ip-range`指定。

### Static Pod
Static Pod是指由Kubelet守护程序直接托管的Pod。对于这种Pod，完全绑定在Kubelete守护程序上，不关联到RC，也不会被API Server所监管，完全由Kubelete守护程序来维护其生命周期，随着Kubelete的启动而启动。一般，StaticPod用来实现集群的引导，例如启动API Server。在未来的版本中，Static Pod可能会被废弃。

### DaemonSet
DaemonSet用来实现确保集群中的所有节点上都运行一个指定的Pod，可以与选择器（Selector）配合使用，来选择需要运行Pod的节点。DaemonSet一般用来运行每一个节点都需要运行的Pod，例如Flannel等。

### ConfigMap
Config Map用来保存和维护Pod需要使用的配置信息。

### Affinity
亲和性（Affinity）用于指定调度器将会将Pod分配到哪些节点。目前版本（1.2）版本的Kubernetes仅支持节点亲和性，只能够根据节点上附加的标签来决定Pod是否分配到指定的节点。目前仅支持在Pod创建之前调度，当Pod创建之后，当节点的标签发生变更时，不会对已经调度的节点做二次调度。

以下为一个节点亲和性的例子：
	
	apiVersion: v1
	kind: Pod
	metadata:
	  name: with-labels
	  annotations:
	    scheduler.alpha.kubernetes.io/affinity: >
	      {
	        "nodeAffinity": {
	          "requiredDuringSchedulingIgnoredDuringExecution": {
	            "nodeSelectorTerms": [
	              {
	                "matchExpressions": [
	                  {
	                    "key": "kubernetes.io/e2e-az-name",
	                    "operator": "In",
	                    "values": ["e2e-az1", "e2e-az2"]
	                  }
	                ]
	              }
	            ]
	          }
	        }
	      }
	    another-annotation-key: another-annotation-value
	spec:
	  containers:
	  - name: with-labels
	    image: gcr.io/google_containers/pause:2.0

目前支持的节点亲和性类型：

* requiredDuringSchedulingIgnoredDuringExecution
* preferresDuringSchedulingIgnoredDuringExecution

计划支持的节点亲和性类型：

* requiredDuringSchedulingRequiredDuringExecution
* requiredDuringSchedulingIgnoredDuringExecution

未来的版本还计划支持Pod亲和性，能够根据节点上运行的Pod来决定Pod是否分配到此节点。

### Hook
钩子（Hook）是一种用来向容器通知其生命周期状态变化事件的机制，容器可以使用钩子来做一些初始化或者清场工作。目前，Kubernetes提供了以下两种不同的钩子：

* PostStart
当容器创建成功之后，触发PostStart钩子。需要注意的是：不保证PostStart钩子在容器的入口点（entrypoint）之前执行。
* PreStop
在容器将要被终止之前，触发PreStop钩子。需要注意的是，在PreStop钩子执行完成之前，Kubernetes不会调用Docker Daemon来删除容器。

*注意：由于容器可以多次启动和停止，所以对于同一个容器，钩子可能会被多次调用*

目前，可以使用以下两种方式实现钩子：

* 执行命令（EXEC）
* 发送HTTP请求（HTTP）

*注意：钩子总是在容器内部执行*

下面是一个钩子的示例：

	apiVersion: extensions/v1beta1
	kind: Deployment
	metadata:
	  name: nginx
	spec:
	  template:
	    metadata:
	      labels:
	        app: nginx
	    spec:
	      containers:
	      - name: nginx
	        image: nginx
	        ports:
	        - containerPort: 80
	        lifecycle:
	          preStop:
	            exec:
	              # SIGTERM triggers a quick exit; gracefully terminate instead
	              command: ["/usr/sbin/nginx","-s","quit"]
	              
	             	              
### 终止消息
容器在退出时会将容器的退出时的信息写入到`terminationMessagePath`指定的文件（默认为： /dev/termination-log）,可以使用下面的命令查看终止消息：

	kubectl get pods/$PODNAME -o go-template="{{range .status.containerStatuses}}{{.lastState.terminated.message}}{{end}}"

### Downward apiece
Downward API可以将Pod的信息暴露给容器，例如Pod的名称、命名空间以及IP等，下面为Downward API的例子：

> 挂载为环境变量

	apiVersion: v1
	kind: Pod
	metadata:
	  name: dapi-test-pod
	spec:
	  containers:
	    - name: test-container
	      image: gcr.io/google_containers/busybox
	      command: [ "/bin/sh", "-c", "env" ]
	      env:
	        - name: MY_POD_NAME
	          valueFrom:
	            fieldRef:
	              fieldPath: metadata.name
	        - name: MY_POD_NAMESPACE
	          valueFrom:
	            fieldRef:
	              fieldPath: metadata.namespace
	        - name: MY_POD_IP
	          valueFrom:
	            fieldRef:
	              fieldPath: status.podIP
	  restartPolicy: Never
	  
> 挂载为卷

	apiVersion: v1
	kind: Pod
	metadata:
	  name: kubernetes-downwardapi-volume-example
	  labels:
	    zone: us-est-coast
	    cluster: test-cluster1
	    rack: rack-22
	  annotations:
	    build: two
	    builder: john-doe
	spec:
	  containers:
	    - name: client-container
	      image: gcr.io/google_containers/busybox
	      command: ["sh", "-c", "while true; do if [[ -e /etc/labels ]]; then cat /etc/labels; fi; if [[ -e /etc/annotations ]]; then cat /etc/annotations; fi; sleep 5; done"]
	      volumeMounts:
	        - name: podinfo
	          mountPath: /etc
	          readOnly: false
	  volumes:
	    - name: podinfo
	      downwardAPI:
	        items:
	          - path: "labels"
	            fieldRef:
	              fieldPath: metadata.labels
	          - path: "annotations"
	            fieldRef:
	              fieldPath: metadata.annotations
               
## 组件和构成

### ApiServer
### Scheduler
### Controller Manager
### Kubelet
### Proxy
### Etcd
### Flannel
### SkyDNS
### Kube2Sky
### Dashbord

## 应用的部署和管理

### 部署应用

### 管理应用

### 应用的扩容与缩容

### 应用的升级和回滚

### 应用的监控和健康检查
#### 容器的监控检查
在Kubernetes中，使用一种名为探针（Probe）的机制来检查容器的健康状况，其中`LivenessProbe`用来检查容器的存活状态，而`ReadinessProbe`用来检查容器是否能够对外提供服务。

* LivenessProbe
如果`LivenessProbe`检查失败，则Kubelet会杀掉容器，容器是否能够重启则由创建Pod时的`RestartPolicy`决定。
* ReadinessProbe
如果`ReadinessProbe`检查失败，则终结点（EndPoint）控制器将会从相关服务的终结点中删除对应失败容器的终结点，以确保调用不会被转发到此容器。

与钩子类似，探针也提供了执行命令（EXEC）和发送HTTP请求（HTTP）两种不同的实现方式，下面是两个探针的例子：
> 执行命名

	apiVersion: v1
	kind: Pod
	metadata:
	  labels:
	    test: liveness
	  name: liveness-exec
	spec:
	  containers:
	  - args:
	    - /bin/sh
	    - -c
	    - echo ok > /tmp/health; sleep 10; rm -rf /tmp/health; sleep 600
	    image: gcr.io/google_containers/busybox
	    livenessProbe:
	      exec:
	        command:
	        - cat
	        - /tmp/health
	      initialDelaySeconds: 15
	      timeoutSeconds: 1
	    name: liveness

> 发送HTTP请求

	apiVersion: v1
	kind: Pod
	metadata:
	  labels:
	    test: liveness
	  name: liveness-http
	spec:
	  containers:
	  - args:
	    - /server
	    image: gcr.io/google_containers/liveness
	    livenessProbe:
	      httpGet:
	        path: /healthz
	        port: 8080
	        httpHeaders:
	          - name: X-Custom-Header
	            value: Awesome
	      initialDelaySeconds: 15
	      timeoutSeconds: 1
	    name: liveness
    
### 应用的日志收集

## 集群的部署和管理

### 集群的部署

### 配置管理和环境变量

### 资源的管理和配额

### 垃圾回收
#### 镜像回收

可以通过设置Kubelet的启动参数`--image-gc-high-threshold`和`--image-gc-low-threshold`来设置镜像回收阈值。当磁盘的占用比例超过由参数`--image-gc-high-threshold`指定的阈值时（默认为90），就会启动镜像收集。镜像收集工具会按照镜像最后使用的先后顺序来删除镜像，越久没有使用的镜像越先删除，直到磁盘的占用比例低于由参数`--image-gc-low-threshold`指定的阈值（默认为80）。

#### 容器收集
可以通过设置Kubelet的启动参数`--minimum-container-ttl-duration`、`--maximum-dead-containers-per-container`以及`--maximum-dead-containers`来设置容器的收集。其中参数`--minimum-container-ttl-duration`用于标识一个容器停止后，最短多长的时间会被容器收集删除掉；参数`--maximum-dead-containers-per-container`用于控制每一个容器可以保留的停止容器的个数；参数`--maximum-dead-containers`用于控制节点上允许保留的停止容器的最大个数。需要注意的是，保留一定的停止容器可以方便收集日志以及调查容器结束的原因。

### 集群的监控和健康检查

### 集群的日志收集

### 集群的升级
#### 需要升级API版本
当需要升级集群以支持新版本的API时，可以通过以下的方式来进行不停服务的平滑升级:

1. 打开API新版本的的支持
	使用API Server的启动参数`--runtime-config`来开启新版本API的支持
2. 更新集群存储以使用新版本
	使用API Server上的环境变量`KUBE_API_VERSIONS`或者API Server的启动参数`--storage-versions`设置写入对象时使用的API版本，将希望使用的API版本，移动到列表的前面
3. 更新所有的配置文件
   更新Pod、RC等对象的配置文件，可以使用下面的命令来进行更新`kubectl convert -f pod.yaml --output-version v1`
4. 将存储中的对象更新到新版本
	使用Kubernetes提供的脚本`update-storage-objects.sh`来更新存储（ETCD）已经存在的对象
5. 关闭API旧版本的支持
	使用API Server的启动参数`--runtime-config`来关闭旧版本API的支持
#### 不需要升级API版本

#### 节点维护
当需要重启节点时，可以采用如下的方式来避免服务的中断：

1. 将节点标记为不可调度
为了避免在节点重启的过程中，调度器将Pod调度到此节点，可以使用下面的命令，将节点标记为不可调度：
	
		kubectl patch nodes $NODENAME -p '{"spec": {"unschedulable": true}}'
		或者
		kubectl replace nodes $NODENAME --patch='{"apiVersion": "v1", "spec": {"unschedulable": true}}'
		
2. 迁移运行在节点上的Pod
对于Pod的迁移需要分为两种不同的情况来考虑：

	* RC创建的Pod
	对于通过RC创建的Pod，由于RC能够保证其托管的Pod被删除时，能够立即创建新的Pod并且调度到其它节点上，所以对于这类Pod可以简单的直接删除即可。 可以使用下面的命令删除Pod：
		
			kubelete delete pod $PODNAME 

	* 独立的Pod
	对于独立的Pod，迁移的工作相对比较麻烦，在将其删除之前，首先需要创建一个新的替代Pod，然后在创建的Pod成功启动之后，更新各种对Pod的引用关系， 最后才能够将其删除。

3. 重新将节点标记为可调度
在节点重启完毕之后，可以使用下面的命令，将节点标记为可调度，以确保调度器能够将Pod调度到此节点：

		kubectl patch nodes $NODENAME -p '{"spec": {"unschedulable": false}}'
		或者
		kubectl replace nodes $NODENAME --patch='{"apiVersion": "v1", "spec": {"unschedulable": false}}'
#### 节点升级
对于需要升级Kubelet、Kube-Proxy的情况，与节点维护基本相似，如果操作能够在短时间内完成，可以不需要迁移运行在节点上的Pod。在默认情况下（由ControllerManager的启动参数`node-monitor-grace-period`控制），40秒之内，节点与API Server断开连接，API Server不会将节点标记为删除。
		
### 集群的扩容和缩容
## 存储
### CephFS
1. 创建数据池
可以使用下面的命令创建文件系统的数据池:

		ceph osd pool create cephfs_data $PG_NUM $PGP_NUM
2. 创建元数据池
可以使用下面的命令创建文件系统的元数据池：

		ceph osd pool create cephfs_metadata $PG_NUM $PGP_NUM

3. 创建CephFS
可以使用下面的命令创建文件系统：

		ceph fs new cephfs $NAME_POOLMETADATA $NAME_POOLDATA

	*注意：注意一个Ceph集群只能创建一个文件系统*
	
	创建完成之后，可以使用命令`ceph fs ls`查看创建的文件系统，如果创建成功，则上述命令可能会返回下面的结果：

		name: cephfs, metadata pool: cephfs_metadata, data pools: [cephfs_data ]

4. 将CephFS的根目录挂载到Pod中
	
		apiVersion: v1
		kind: Pod
		metadata:
		  name: cephfs2
		spec:
		  containers:
		  - name: cephfs-rw
		    image: kubernetes/pause
		    volumeMounts:
		    - mountPath: "/mnt/cephfs"
		      name: cephfs
		  volumes:
		  - name: cephfs
		    cephfs:
		      monitors:
		      - 10.16.154.78:6789
		      - 10.16.154.82:6789
		      - 10.16.154.83:6789
		      user: admin
		      secretRef:
		        name: ceph-secret
		      readOnly: true
		      
5. 将CephFS的子目录挂载到Pod中

	      
#### 配额管理
1. 创建用户
2. 

#### 权限管理
mon = "allow r" 
osd = "allow rw pool=guest01-data, allow r pool=common-data" 
mds = "allow rw tree=/guests/guest01, allow r tree=/guests/common" 
ceph-fuse -r /zhi_test /mnt/cephfs      
## 网络
优先级低
## 安全

## 高可用

## 大规模集群