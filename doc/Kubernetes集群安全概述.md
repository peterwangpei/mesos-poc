# Kubernetes集群安全概述
## API的访问安全性
### API Server的端口和地址
在默认情况下，API Server通过**本地端口**和**安全端口**两个不同的HTTP端口，对外提供API服务，其中**本地端口**是基于HTTP协议的，用于在本机（API Server所在主机）**无限制**的访问API Server，而安全端口则是基于HTTPS协议的，用于远程**有限制**的访问API Server，下面就这两种端口做详细的介绍。

1. 本地端口（Localhost Port）
   
   在API Server的默认配置中，本地端口默认绑定到地址`127.0.0.1`上，所以，在默认情况下，本地端口只能在本机（API Server所在主机）访问，由于API Server不对任何通过本地端口的访问做任何权限控制（通过本地端口的访问绕过了认证和授权过程），换句话说，只要能够访问本地端口，任何人都可以通过本地端口无限制的访问API Server，基于安全性方面的考虑，在配置API Server时，尽量不要将本地端口绑定到地址`127.0.0.1`以外的地址上，以避免将本地端口暴露到本机以外。
   
   本地端口默认绑定到端口**8080**上,本地端口的绑定端口号可以通过API Server的启动参数`--insecure-port`来进行指定，如果将绑定的端口号指定为**0**，则表示关闭本地端口。另外，可以通过API Server的启动参数`--insecure-bind-address`来指定本地端口的绑定地址。
   
   **注意：在生产环境中尽量避免将本地端口绑定到`127.0.0.1`以外的地址，以避免带来不必要的安全问题。**
   
2. 安全端口（Secure Port）
 
 	顾名思义，安全端口是API Server对外提供的，用于外部访问的、安全的、可控的API调用接口，API Server只允许通过认证（Authentication）的用户才能够通过安全端口访问API Server，无论是认证为`User Account`或者`Service Account`都可以正常的通过安全端口访问API Server，但是对于尚未认证的匿名用户，当通过安全端口访问API Server时，服务端总是返回`401（Unauthorized）`，拒绝其后续访问。
 	
 	安全端口默认绑定到端口**6443**上,并且总是通过**HTTPS**协议对外提供服务。安全端口绑定的端口号可以通过API Server的启动参数`--secure-port`来进行指定，和本地端口的配置类似，如果将安全端口绑定的端口号指定为**0**，则表示关闭安全端口。安全端口默认绑定到地址`0.0.0.0`上（理论上应该是0.0.0.0/32，表示本机的所有源地址），当然也可以通过API Server的启动参数`--bind-address`来进行显示指定。
 	
 	由于安全端口是基于HTTPS协议对外提供服务的，当未显示指定HTTPS证书和私钥的情况下，API Server会自动在主机路径`/var/run/kubernetes`下生成用于HTTPS的自签名证书和私钥（版本1.2的Kubernetes生成的自签名证书和私钥文件分别为：apiserver.crt和apiserver.key），当然，如果希望使用指定的证书和私钥，则可以通过API Server的启动参数`--tls-cert-file`和`--tls-private-key-file`来分别指定。
  
### 代理和防火墙

在实际的生产环境中，可能存在现有的认证体系无法与Kubernetes集群集成或者需要执行特殊认证和授权逻辑的情况，在这种情况下，可以考虑引入代理（Proxy）来解决认证和授权的问题，在认证通过之后，代理将请求转发到API Server。根据，代理能否与API Server部署在同一台主机的不同，需要分为以下两种情况进行分别讨论。

#### 代理与API Server能够部署在同一台主机

当代理能够与API Server部署在同一台主机时，建议按照下面的方式进行集成：

* 关闭安全端口（将安全端口绑定到端口号**0**），确保所有的API请求只能通过代理接入
* 将本地端口绑定到地址`127.0.0.1`上，确保只能在本机访问
* 设置防火墙规则，仅开放本机的443端口
* 配置nginx监听443端口，并且在此端口上配置认证和HTTPS
* 配置nginx将请求转发到本地端口，默认情况下为`127.0.0.1:8080`

#### 代理与API Server无法部署在同一台主机

当代理无法与API Server部署在同一台主机时，从安全性的角度来看，再试图通过本地端口与API Server来集成将不会是一个好的选择，在这种情况下，使用安全端口与API Server集成成立唯一的选择。由于安全接口的认证和授权体系比较复杂，具体的集成方式在后续的内容中进行深入的讨论。

## 账号类型账号

Kubernetes根据**使用账号的进程是否在Pod内部运行**这个标准将账号划分为用于提供给外部进程使用的用户账号（User Accounts）和用于提供给内部进程使用的服务账号（Service Accounts），这两种不同的账号类型。

当进程在Pod内部运行时，一般建议该进程使用服务账号来访问API Server，而当进程运行在Pod之外甚至在Kubernetes集群之外时，则建议该进程使用用户账号来访问API Server；当然，这个标准并不是绝对的，例如，当Pod内部运行的进程使用用户账号来访问API Server时，并不会被API Server视为不合法而拒绝访问。

### 用户账号（User Accounts）

用户账号是一个非常传统的概念，可以简单的理解为用户名和密码，当调用方通过API Server提供的认证接口传入用户名、密码通过认证之后，调用方就扮演了这个用户与API Server进行交互。与一般的用户名的概念相同，在Kubernetes中，用户名在一个集群中是全局唯一的，也就是说在同一个集群中，只允许有一个指定名称的用户账号，而与集群中创建了多少个命名空间（Namespace）或者启动了多少个API Server无关。

