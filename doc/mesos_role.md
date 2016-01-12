
#使用Mesos角色（Roles）将Mesos集群资源拆分到多个K8s Framework
##Mesos角色简介
在Mesos中，角色可以理解为资源(Resources)池，每一个角色中都关联了划分给此角色的资源，每一个Mesos Framework都可以冠以一个或者多个角色，从而实现Framework可以从一个或者多个“资源池”中获取资源。由于关联到角色上的资源是互不相交的，从而可以通过将特定的资源关联到特定的角色并且将特定的Framework冠以特定的角色的方式来实现多个Framework之间的资源隔离。

例如，假设有8CPU的资源，如果资源按照如下的方式关联到角色

|角色|资源|
|---|---|
|Role1|2CPU|
|Role2|4CPU|
|*|2CPU|

Framework按照如下的方式分配角色

|Framework|角色|
|---|---|
|Framework1|Role1|
|Framework2|*,Role2|
那么对于Framework1而言，则只能从Role1关联的2CPU中分配资源，而Framework2，则可以从Role2和`*`关联的6CPU(4CPU+2CPU)中分配资源。

Mesos通过引入预定（Reservation）的概念来将资源关联到角色，根据指定的方式和时机不同，预定分为静态预定（Static Reservation）和动态预定（Dynamic Reservation），其中静态预定在Slave启动时指定，一旦指定，除非重新启动Slave，否则无法修改预定策略。关于预定的详细信息，可以点击[链接](http://mesos.apache.org/documentation/latest/reservation/)查看。

在默认情况下，所有资源都被`*`角色预定，而所有Framework都被分配了`*`角色。
##如何实现
###定义角色
可以通过Mesos Master的启动参数`--roles`来定义角色，多个角色之间使用逗号分隔。需要注意的是：

- 角色一旦定义，除非重新启动Master，否则无法修改角色定义
- 如果存在Mesos高可用集群，则集群中的各个Master的角色定义必须一致
###定义Mesos Slave的默认角色
在默认情况下，Slave默认将所有的可用资源都指定给角色`*`，如果希望Slave将资源默认指定给特定角色，则可以通过指定Slave的启动参数`--default_role`来指定默认角色。

例如,下面的语句则将该Slave的所有可用资源默认指定给角色`role1`:
      
    mesos-slave --default=role1
###将角色关联到Framework
在默认情况下，所有的Framework都默认被指定了角色`*`，对于K8s而言，可以通过`--mesos-role`启动参数来指定角色。
例如，使用如下语句，则将K8s的Mesos角色指定为`role1`:
    
    km scheduler --mesos-role=role1
##实施指南
1. 定义角色
根据K8s Framework的个数，定义同等数量的Mesos角色，假设有两个K8s Framework，则使用如下方式定义: 

        mesos-master --roles="kubernate1,kubernete2"
2. 将Slave的可用资源分配到不同的角色
根据需求，通过指定slave的默认角色，将Slave的资源分配到不同的角色，例如：

        mesos-slave --default_role="kubernete1"
        或者
        mesos-slave --default_role="kubernete2"
3. 指定K8s的Mesos角色
通过指定K8s的Mesos角色，将指定Mesos角色的资源指定给特定的K8s Framework，例如:

        km scheduler --mesos-role="kubernete1"
        或者
        km scheduler --mesos-role="kubernete2"