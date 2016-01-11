# Kubernetes-Mesos #

# Kubernetes #

当我们需要做一个集群（scale）网络应用，如果这放在几年前，我们必须先创建 VM 镜像，对 虚拟机实例 进行编排，进行负载均衡等等。
这很复杂，在这时候我们可以使用一些自动化部署工具 如 Chef、Puppet、Ansible 以及 Salt 来帮助我们管理机器。但是在虚拟机上启动速度还是太慢。

相比于虚拟机，容器更加轻量级，构建起来更加有效率。但是 容器 需要更好的管理和调度系统， 如当一个容器崩溃时，他需要被平滑地替换掉。
Kubernetes 就是为了解决这样的问题而被创造的。


The challenge shifts from configuration management to orchestration, scheduling, and isolation. A failure of one computing unit cannot take down another (isolation), resources should be reasonably well balanced geographically to distribute load (orchestration), and you need to detect and replace failures near instantaneously (scheduling).

It is regularly said that in the new world of containers we should be thinking in terms of services (and sometimes micro-services) instead of applications.

Service is a process that:
1. is designed to do a small number of things (often just one).
2. has no user interface and is invoked solely via some kind of API.

An application, on the other hand, is pretty much the opposite of that. It has a user interface (even if it’s just a command line) and often performs lots of different tasks

A Kubernetes cluster does not manage a fleet of applications. It manages a cluster of services. You might run an application (often your web browser) that communicates with these services, but the two concepts should not be confused.

## 核心概念和术语 ##

### Node ##

Bunches of machines sit networked together in lots of data centers. Each of those machines is hosting one or more Docker containers. Those worker machines are called nodes.