此外，用户账号可以从数据库等第三方系统同步到进来，以实现与其它系统共享用户账号信息。

### 服务账号（Service Accounts）

从外在的表现来看，服务账号与用户账号的最大的不同点，表现在服务账号是命名空间唯一，而用户账号是整个集群唯一。在Kubernetes中，每一个命名空间都可以创建具有相同名称的服务账号，在默认情况下，每一个namespace在创建时，都会自动创建一个名为**default**的默认服务账号，如果在API Server开启了ServiceAccount插件的情况下（通过API Server的--admission-control启动参数指定），该默认服务账号会在Pod创建或者更新时，被自动的关联到该Pod上，并且自动的将默认服务账号的凭证（Token）部署到Pod中所有容器文件系统的目录`/var/run/secrets/kubernetes.io/serviceaccount/`下。

从实质上来看，服务账号与用户账号并没有本质上的不同，可以认为每一个服务账号的背后都自动关联了一个隐藏的用户账号，就以以默认服务账号为例，假设在默认命名空间下有一个默认服务账号（default），那么当某一个进程使用这个服务账号访问API Server时，可以简单理解为使用名为`system:serviceaccount:default:default`的用户账号来访问API Server，所以希望控制某一个服务账号的权限时，就可以简单的通过对名为`system:serviceaccount:<命名空间>:<服务账号名称>`的隐藏用户账号进行权限控制就可以达到目的。

**TODO** 实验服务账号是否可以采用与用户账号相同的认证方式

## 认证（Authentication）

