## 搭建环境
### Ubuntu
在Ubuntu上安装最新版cloudify（3.3.1）只要运行以下命令即可：
```sh
wget -c http://repository.cloudifysource.org/org/cloudify3/get-cloudify.py
sudo python get-cloudify.py
```

### CentOS
在CentOS上安装cloudify 3.3.1只要运行以下命令即可：
```sh
wget -c http://repository.cloudifysource.org/org/cloudify3/3.3.1/sp-RELEASE/cloudify-centos-Core-cli-3.3.1-sp_b310.x86_64.rpm
sudo yum -y install epel-release
sudo yum clean all
sudo yum -y install python-pip
sudo yum clean all
sudo rpm -i cloudify-centos-Core-cli-3.3.1-sp_b310.x86_64.rpm
source /opt/cfy/env/bin/activate
```

### 查看安装结果
安装完了之后，运行以下命令可以看到cloudify命令行的版本及帮助文档：
```sh
cfy --version
cfy -h
```

## 部署应用
Cloudify的应用被称为[蓝图](http://docs.getcloudify.org/3.3.1/intro/blueprints/)。官方已经为我们的第一次使用准备了一个Hello World：
```sh
wget -c https://github.com/cloudify-examples/simple-python-webserver-blueprint/archive/master.zip
sudo apt-get install -f unzip
unzip master.zip
cd simple-python-webserver-blueprint-master/
```

接下来初始化下载的蓝图并传入端口等参数：
```sh
cfy local init --blueprint-path blueprint.yaml --inputs '{"webserver_port": "8000", "host_ip":"localhost"}'
```

Cloudify使用工作流（workflow）来管理应用程序。现在启动install工作流来部署一个python的web服务器：
```sh
cfy local execute --workflow install
curl localhost:8000
```

通过以下命令可以看到一些运行的参数：
```sh
cfy local outputs
```

我们看到的内容称之为模型（model）。蓝图是应用的模板，蓝图的实例称为部署（deployment），部署就是模型的内容之一。蓝图里的每个实体称之为节点（node），节点在部署里称为节点实例（node-instances），它们是一对多的关系。但是在这个例子里，我们有两个节点，每个节点各有一个节点实例。可以用以下命令查看节点实例：
```sh
cfy local instances
```

可以看到这两个节点实例分别是host和http_web_server，其中http_web_server运行在host之上。可以用以下命令来结束部署：
```sh
cfy local execute -w uninstall
```

## 蓝图解析
使用以下命令查看蓝图的结构：
```sh
cat blueprint.yaml
```

这就是一个yaml格式的文件，里面都是cloudify的DSL。文件分为以下五个部分：
- tosca_definitions_version：蓝图的DSL版本，这里是cloudify_dsl_1_2
- imports：引用yaml文件的地址
- inputs：蓝图的配置信息，也就是一开始初始化蓝图时传入的参数
- node_templates：描述了应用的资源以及应用是如何被部署的，可以跟刚才看到的节点实例相对应起来
- outputs：输出信息，也就是刚才看到的模型里的内容

其中包括了三个内置函数（Intrinsic Functions），分别是`get_input`，`get_property`和`concat`，只能在蓝图里使用。所有的内置函数可以在[这里](http://docs.getcloudify.org/3.3.1/blueprints/spec-intrinsic-functions/)查到。

[TOSCA](https://www.oasis-open.org/committees/tosca/)（Topology and Orchestration Specification for Cloud Applications）是由OASIS组织制定的云应用拓扑编排规范。Cloudify的蓝图是TOSCA的一个实现。TOSCA的简介可以参考[TOSCA简介](tosca.md)。

## 部署容器
Cloudify通过[docker插件](http://docs.getcloudify.org/3.3.1/plugins/docker/)来支持docker。这个插件依赖于Docker Python API库，而不是Docker CLI，所以体验上有所不同。举个例子，`docker run`将会被分解为`docker create`和`docker start`。如果部署一个tomcat容器，首先需要生成一个tomcat容器的蓝图：
```sh
mkdir ../docker
cd ../docker

cat << EOF > blueprint.yaml
tosca_definitions_version: cloudify_dsl_1_2
imports:
  - http://www.getcloudify.org/spec/cloudify/3.4m3/types.yaml
  - http://www.getcloudify.org/spec/docker-plugin/1.3.1/plugin.yaml
inputs:
  host_ip:
      description: >
        The ip of the host the application will be deployed on
      default: 127.0.0.1
  tomcat_container_port_bindings:
    description: >
      A dict of port bindings for the node container.
    default:
      8080: 8080
node_templates:
  host:
    type: cloudify.nodes.Compute
    properties:
      install_agent: false
      ip: { get_input: host_ip }
  tomcat_container:
    type: cloudify.docker.Container
    properties:
      name: tomcat
      image:
        repository: tomcat
        tag: 8.0.30-jre8
    interfaces:
      cloudify.interfaces.lifecycle:
        create:
          implementation: docker.docker_plugin.tasks.create_container
          inputs:
            params:
              stdin_open: true
              tty: true
        start:
          implementation: docker.docker_plugin.tasks.start
          inputs:
            params:
              port_bindings: { get_input: tomcat_container_port_bindings }
    relationships:
      - type: cloudify.relationships.contained_in
        target: host
outputs:
  http_endpoint:
    description: Tomcat web server endpoint
    value: { 'http://localhost:8080' }
EOF
```

要使用这个蓝图，需要先安装docker的插件，然后就可以初始化蓝图：
```sh
cfy local create-requirements -o requirements.txt -p blueprint.yaml
sudo pip install -r requirements.txt
cfy local init -p blueprint.yaml
```

这样就可以运行了。由于第一次运行需要下载镜像，可能会比较慢：
```sh
cfy local execute -w install
docker ps
docker images
curl localhost:8080
```

同样可以查看运行参数和节点实例：
```sh
cfy local outputs
cfy local instances
```

可以用以下命令来结束部署：
```sh
cfy local execute -w uninstall
docker ps -a
```

容器会被删除。

## Cloudify管理器
除了命令行以外，cloudify也支持使用管理器来部署应用。Cloudify管理器有自己的用户界面，提供历史记录、授权和鉴权等功能，并且支持并行运行工作流。启动cloudify管理器就像是启动一个普通的蓝图一样，可是安装需要下载一大堆的依赖，比较繁琐，可以参考[官方教程](http://docs.getcloudify.org/3.3.1/manager/bootstrapping/)。官方另外还提供了一个[vagrant镜像](http://docs.getcloudify.org/3.3.1/manager/getting-started/)，里面已经配置好了整个Cloudify管理器，启动虚拟机后可以直接通过IP访问cloudify管理器的页面。

[官方教程](http://docs.getcloudify.org/3.3.1/manager/getting-started/)也提供了一个如何使用cloudify管理器的样例可供参考。