A node usually runs three important processes:
1. Kubelet, A special background process (daemon that runs on each node whose job is to respond to commands from the master to create, destroy, and monitor the containers on that host.
2. Prox, This is a simple network proxy that’s used to separate the IP address of a target container from the name of the service it provides. 
3. cAdvisor (optional), [Container Advisor (cAdvisor)] is a special daemon that collects, aggregates, processes, and exports information about running containers. This information includes information about resource isolation, historical usage, and key network statistics.

### master

Other machines run special coordinating software that schedule containers on the nodes. These machines are called masters. Collections of masters and nodes are known as clusters.

Todo: 加入图片

The Master runs three main items:
1. Api Server, nearly all the components on the master and nodes accomplish their respective tasks by making API calls. These are handled by the API Server running on the master.
2. etcd, Etcd is a service whose job is to keep and replicate the current configuration and run state of the cluster. It is implemented as a lightweight distributed key-value store and was developed inside the CoreOS project.
3. Controller Manager & Scheduler, These processes schedule containers (actually, pods—but more on them later) onto target nodes; They also make sure that the correct numbers of these things are running at all times.

### Pod ##

A pod is a collection of containers and volumes that are bundled and scheduled together because they share a common resource—usually a filesystem or IP address.

In the standard Docker configuration, each container gets its own IP address. Kubernetes simplifies this scheme by assigning a shared IP address to the pod.
The containers in the pod all share the same address and communicate with one another via localhost.

Kubernetes schedules and orchestrates things at the pod level, not the container level.

That means if you have several containers running in the same pod they have to be managed together.

Pods are not durable things, and you shouldn’t count on them to be.

Sharing and preserving state between the containers in your pod, however, has an even easier solution: volumes.

### Volumn ##

A Kubernetes volume is defined at the pod level—not the container level.

Kubernetes currently supports a handful of different pod volume types

* EmptyDir, This type of volume is bound to the pod and is initially always empty when it’s first created. Since the volume is bound to the pod, it only exists for the life of the pod. When the pod is evicted, the contents of the volume are lost. Every container in the pod can read and write to this volume
* NFS, That was a particularly welcome enhancement because it meant that containers could store and retrieve important file- based data—like logs—easily and persistently
* GCEPersistentDisk (PD)

## 使用 kubernetes 编排

### Label & Annotation ##

Labels are queryable—which makes them especially useful in organizing things.

Annotations are bits of useful information you might want to store about a pod (or cluster, node, etc.) that you will not have to query.

Labels are used to store identifying information about a thing that you might need to query against. Annotations are used to store other arbitrary information that would be handy to have close but won’t need to be filtered or searched.

### Replication Controller ##

Multiple copies of a pod are called replicas. They exist to provide scale and fault-tolerance to your cluster.

The process that manages these replicas is the replication controller. Specifically, the job of the replication controller is to make sure that the correct number of replicas are running at all times. 

### Service ##

The replication controller is only concerned about making sure the right number of replicas is constantly running.

It doesn’t care if your public-facing application is easily findable by your users. Since it will evict and create pods as it sees fit, there’s no guarantee that the IP addresses of your pods will stay constant

A service is a long-lived, well-known endpoint that points to a set of pods in your cluster. It consists of three things—an external IP address (known as a portal, or sometimes a portal IP), a port, and a label selector.


### Namespace ##

kubernetes 通过将系统内部的对象分配到不同的 Namespace, 形成逻辑上分组的不同项目、小组或用户组，便于不同的分组在共享使用整个集群的资源的同时还能被分别管理。
可以用来解决多租户的问题。

kubernetes 启动后，会创建一个名为 default 的 namespace，通过 Kuberctl 可以查看到

~~~~~~
$ kubectl get namespaces
~~~~~~

# Mesos #

Mesos is an orchestration platform for managing CPU, memory, and other resources across a cluster. Mesos uses containerization technology, such as Docker and Linux Containers (LXC), to accomplish this. However, Mesos provides much more than that—it provides realtime APIs for interacting with and developing for the cluster.

It allows you to treat your cluster as a single, large group of resources.

It can be useful to think of Mesos as a deployment system. Distributed applications can be made into Mesos frameworks for use on a Mesos cluster.

Mesos offers flexibility and mitigates the risk of being outpaced by technology development; with Mesos, launching a Spark cluster or switching to a newer technology is as simple as launching the framework and watching it bootstrap itself.


## Frameworks

Applications that run on Mesos are called frameworks. A framework has two parts: the controller portion, which is called the scheduler, and the worker portion, which are called the executors.

To run a framework on a Mesos cluster, we must run its scheduler. A scheduler is simply a process that can speak the Mesos protocol;

When a scheduler first starts up, it connects to the Mesos cluster so that it can use the cluster’s resources. As the scheduler runs, it makes requests to Mesos to launch executors as it sees fit.

When a scheduler wants to do some work, it launches an executor. The executor is simply the scheduler’s worker: the scheduler then decides to send one or more tasks to the executor, which will work on those tasks independently, sending status updates to the scheduler until the tasks are complete. 

## Master and Slave

A Mesos cluster is comprised of two components: the Mesos masters and the Mesos slaves. The masters are the software that coordinates the cluster; the slaves are what execute code in containers.

### Mesos Master ###

The Mesos masters are the brain of the cluster.
* They are the central source of truth for running tasks.
* They fairly share the cluster between all the connected frameworks.
* They host the primary UI for the cluster.
* They ensure high availability and efficient allocation of resources. Considered together, they are a single point of failure, but Mesos automatically handles and recovers from individual master failures.

Losing a majority of the masters does force the Mesos cluster to operate in a “safe mode”—when a majority of the masters are down, frameworks will not be able to allocate new resources or launch new tasks; however, running tasks will continue as normal. This means that even during a master outage, as long as the frameworks in use can continue to function without launching new tasks, the cluster as a whole can offer uninterrupted service even as individual components fail.

### Slaves ###

The complement of the Mesos masters are the slaves. The slaves have a different set of responsibilities:
* They launch and manage the containers that host the executors (both LXC containers and Docker images).
* They provide a UI to access data from within the containers.
* They communicate with their local executors in order to manage communications with the Mesos masters.
* They advertise information about the hosts they’re running on, including information about running tasks and executors, available resources, and other metadata.
* They manage status updates from their tasks.
* They checkpoint their state to enable rolling restarts of the cluster.


## Resources

The fundamental abstraction in Mesos is that of the resource—tasks and executors consume resources while performing their work. 

The standard resources (and thus the resources that nearly every framework uses) are cpus, mem (memory), disk, and ports.

## Roles

In order to decide which resources can be offered to which frameworks, Mesos includes the concept of “roles.” A role is like a group: you can have the dgrnbrg role (for things you run), the qa role (for quality assurance-related tasks), the db role (for databases), and so on. 

## Task and Excutors

When a scheduler wants to do some work, it launches an executor. The executor is simply the scheduler’s worker: the scheduler can decide to send one or more tasks to an executor, which will work on those tasks independently, sending status updates to the scheduler until the tasks are complete.



## 案例 ##

### skydns，kubeui 核心组件运行

### nfs ceph 盘加载

### mysql 主从配置