1.2版本的Kubernetes，提供了客户端证书认证、Token认证、OpenID认证、HTTP基本认证以及[Keystone认证](http://docs.openstack.org/developer/keystone/)等五种不同的认证方式，下面将会就这些认证方式进行详细的介绍。

需要注意的是，这五种认证方式之间不是互斥的，同一个API Server允许同时开启一种或者多种不同的认证方式，并不会存在开启客户端证书认证而Token认证自动失效的情况，在开启多种认证的情况下，客户端可以自由的选择合适的认证方式来进行认证。

例如，假设服务器同时开启了客户端证书认证和Token认证，客户端可以仅仅传入合法的Token访问，也可以传入合法的证书私钥对访问，也可以同时传入Token和证书私钥对进行访问，当客户端同时使用多种认证方式同时认证时，只要一种认证方式通过认证，就可以继续访问，如果所有的认证方式都无法通过认证，则服务端会拒绝客户端继续访问。

**TODO**确认认证的优先级别

### 客户端证书认证（Client certificate authentication）

客户端认证的开启非常的简单，只需要通过API Server的启动参数`--client-ca-file`指定用于客户端认证的证书文件即可（注意：证书文件中可以包含一个或者多个证书）。

当客户端通过客户端证书认证后，用于认证证书的公用名（Common name of the subject）将作为用于后续访问的用户名。所以，当希望对于客户端证书认证用户进行权限控制时，对名为证书公用名的用户进行授权就是对客户端证书认证用户进行授权。

以下就以自签名证书为例，演示如何配置API Server的客户端证书认证：

1. 创建自签名证书

	可以使用如下的命令创建一个用于客户端认证的证书
	
	    openssl req \
	    -new \
	    -nodes \ 
	    -x509 \
	    -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=HuaWei/OU=PaaS/CN=batman" \
	    -days 3650 \
	    -keyout 私钥.key \
	    -out 证书.crt 
	    
	    说明：
	    /C    表示国家只能为两个字母的国家缩写，例如CN，US等
	    /ST   表示州或者省份
	    /L    表示城市或者地区
	    /O    表示组织机构名称
	    /OU   表示组织机构内的部门或者项目名称
	    /CN   表示公用名，如果用来作为SSL证书则应该填入域名或者子域名，
	          如果作为客户端认证证书则可以填入期望的用户名
2. 为API Server指定要应用的客户端认证证书
	将上一步创建的**证书文件**拷贝到API Server所在的主机，然后通过启动参数`--client-ca-file`将证书文件的路径传递给API Server。
3. 验证客户端认证证书
	
	可以使用如下命令来验证客户端认证是否起效：
		
		kubectl \
		--server=https://192.168.0.1:6443 \
		--insecure-skip-tls-verify=true \
		--client-certificate=证书.crt \
		--client-key=私钥.key \
		get nodes
		
		说明：
		--server                    用来指定API Server的地址，注意一定要使用安全端口
		--insecure-skip-tls-verify  表示不验证证书，当服务端证书为自签名证书时指定
		--client-certificate        指定客户端认证证书
		--client-key                指定客户端认证证书的私钥


### Token认证（Token File）

Token认证的开启也同样非常简单，只需要通过API Server的启动参数`--token-auth-file`指定包含Token信息的Token文件即可。Token文件是一个3到4列的csv文件，这个csv文件中，从左到右分别为Token、用户名(User Name)、用户UID（User UID）以及用户所属的组，其中前3列为必须列，用户组列为可选列，如果用户隶属于多个组，则需要将所有的组名通过双引号括起来：
		
	token,user name,uid,"group1,group2,grooup3"

需要注意的是，Token认证没有过期的概念，所有的Token理论上可以认为永不过期，另外，除非重启API Server，否则无法更新或者删除Token。

以下演示如何配置Token认证：

1. 创建Token文件
   我们通过手工创建内容如下的Token文件:
   	
   		demo,demo,demo,demo
   
2. 为API Server指定要应用的Token文件
	将上一步创建的Token文件拷贝到API Server所在的主机，然后通过启动参数`--token-auth-file`将Token文件的路径传递给API Server。
3. 验证Token认证
	
	可以使用如下命令来验证Token认证是否起效：
		
		kubectl \
		--server=https://192.168.0.1:6443 \
		--insecure-skip-tls-verify=true \
		--token=demo
		get nodes
		
		或者
		
		curl \
		-k \
		-H "Authorization: Bearer demo" \
		https://192.168.0.1:6443/api/v1/nodes
### OpenID认证（OpenID Connect ID Token）

OpenID认证的开启相对比较复杂，开启OpenID认证需要设置如下几项启动参数：

* --oidc-issuer-url（必须指定）
  
  用于指定用于提供OpenID认证服务的服务地址。**注意：**服务地址必须为HTTPS的URL。
* --oidc-client-id （必须指定）
  用于指定 
**TODO**

### HTTP基本认证（HTTP Basic Authentication）

HTTP基本认证的开启也同样非常简单，只需要通过API Server的启动参数`--basic-auth-file`指定包含用户信息的用户配置文件即可。用户配置文件是一个3列的csv文件，这个csv文件中，从左到右分别为Token、用户名(User Name)、用户ID（User ID）：
		
	password,user name,user id

需要注意的是，HTTP基本认证和Toke认证一样没有过期的概念，所有只有重启API Server才能更新或者删除用户信息。此外，HTTP基本认证是作为便利性方面的考虑才加以支持的，在正式生产环境中应该优先考虑上述的几种认证方式。

以下演示如何配置HTTP基本认证：

1. 创建用户配置文件
   我们通过手工创建内容如下的用户配置文件:
   	
   		password,zhangsan,zhangsan
   
2. 为API Server指定要应用的HTTP基本认证用户配置文件
	将上一步创建的用户配置文件拷贝到API Server所在的主机，然后通过启动参数`--basic-auth-file`将用户配置文件的路径传递给API Server。
3. 验证HTTP基本认证
	
	可以使用如下命令来验证HTTP基本认证是否起效：
		
		kubectl \
		--server=https://192.168.0.1:6443 \
		--insecure-skip-tls-verify=true \
		--username=zhangsan
		--password=password
		get nodes
		
		或者
		
		curl \
		-k \
		-u zhangsan:password \
		https://192.168.0.1:6443/api/v1/nodes

### Keystone认证（Keystone Authentication）

Keystone认证的开启非常简单，只需要通过API Server的启动参数`--experimental-keystone-url`指定Keystone服务提供的认证地址即可。由于目前版本的（版本1.2）Kubernetes对Keystone认证的支持还处于试验状态，在这里就不进行详细的介绍了，详细的信息可以参考[Keystone官方文档](http://docs.openstack.org/developer/keystone/)。

### Kubeconfig文件

在测试环境中，Slave（Kubelet）一般通过本地端口与API Server集成，但是在正式生产环境中，基于安全性方面的考虑，一般都会选择关闭API Server的本地端口或者只允许在API Server所在主机上访问本地端口，在这种情况下Slave只能通过安全端口与API Server集成。

为了能够通过安全端口与API Server集成，Kubelet提供了`--client-certificate`、`-client-key`、`--username`、`--password`以及`--token`等启动参数来支持上述认证方式，通过这些启动参数，Kubelet可以选择一种当前API Server提供的认证方式通过安全端口与API Server集成。

虽然上述的方式能够实现Kubelet与API Server的集成，但是配置上稍显复杂，需要在Kubelet的启动参数中指定很多的认证信息。为了简化配置以及方便在多个集群之间进行切换，Kubelet支持一种名为kubeconfig的机制，可以将集群信息、认证信息等配置信息保存到一个或者多个YAML格式的配置文件中（默认配置文件的路径为`/var/lib/kubelet/kubeconfig`），具体的信息可以参看[Kubeconfig](http://kubernetes.io/docs/user-guide/kubeconfig-file/)。
在配置合理的情况，可以不需要指定Kubelet的任何启动参数，Kubelet就可以顺利的加入到集群中。

以下为一个配置文件的示例：

	apiVersion: v1
	kind: Config
	clusters:
	  #集群配置信息，可以通过--cluster参数指定使用
	  - cluster:
	      api-version: v1
	      server: https://192.168.0.150:6443
	      insecure-skip-tls-verify: true
	    name: local
	contexts:
	  #集群上下文配置信息，可以通过--context参数指定使用
	  - context:
	      #表示加入到哪一个集群
	      cluster: local
	      #表示引用哪个用户进行进行认证
	      user: kubelet
	    name: service-account-context
	users:
	  #配置用户信息，用户名可以通过--user启动参数指定使用
	  - name: kubelet
	    user:
	       #以下认证任选一种
	       token: Token认证
	       username: HTTP基本认证用户名
	       password: HTTP基本认证密码
	       client-certificate: 客户端认证证书
	       client-key: 客户端认证私钥
	#默认使用的上下文名称
	current-context: service-account-context

## 授权（Authorization）

在Kubernetes中，授权和认证是两个相互相对独立的过程，当客户端通过**安全端口**访问API Server时，API Server会对客户端发起的请求进行认证，如果请求无法通过认证，哪怕后续的授权过程不对请求做任何限制（AlwaysAllow），该请求任然会被API Server拒绝，只有当请求通过认证之后，才会轮到授权插件来对请求进行权限校验。

Kubernetes的授权是通过插件的方式来实现的，，目前Kubernetes内置提供了AlwaysDeny、AlwaysAllow、ABAC以及WebHook等四种不同的授权插件，用户可以通过赋予API Server启动参数`--authorization-mode`授权插件的名称来指定希望启用的授权模式，下面，就这些授权模式做进一步的详解介绍。

### AlwaysDeny

顾名思义，当API Server的授权模式设置为AlwaysDeny模式时，服务端将会拒绝任何对**安全端口**的请求，以前面介绍的Token认证的例子为例，当服务端的授权模式设置为**AlwaysDeny**时，再使用命令`curl -k --H "Authorization: Bearer demo" https://192.168.0.1:6443/api/v1/nodes`
访问服务端时，服务端总是返回`Forbidden: "/api/v1/nodes"`，表示访问被拒绝。

AlwaysDeny模式主要用于测试，当然也可以用来暂时停止集群的对外服务。

### AlwaysAllow

与AlwaysDeny模式相反，当API Server的授权模式设置为AlwaysAllow模式时，只要通过认证，服务端将会接受任何对**安全端口**的请求，换句话说就是除了认证没有任何权限限制。

当集群不需要授权时，则可以考虑将授权模式设置为AlwaysAllow模式，以降低配置的复杂性。

### ABAC（基于属性的访问控制）

ABAC是英文Attribute-based access control的缩写，ABAC的核心是根据请求的相关属性，例如用户属性、资源属性以及环境属性等属性，作为授权的基础来进行访问控制，以解决分布式系统的可信任关系的访问控制问题。

基于身份的访问控制（Identity-based access control）和基于角色的访问控制（Role-based access control）都可以认为是ABAC的一个单属性特例。

目前，Kubernetes主要根据请求的以下几个属性进行授权：

* 用户名
* 用户组
* 是否访问资源
* 请求的地址
* 是否访问杂项接口（Miscellaneous Endpoints）
* 对资源的请求动作类型（Request Verb）
* 对非资源的HTTP动作类型（HTTP Verb）
* 访问的资源类型
* 访问对象所属的命名空间（Namespace）
* 访问的API的所属API组（API Grooup）

如果需要启用ABAC授权模式，首先需要通过将API Server的启动参数`--authorization-mode`设置为`ABAC`将授权模式设置为ABAC，然后通过API Server的启动参数`--authorization-policy-file`将
ABAC的策略文件路径传递给API Server。

ABAC的策略文件是一个[one JSON object per line](http://jsonlines.org/)格式的文本文件，下面就是一个策略文件的例子：

	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "*","nonResourcePath": "*","readonly": true } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "admin","namespace": "*","resource": "*","apiGroup": "*" } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "scheduler","namespace": "*","resource": "pods","readonly": true } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "scheduler","namespace": "*","resource": "bindings" } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "kubelet","namespace": "*","resource": "pods","readonly": true } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "kubelet","namespace": "*","resource": "services","readonly": true } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "kubelet","namespace": "*","resource": "endpoints","readonly": true } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "kubelet","namespace": "*","resource": "events" } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "alice","namespace": "projectCaribou","resource": "*","apiGroup": "*" } }
	{ "apiVersion": "abac.authorization.kubernetes.io/v1beta1","kind": "Policy","spec": { "user": "bob","namespace": "projectCaribou","resource": "*","apiGroup": "*","readonly": true } }

