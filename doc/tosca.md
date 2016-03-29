## 简介
[TOSCA](https://www.oasis-open.org/committees/tosca/)（Topology and Orchestration Specification for Cloud Applications）是由OASIS组织制定的云应用拓扑编排规范。通俗地说，就是制定了一个标准，用来描述云平台上应用的拓扑结构。目前支持XML和YAML，Cloudiy的蓝图就是基于这个规范而来。这个规范比较庞大，本文尽量浓缩了[TOSCA的YAML版](http://docs.oasis-open.org/tosca/TOSCA-Simple-Profile-YAML/v1.0/TOSCA-Simple-Profile-YAML-v1.0.html)前两章。

TOSCA的基本概念只有两个：节点（node）和关系（relationship）。节点有许多类型，可以是一台服务器，一个网络，一个计算节点等等。关系描述了节点之间是如何连接的。举个例子：一个nodejs应用（节点）部署在（关系）名为host的主机（节点）上。节点和关系都可以通过程序来扩展和实现。

目前它的开源实现有OpenStack (Heat-Translator，Tacker，Senlin)，Alien4Cloud，Cloudify等。

## 示例
### Hello World
第一个例子是没有Hello World的Hello World。先看下面这段描述文件：
<pre>
tosca_definitions_version: tosca_simple_yaml_1_0

description: Template for deploying a single server with predefined properties.

topology_template:
  node_templates:
    my_server:
      type: tosca.nodes.Compute
      capabilities:
        host:
          properties:
            num_cpus: 1
            disk_size: 10 GB
            mem_size: 4096 MB
        os:
          properties:
            architecture: x86_64
            type: linux 
            distribution: rhel 
            version: 6.5 
</pre>

除了TOSCA的版本`tosca_definitions_version`和描述信息`description`以外，就是这个`topology_template`了。这里我们看到有一个名为`my_server`的节点，它的类型是`tosca.nodes.Compute`。这个类型预置了两个`capabilities`信息，一个是`host`，定义了硬件信息；另一个是`os`，定义了操作系统信息。

### 输入输出
描述文件如下：
<pre>
topology_template:
  <b style="color:magenta">inputs</b>:
    cpus:
      type: integer
      description: Number of CPUs for the server.
      constraints:
        - valid_values: [ 1, 2, 4, 8 ]
 
  node_templates:
    my_server:
      type: tosca.nodes.Compute
      capabilities:
        host:
          properties:
            num_cpus: { get_input: cpus }
            mem_size: 2048  MB
            disk_size: 10 GB
 
  <b style="color:magenta">outputs</b>:
    server_ip:
      description: The private IP address of the provisioned server.
      value: { get_attribute: [ my_server, private_address ] }
</pre>

这里的`inputs`和`outputs`分别定义了输入和输出。在语义上很容易能看出来输入的`cpus`是在1，2，4和8中的一个整数，而输出的`server_ip`就是`my_server`这个节点的`private_address`也就是私有IP地址。另外一点是TOSCA提供了一些内置函数，在上面这个文件中使用了`get_input`和`get_attribute`。输入参数可以通过`get_input`被使用。

### 安装软件
描述文件如下：
<pre>
topology_template:
  inputs:
    # 略
 
  node_templates:
    mysql:
      type: <b style="color:magenta">tosca.nodes.DBMS.MySQL</b>
      properties:
        root_password: { get_input: my_mysql_rootpw }
        port: { get_input: my_mysql_port }
      <b style="color:magenta">requirements</b>:
        - host: db_server
 
    db_server:
      type: tosca.nodes.Compute
      capabilities:
        # 略
</pre>

我们看到了一个新的节点类型：`tosca.nodes.DBMS.MySQL`。这个类型允许接收`root_password`和`port`的参数。除了节点，关系也出来了。在`requirements`里定义了`mysql`这个节点需要被安装到`db_server`这个节点上。如果只想表明依赖，比如说`service_a`依赖于`service_b`，也可以直接用`- dependency: service_b`来描述。上面文件的拓扑结构如下图：

![](http://docs.oasis-open.org/tosca/TOSCA-Simple-Profile-YAML/v1.0/csprd02/TOSCA-Simple-Profile-YAML-v1.0-csprd02_files/image003.png)

### 初始化数据库
描述文件如下：
<pre>
  node_templates:
    my_db:
      type: <b style="color:magenta">tosca.nodes.Database.MySQL</b>
      properties:
        name: { get_input: database_name }
        user: { get_input: database_user }
        password: { get_input: database_password }
        port: { get_input: database_port }
      <b style="color:magenta">artifacts</b>:
        db_content:
          file: files/my_db_content.txt
          type: tosca.artifacts.File
      requirements:
        - host: mysql
      interfaces:
        <b style="color:magenta">Standard:
          create:
            implementation: db_create.sh</b>
            inputs:
              db_data: { get_artifact: [ SELF, db_content ] }
 
    mysql:
      type: tosca.nodes.DBMS.MySQL
      properties:
        root_password: { get_input: mysql_rootpw }
        port: { get_input: mysql_port }
      requirements:
        - host: db_server
 
    db_server:
      # 略
</pre>

这里的`tosca.nodes.Database.MySQL`表示一个MySQL数据库的实例。在`artifacts`的`db_content`里指定了一个文本文件，而这个文件将被`interfaces`里的`Create`所用，为`db_create.sh`脚本提供数据。`Standard`表示生命周期，可能会包含`configure`、`start`、`stop`等各种操作，而`db_create.sh`本身是对`tosca.nodes.Database.MySQL`提供的默认`create`操作的一个重写。如下图：

![](http://docs.oasis-open.org/tosca/TOSCA-Simple-Profile-YAML/v1.0/csprd02/TOSCA-Simple-Profile-YAML-v1.0-csprd02_files/image004.png)

### 两层应用
描述文件如下：
<pre>
  node_templates:
    wordpress:
      type: tosca.nodes.WebApplication.WordPress
      properties:
        context_root: { get_input: context_root }
        admin_user: { get_input: wp_admin_username }
        admin_password: { get_input: wp_admin_password }
        db_host: { get_attribute: [ db_server, private_address ] }
      <b style="color:magenta">requirements:
        - host: apache
        - database_endpoint: wordpress_db</b>
      interfaces:
        Standard:
          inputs:
            db_host: { get_attribute: [ db_server, private_address ] }
            db_port: { get_property: [ wordpress_db, port ] }
            db_name: { get_property: [ wordpress_db, name ] }
            db_user: { get_property: [ wordpress_db, user ] }
            db_password: { get_property: [ wordpress_db, password ] }  
    apache:
      type: tosca.nodes.WebServer.Apache
      properties:
        # 略
      <b style="color:magenta">requirements:
        - host: web_server</b>
    web_server:
      type: tosca.nodes.Compute
      # 略

    wordpress_db:
      type: tosca.nodes.Database.MySQL
      # 略
    mysql:
      type: tosca.nodes.DBMS.MySQL
      # 略
    db_server:
      type: tosca.nodes.Compute
      # 略
</pre>

这个文件描述了一个很常见的拓扑结构：`mysql`里有一个`wordpress_db`，运行在`db_server`上；`apache`部署了一个`wordpress`，运行在`web_server`上。`wordpress`需要`wordpress_db`。

### 关系定制化
描述文件如下：
<pre>
  node_templates:
    wordpress:
      type: tosca.nodes.WebApplication.WordPress
      properties:
        # 略
      requirements:
        - host: apache
        - database_endpoint:
            node: wordpress_db
            <b style="color:magenta">relationship: my.types.WordpressDbConnection</b>
    wordpress_db:
      type: tosca.nodes.Database.MySQL
      properties:
        # 略
      requirements:
        - host: mysql
  <b style="color:magenta">relationship_templates:
    my.types.WordpressDbConnection:</b>
      type: ConnectsTo
      interfaces:
        Configure:
          pre_configure_source: scripts/wp_db_configure.sh
</pre>

这里的关注点是`relationship`里的`my.types.WordpressDbConnection`。这是一个自定义的关系，在文件的下半部分描述了详细定义。它实际上是一个`ConnectsTo`类型，为`pre_configure_source`操作提供了一个自定义脚本。这个定义也可以单独提出一个文件，就像下面这样：
<pre>
tosca_definitions_version: tosca_simple_yaml_1_0
 
description: Definition of custom WordpressDbConnection relationship type
 
<b style="color:magenta">relationship_types:
  my.types.WordpressDbConnection:</b>
    derived_from: tosca.relationships.ConnectsTo
    interfaces:
      Configure:
        pre_configure_source: scripts/wp_db_configure.sh
</pre>

### 限定需求资源
描述文件如下：
<pre>
  node_templates:
    mysql:
      type: tosca.nodes.DBMS.MySQL
      properties:
        # 略
      requirements:
        - host:
            <b style="color:magenta">node_filter</b>:
              capabilities:
                - host:
                    properties:
                      - num_cpus: { <b style="color:magenta">in_range</b>: [ 1, 4 ] }
                      - mem_size: { <b style="color:magenta">greater_or_equal</b>: 2 GB }
                - os:
                    properties:
                      - architecture: { <b style="color:magenta">equal</b>: x86_64 }
                      - type: linux
                      - distribution: ubuntu
</pre>

需要关注的是`node_filter`。这里并没有指定mysql在哪个节点上启动，但是指定了一些节点信息，只有符合的节点才能够启动它。也可以抽出来做个模板：
<pre>
  node_templates:
    mysql:
      type: tosca.nodes.DBMS.MySQL
      properties:
        # 略
      requirements:
        - host: <b style="color:magenta">mysql_compute</b>
 
    <b style="color:magenta">mysql_compute</b>:
      type: Compute
      node_filter:
        capabilities:
          - host:
              properties:
                num_cpus: { equal: 2 }
                mem_size: { greater_or_equal: 2 GB }
          - os:
              properties:
                architecture: { equal: x86_64 }
                type: linux
                distribution: ubuntu
</pre>

数据库也可以使用：
<pre>
  node_templates:
    my_app:
      type: my.types.MyApplication
      properties:
        admin_user: { get_input: admin_username }
        admin_password: { get_input: admin_password }
        db_endpoint_url: { get_property: [SELF, <b style="color:magenta">database_endpoint</b>, url_path ] }         
      requirements:
        - <b style="color:magenta">database_endpoint</b>:
            node: my.types.nodes.MyDatabase
            <b style="color:magenta">node_filter</b>:
              properties:
                - db_version: { greater_or_equal: 5.5 }
</pre>

上面指定了数据库的版本。也可以抽出来做个模板：
<pre>
  node_templates:
    my_app:
      type: my.types.MyApplication
      properties:
        admin_user: { get_input: admin_username }
        admin_password: { get_input: admin_password }
        db_endpoint_url: { get_property: [SELF, database_endpoint, url_path ] }         
      requirements:
        - database_endpoint: <b style="color:magenta">my_abstract_database</b>
    <b style="color:magenta">my_abstract_database</b>:
      type: my.types.nodes.MyDatabase
      properties:
        - db_version: { greater_or_equal: 5.5 }
</pre>

### 节点模板替换
描述文件如下：
<pre>
  node_templates:
    web_app:
      type: tosca.nodes.WebApplication.MyWebApp
      requirements:
        - host: web_server
        - database_endpoint: <b style="color:magenta">db</b>
 
    web_server:
      type: tosca.nodes.WebServer
      requirements:
        - host: server
 
    server:
      type: tosca.nodes.Compute
      # 略
 
    <b style="color:magenta">db</b>:
      # 这是一个抽象节点
      type: tosca.nodes.Database
      properties:
        user: my_db_user
        password: secret
        name: my_db_name
</pre>

这里的`db`是一个抽象节点，可以被下面的描述文件所替换：
<pre>
topology_template:
  inputs:
    db_user:
      type: string
    # 略
  <b style="color:magenta">substitution_mappings:
    node_type: tosca.nodes.Database
    capabilities:
      database_endpoint: [ database, database_endpoint ]</b>
  node_templates:
    database:
      type: tosca.nodes.Database
      properties:
        user: { get_input: db_user }
        # 略
      requirements:
        - host: dbms
    dbms:
      type: tosca.nodes.DBMS
      # 略
    server:
      type: tosca.nodes.Compute
      # 略
</pre>

这里的`database_endpoint`是由`database`节点提供的`database_endpoint`。两个文件联系起来看，表明了上面的`web_app`不需要管`db`是什么样子的，有什么拓扑结构，它关心的只是`database_endpoint`。而下面由`database`、`dbms`和`server`三个节点组成的模板正好可以提供`database_endpoint`，从而替换掉`db`这个抽象节点。另外，这样的替换也支持嵌套。

### 节点模板组
描述文件如下：
<pre>
  node_templates:
    apache:
      type: tosca.nodes.WebServer.Apache
      properties:
        # 略
      requirements:
        - host: server
    server:
      type: tosca.nodes.Compute
        # 略
  <b style="color:magenta">groups</b>:
    <b style="color:magenta">webserver_group</b>:
      type: tosca.groups.Root
      members: [ apache, server ]

  <b style="color:magenta">policies</b>:
    - my_anti_collocation_policy:
        type: my.policies.anticolocateion
        targets: [ <b style="color:magenta">webserver_group</b> ]
        # 可以一起处理
</pre>

这个例子表明了`apache`和`server`应该是一组的关系。这样它们就可以一起被处理，比如说伸缩。

### YAML宏
描述文件如下：
<pre>
<b style="color:magenta">dsl_definitions:
  my_compute_node_props: &my_compute_node_props</b>
    disk_size: 10 GB
    num_cpus: 1
    mem_size: 2 GB
 
topology_template:
  node_templates:
    my_server:
      type: Compute
      capabilities:
        - host:
            properties: <b style="color:magenta">*my_compute_node_props</b>
 
    my_database:
      type: Compute
      capabilities:
        - host:
            properties: <b style="color:magenta">*my_compute_node_props</b>
</pre>

它使用了宏来避免重复。

### 传参
描述文件如下：
<pre>
  node_templates: 
    wordpress:
      type: tosca.nodes.WebApplication.WordPress
      requirements:
        - database_endpoint: mysql_database
      interfaces:
        Standard:
          <b style="color:magenta">inputs</b>:
            wp_db_port: { get_property: [ SELF, database_endpoint, port ] }
          configure:
            implementation: wordpress_configure.sh           
            <b style="color:magenta">inputs</b>:
              wp_db_port: { get_property: [ SELF, database_endpoint, port ] }
</pre>

这个例子有两个`inputs`，前者指的是为所有操作都声明一个变量，后者指的是为`configure`这个操作声明一个变量。再看下一个文件：
<pre>
  node_templates: 
    frontend: 
      type: MyTypes.SomeNodeType    
      attributes: 
        url: { <b style="color:magenta">get_operation_output</b>: [ SELF, Standard, create, generated_url ] } 
      interfaces: 
        Standard: 
          create: 
            implementation: scripts/frontend/create.sh
          configure: 
            implementation: scripts/frontend/configure.sh 
            inputs: 
              data_dir: { <b style="color:magenta">get_operation_output</b>: [ SELF, Standard, create, data_dir ] }
</pre>

在这个例子里有两个`get_operation_output`，前者指的是将`create`操作的环境变量`generated_url`设置到`url`里，后者是将`data_dir`传递给`configure`操作。

### 取动态值
描述文件如下：
<pre>
node_types:
  ServerNode:
    derived_from: SoftwareComponent
    properties:
      <b style="color:magenta">notification_port</b>:
        type: integer
    capabilities:
      # 略
  ClientNode:
    derived_from: SoftwareComponent
    properties:
      # 略
    requirements:
      - server:
          capability: Endpoint
          node: ServerNode 
          relationship: ConnectsTo
topology_template:          
  node_templates:
    my_server:
      type: ServerNode 
      properties:
        notification_port: 8000
    my_client:
      type: ClientNode
      requirements:
        - server:
            node: my_server
            relationship: <b style="color:magenta">my_connection</b>
  relationship_templates:
    <b style="color:magenta">my_connection</b>:
      type: ConnectsTo
      interfaces:
        Configure:
          inputs:
            <b style="color:magenta">targ_notify_port: { get_attribute: [ TARGET, notification_port ] }</b>
            # 略
</pre>

这个例子里，类型为`ClientNode`的`my_client`在`my_connection`关系的`Configure`操作上需要`notification_port`变量。这样的话，当类型为`ServerNode`的`my_server`连接过来时，就能取到它的`notification_port`变量，并设置到`targ_notify_port`环境变量里。有一点值得注意的是，真实的`notification_port`可能是8000，也可能不是。所以在这种情况下，不用`get_property`，而用`get_attribute`函数。