ABAC的授权过程可以简单的理解为将请求属性转换为一个**spec**对象，然后拿到这个spec对象与策略文件中定义的spec对象进行匹配，如果这个**spec**对象能够与策略文件中定义的任何一条规则允许的**spec**对象匹配，那么授权通过；如果这个**spec**对象无法与任何一条规则匹配，那么授权失败。

下面是一个完整的spec对象的例子：
  
   	{
   		"apiVersion": "abac.authorization.kubernetes.io/v1beta1",
   		"kind": "Policy",
   		"spec": 
   		{
   			"user": "用户名"，
   			"group": "用户组"，
   			"readonly": "是否只读"，
   			"apiGroup": "访问的API所属的API组"，
   			"namespace": "访问对象的所属命名空间",
   			"resource": “访问的资源类型”,
   			"nonResourcePath": "访问的非资源路径"
   		}
   	}

假设只允许名为`bob`的用户读取命名空间`projectCaribou`下的`Pod`信息，则可以创建如下规则：

	{
		"apiVersion": "abac.authorization.kubernetes.io/v1beta1", 
		"kind": "Policy",
		 "spec": 
		 {
		 	"user": "bob",
		 	"namespace": "projectCaribou", 
		 	"resource": "pods",
		 	"apiGroup": "*", 
		 	"readonly": true 
		 }
	}
	
以下面的策略配置为例：

	{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"zhangsan", "namespace": "*","resource": "pods","apiGroup": "*","readonly": true }}
	{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"admin", "namespace": "*","resource": "*","apiGroup": "*","readonly": true, "nonResourcePath": "*" }}
	{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"lisi", "namespace": "*","resource": "nodes","apiGroup": "*","readonly": true }}
	
相当于定义了如下规则：

| 用户 | 能力 |
|------|------|
|zhangsan|允许读取Pod信息|
|admin|允许读取所有资源信息|
|lisi|允许读取Node信息|

请求在转换为**spec**对象的过程中，如果某一个属性请求具备多值，例如**group**属性，那么可以理解为将请求转换为多个**spec**对象，每一个对象持有多值属性中的一个值，然后这些对象分别于策略文件进行匹配，只要任何一个对象匹配通过，则请求授权通过。对于请求无法提供的属性，例如**group**属性，那么在转换为**spec**对象的过程中该属性被设置为该属性声明类型的默认值，例如，字符串类型的属性设置为空字符串，而整数型的属性设置为0。

规则文件中，可以使用`*`来进行通配，例如，在规则中出现如下定义`"user": "*"`，则表示该规则匹配任何用户，也就是说任何用户的请求，在用户名这一项上该规则都匹配。需要注意的是，缺省不代表匹配任何项，当某一个属性缺省时，可以理解为该属性设置为默认值。

在上面的介绍中，有人可能会有疑惑：为什么要将请求路径划分为资源和非资源路径两种不同的属性？原因是:Kubernetes实现了一种名[API Group](http://kubernetes.io/docs/api/)的特性，由于这种特性导致了同一种资源可能有N个入口可以访问，以Pod为例，用户可能通过地址`https://192.168.0.1:6443/api/v1/pods`访问，也可以通过地址`https://192.168.0.1:6443/api/v1/namespaces/default/pods`访问，如果依靠请求地址来控制资源的访问的话，会导致规范定义的极速膨胀；此外，一旦增加了新的API组，又会导致同一个资源的访问增加大量的请求地址，所以从易用性以及性能等方面的考虑，对于资源直接使用资源类型进行控制是相对较好的一种方案。

由于非资源的请求地址相对固定，不会存在这个问题，而且又没有关联的可供识别的对象，所以对于非资源请求使用访问地址来做限制就是一种显而易见的选择了。

### WebHook

WebHook模式是一种扩展授权模式，在这种模式下，API Server将授权过程委派到外部的一个REST服务，由外部的服务决定是否授予指定请求继续访问的权限。

WebHook模式的开启非常的简单，只需要通过API Server的启动参数`--authorization-mode`设置为`WebHook`并且通过启动参数`--authorization-webhook-config-file`将外部授权服务的配置信息告诉API Server即可。

由于WebHook模式的授权策略完全由外部授权服务来决定，在这里就不进行详解的介绍，具体的信息可以参看[Kubernetes官方文档](http://kubernetes.io/docs/admin/authorization/#kubectl)。

### 自定义插件

此外，Kubernetes也支持通过开发新的插件的方式支持新的授权模式，插件的开发非常简单，只需要实现如下接口即可，在这里就不做展开讨论：
		
	type Authorizer interface {
  		Authorize(a Attributes) error
	}

### 如何识别各种认证方式的用户名和用户组
**TODO** 需要进一步验证

| 认证方式 | 用户名 | 用户组 |
|---|---|---|
| 客户端证书认证 | 证书的公共名 | 无 |
| Token认证 | Token文件中指定的用户名 | Token文件中指定的用户组 |
| HTTP基本认证 | 配置文件中指定的用户名 | 无 |
| OpenID认证 | 通过启动参数`--oidc-username-claim`指定 | 通过启动参数`--oidc-groups-claim`指定 |	

## Secret
在实际的生产环境中，在大多数情况下，容器都不是孤立存在的，一般都需要与其它服务或者系统进行通讯或者集成，而其它服务或者系统一般都需要调用者提供密码、认证Token以及SSH秘钥等信息来确保信息安全。

在常规的容器化实践中，一般采用环境变量、命令行参数、挂载文件甚至直接Build到镜像中等方式将这些敏感信息传递到容器中，以达到容器能够在运行中获得这些敏感信息的目的。然而，上述的方式存在容易泄露、难以变更以及维护困难等问题，为了解决这些问题，在Kubernetes中引入了秘密（Secret）的概念。

在Kubernetes中，秘密可以简单的理解为一个命名对象，在这个对象中保存了特定的敏感信息，用户可以简单的通过Pod定义文件、Service Account甚至在运行中动态获取等方式，在容器获得秘密中保存的敏感信息。此外，通过Pod定义文件、服务账号等静态方式挂接在Pod上的秘密，在Pod没有启动之前，任何对秘密的更改都会在Pod启动之后直接反应到Pod中，而在Pod启动之后的更改，则需要重新启动Pod。

目前，Kubernetes提供了以下三种不同的秘密：

* 不透明秘密（Opaque Secret）

	不透明秘密可以简单的理解为可以随便放任何数据的字典，Kubernetes只是简单的将秘密中包含的数据传递到包含在Pod中的容器，具体的内容只有提供方和使用方能够理解。需要注意的是，单个秘密的大小上限是**1MB**，如果希望传递更多的内容，可以考虑将内容拆分到多个小的秘密中。
	
* API Token Secret

	API Token一般与服务账号配对使用，通过[准入控制](http://kubernetes.io/docs/admin/admission-controllers/)（Admission Control）提供的`Service Account`插件自动的将API Token挂载到容器中（默认挂载到容器的`/var/run/secrets/kubernetes.io/serviceaccount/`路径下），以实现在容器中能够有权限访问API Server。当然，在不使用准入控制的情况下，也可以采用与其它秘密相同的方式挂载到容器中。
	
* imagePullSecret

imagePullSecret用来保存镜像仓库的认证信息，以方便`Kubelet`在启动Pod时，能够获得镜像仓库的认证信息，确保能`Kubelet`够有权限从镜像仓库中下载Pod所需的镜像。

此外，为了确保镜像的安全以及保证只有授权的用户才能给使用特定的镜像，建议在生产环境中启用准入控制的`AlwaysPullImages`插件，当启用这个插件时，将无视Pod定义中的镜像下载策略（imagePullPolicy），强制`Kubelet`总是从镜像仓库中下载镜像，而不使用本地镜像，从效果上看相当于将Pod定义中的镜像下载策略设置为`Always `。

### Opaque Secret

#### 创建
* 通过命令行创建（Kubernetes 1.2新增加的特性）

	假设需要将以下MySQL的连接信息通过秘密传入到容器中：
	
		db-user-name：mysql
		db-user-pass：password
		db-address：192.168.0.1:3306
		db-name：database
	
	可以采用下面的命令创建秘密：
	
	   	通过文件创建
	   	echo "mysql" > ./username.txt
	   	echo "password" > ./password.txt
	   	echo "192.168.0.1:3306" > ./address.txt
	   	echo "database" > ./name.txt
	   	
	   	./kubectl create secret \
	   	generic mysql-database-secret \
	   	--from-file=db-user-name=./username.txt \
	   	--from-file=db-user-pass=./password.txt \
	   	--from-file=db-address=./address.txt \
	   	--from-file=db-name=./name.txt	   	
	   	
	   	也可以通过字面参数直接创建
	   	
	   	./kubectl create secret \
	   	generic mysql-database-secret \
	   	--from-literal=db-user-name=mysql \
	   	--from-literal=db-user-pass=password \
	   	--from-literal=db-address=192.168.0.1:3306 \
	   	--from-literal=db-name=database
	   	
	如果创建成功，则可以使用命令`./kubectl describe secret mysql-database-secret`查看创建的秘密：
	
		Name:		mysql-database-secret
		Namespace:	default
		Labels:		<none>
		Annotations:	<none>

		Type:	Opaque

		Data
		====
		db-name:	9 bytes
		db-user-name:	6 bytes
		db-user-pass:	9 bytes
		db-address:	17 bytes
		
* 通过定义文件创建

	创建如下内容的YAML文件，然后使用命名`./kubectl create -f 文件路径`即可创建秘密，其中的数据内容是各项数据的Base64编码，可以简单的利用如下命令`echo 内容 | Base64`，生成指定内容的Base64编码。
	
		apiVersion: v1
   		data:
  		  db-address: MTkyLjE2OC4wLjE6MzMwNg==
  		  db-name: ZGF0YWJhc2U=
  		  db-user-name: bXlzcWw=
  		  db-user-pass: cGFzc3dvcmQ=
		kind: Secret
		metadata:
  		  name: mysql-database-secret
  		  namespace: default
       type: Opaque

#### 更新
相对于创建而言，更新只能通过文件来实现了，简单的方式是首先使用如下的命名导出秘密定义：
		
	./kubectr get secret mysql-database-secret -o yaml > mysql-database-secret.yaml
	或者
	./kubectr get secret mysql-database-secret -o json > mysql-database-secret.json

然后在更新文件内容之后，再使用如下命令更新秘密：

	./kubectl replace -f mysql-database-secret.yaml
	或者
	./kubectl replace -f mysql-database-secret.json	
#### 使用
##### 挂载为文件

针对上一步创建的秘密，可以通过如下的定义直接挂载到容器的文件系统中：

	apiVersion: v1
	kind: Pod
	metadata:
  	  name: demo
	  spec:
  	    containers:
  	      - name: demo
  	        imagePullPolicy: IfNotPresent
      		 image: image
           volumeMounts:
             - name: mysql
               mountPath: /etc/mysql
               readOnly: true
       volumes:
         - name: mysql
           secret:
             secretName: mysql-database-secret
             
挂载成功之后可以，在容器的文件系统中看到秘密的内容：

	docker exec -it containerId ls /etc/mysql
	
	db-address  db-name  db-user-name  db-user-pass
	
	docker exec -it containerId cat /etc/mysql/db-user-pass
	password
	
##### 挂载为环境变量

可以采用下面的定义直接将秘密挂载为环境变量：

	apiVersion: v1
	kind: Pod
	metadata:
  	  name: demo
	  spec:
  	    containers:
  	      - name: demo
  	        imagePullPolicy: IfNotPresent
      		 image: image
      		 env:
		        - name: SECRET_USERNAME
		          valueFrom:
		            secretKeyRef:
		              name: mysql-database-secret
		              key: db-user-name
		        - name: SECRET_PASSWORD
		          valueFrom:
		            secretKeyRef:
		              name: mysql-database-secret
		              key: db-user-pass
		        - name: SECRET_NAME
		          valueFrom:
		            secretKeyRef:
		              name: mysql-database-secret
		              key: db-name
		        - name: SECRET_ADDRESS
		          valueFrom:
		            secretKeyRef:
		              name: mysql-database-secret
		              key: db-address
                   
然后使用如下命令，就可以看到秘密的内容已经挂载为环境变量：

	docker exec -it containerId env
	
	PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	HOSTNAME=nginx
	SECRET_USERNAME=mysql
	SECRET_PASSWORD=password
	SECRET_NAME=database
	SECRET_ADDRESS=192.168.0.1:3306
	KUBERNETES_SERVICE_PORT_HTTPS=443
	KUBERNETES_PORT=tcp://172.0.0.1:443
	KUBERNETES_PORT_443_TCP=tcp://172.0.0.1:443
	KUBERNETES_PORT_443_TCP_PROTO=tcp
	KUBERNETES_PORT_443_TCP_PORT=443
	KUBERNETES_PORT_443_TCP_ADDR=172.0.0.1
	KUBERNETES_SERVICE_HOST=172.0.0.1
	KUBERNETES_SERVICE_PORT=443
	...
		
##### 自动挂载

目前Opaque Secret尚未实现自动挂载，也许在Kubernetes的后续版本中会提供这个功能，具体的信息可以参看[Issue 9902](http://issue.k8s.io/9902)。

### imagePullSecret

#### 创建
imagePullSecret的创建和更新方式与Opaque Secret的创建和更新方式类似，支持在创建和更新中一些参数稍有区别。

下面是一个完整的YAML格式的imagePullSecret定义文件：
	
		apiVersion: v1
		data:
		  .dockercfg: eyJET0NLRVJfUkVHSVNUUllfU0VSVkVSIjp7InVzZXJuYW1lIjoiRE9DS0VSX1VTRVIiLCJwYXNzd29yZCI6IkRPQ0tFUl9QQVNTV09SRCIsImVtYWlsIjoiRE9DS0VSX0VNQUlMIiwiYXV0aCI6IlJFOURTMFZTWDFWVFJWSTZSRTlEUzBWU1gxQkJVMU5YVDFKRSJ9fQ==
		kind: Secret
		metadata:
		  name: local-registry-secret
		  namespace: default
		type: kubernetes.io/dockercfg

上面的定义文件中有两点需要注意：

1. Secret的类型
	
	imagePullSecret的类型为`kubernetes.io/dockercfg`
2. Secret的数据
	
	imagePullSecret中只包含一个名为`.dockercfg`的数据，**注意**，这个名称是固定的,而具体的内容是以下内容的Base64编码：
		
		{
			"DOCKER_REGISTRY_SERVER":
			{
				"username":"用户名",
				"password":"密码",
				"email":"邮件地址",
				"auth":"RE9DS0VSX1VTRVI6RE9DS0VSX1BBU1NXT1JE"
			}
		}
	其中`auth`属性是必须的，明文部分除了邮件地址以外，用户名和密码这两个属性都可以不要，而`auth`属性的值就是`用户名:密码`的简单Base64编码，可以使用如下命令简单生成：
	
		echo 用户名:密码 | base64
	
	以下是最小内容的示例：
	
		{
			"DOCKER_REGISTRY_SERVER":
			{
				"username":"用户名",
				"password":"密码",
				"email":"邮件地址",
				"auth":"RE9DS0VSX1VTRVI6RE9DS0VSX1BBU1NXT1JE"
			}
		}
	
	此外，还可以通过Docker提供的`login`命令生成imagePullSecret的内容，以下为通过Docker生成的示例命令：
	
		docker login -u 用户名 -p 密码 -e 邮件地址 镜像库地址
		
	命令的执行结果会写入到如下路径：
	
		~/.docker/config.json
		
	最后通过如下命令就可以简单生成imagePullSecret的内容了：
	
		cat ~/.docker/config.json | base64
	
	此外，还可以通过`kubectl`命令来生成imagePullSecret，下面是命令的示例：
	
		./kubectl create secret docker-registry \
		镜像下载秘密名称 \
		--docker-server=镜像库地址 \
		--docker-username=用户名 \
		--docker-password=密码 \
		--docker-email=邮件地址 \
		-s API Server地址

#### 使用

imagePullSecret的使用方式与Opaque Secret的挂载方式不同，由于imagePullSecret用于提供给`kubectl`来下载镜像，而不需要挂载到容器中，所以对于imagePullSecret而言，只需要在Pod定义中声明使用即可。在Pod可以声明多个imagePullSecret，使得`Kubelet`可以从多个不同的镜像仓库中下载镜像，当`kubectl`下载镜像时，会根据镜像仓库的不同选择合适的imagePullSecret去执行镜像下载操作。

目前，主要有以下两种方式将imagePullSecret绑定到Pod上：

1. 在Pod中直接定义

	可以在Pod定义中，直接声明需要绑定的imagePullSecret，以下为Pod中绑定imagePullSecret定义文件的示例：
	
		apiVersion: v1
		kind: Pod
		metadata:
	  		name: foo
	  		namespace: awesomeapps
		spec:
	  		containers:
	    		- name: foo
	      		  image: janedoe/awesomeapp:v1
	  		imagePullSecrets:
	    		- name: 秘密名称
		    	- name: 秘密名称
		    	- ...
		    	
		    	
2. 在服务账号中定义 

	可以在服务账号中，声明需要绑定到服务账号的imagePullSecret，当服务账号被隐式或者显式的绑定到Pod上时，服务账号中声明的秘密，包括imagePullSecret也自动被绑定到Pod。以下为在服务账号中绑定imagePullSecret定义文件的示例：
	
		apiVersion: v1
		kind: ServiceAccount
		metadata:
  			name: default
  			namespace: default
		imagePullSecrets:
	    	- name: 秘密名称
		    - name: 秘密名称
		    - ...
		
		在Pod中显式的声明服务账号
		
		apiVersion: v1
		kind: Pod
		metadata:
	  		name: foo
	  		namespace: awesomeapps
		spec:
	  		containers:
	    		- name: foo
	      		  image: janedoe/awesomeapp:v1
	      serviceAccountName: 服务账号名称
	      
**注意：**秘密和服务账号都是命名空间敏感的，所以无论在Pod中引用秘密、服务账号或者在服务账号中引用秘密，都只能本命名空间内的秘密和服务账号，不能够跨命名空间引用其它命名空间的秘密和服务。

对于已经存在的服务账号，希望往服务账号中添加或者删除imagePullSecret，可以按照如下步骤实现：

1. 导出现有服务账号的定义文件

		kubectl get serviceaccount 服务账号名称 -o 格式(json或者yaml) > 定义文件路径	
2. 更新服务定义
		
	修改上一步导出的定义文件，在定义文件中添加或者删除imagePullSecret。
3. 更新服务账号

		kubectl replace serviceaccount 服务账号名称 -thef 定义文件路径

### API Token秘密

API Token Secret一般用于绑定到服务账号，用于标识服务账号，从而实现在Pod中能够以服务账号的身份访问API Server，具体的内容可以参看[在Pod中访问API Server]()。

虽然，API Token Secret可以手动创建，但是大多数情况下都不需要手动创建，而是伴随服务账号自动创建，如果确实要手动创建，则可以使用下面的模板进行创建：

	apiVersion: v1
	kind: Secret
	metadata:
	  name: 秘密名称
	  annotations: 
	    kubernetes.io/service-account.name: 服务账号名称
	type: kubernetes.io/service-account-token

创建成功的API Token秘密可以按照普通秘密相同的方式挂载到服务账号或者Pod，在这里就不进行详细讨论了。

## 服务账号的自动化以及授权

Kubernetes内置提供一种机制，可以实现默认服务账号的自动创建和自动挂载，对于大多数情况而言，使用这种内置机制基本上可以满足服务账号的使用要求了。当然如果需要进一步的细化权限，则必须手动创建服务账号手动绑定服务账号了。

Kubernetes通过ServiceAccount插件、Token Controller以及Service Account Controller等三个组件实现服务账号的自动化，下面就这个三个组件的分工做简要概述。

* ServiceAccount插件
	
	ServiceAccount插件运行在API Server中，通过API Server的`--admission-control`参数启用，当启用了ServiceAccunt插件，ServiceAccount插件将在Pod启动或者更新的过程中执行下面的动作：
	1. 确保Pod绑定了服务账号，如果没有显示绑定，则自动绑定到`default`服务账号
	2. 确保Pod绑定的服务账号是存在的，如果不存在，则拒绝Pod启动
	3. 如果Pod没有显示声明`ImagePullSecret`，则自动将服务账号上声明的`ImagePullSecret`绑定到Pod
	4. 将服务账号中绑定的API Token通过卷的方式自动加载到容器的文件系统`/var/run/secrets/kubernetes.io/serviceaccount`
	
* Token Controller

	Token Controller是Kubernetes Controller Manager的一个组件，用于同步服务账号和密码，主要实现了下面的功能：
	* 当服务账号创建时，自动创建一个API Token秘密
	* 当服务账号删除时，自动删除服务账号的所有API Token秘密
	* 当秘密删除时，自动从服务账号中删除引用关系
	* 创建API Token秘密是确保服务账号存在，并且自动添加一个用于访问API的Token
	
* Service Account Controller 

   Service Account Controller用于管理命名空间中的服务账号，并且确保每一个活动的命名空间中都存在`default`服务账号。
   
对于服务账号的授权，在前面的章节中已近做了一些概要的介绍，从本质上来说与用户账号的授权是一样的，只是需要注意服务账号的账号名。

由于服务账号一般用于提供给Pod来访问API Server，所以从安全性的角度来看，尽量限制服务账号为只读，且最好不允许跨命名空间访问（在Kubernetes中，一般采用命名空间的方式来实现多租户）。
   
## 在Pod中访问API Server

在Pod中访问API Server或者说在容器中访问API Server，存在很多种可能的方式，但是从安全性的角度而言，使用服务账号并且只通过安全端口访问API Server是一种受控和安全的访问方式。

如果要使用服务账号访问API Server，建议通过服务账号自动化机制，自动的将用于访问API Server的Token挂载到容器中，在容器中就可以简单的使用Token认证来访问API Server了。

此外，也可以使用`kubectl`的`proxy`命令，创建一个到API Server的代理。当启用Kubectl代理时，在代理中已经处理了服务地址以及认证信息，客户端只需要简单的访问代理提供的地址，就可以以指定的身份访问API Server了。

关于Kubectl代理的详细信息可以参考[访问集群](http://kubernetes.io/docs/user-guide/accessing-the-cluster/#directly-accessing-the-rest-api)。




