###Mesos安装部署

1. 安装Mesosphere软件包
        
        sudo rpm -Uvh http://repos.mesosphere.com/el/7/noarch/RPMS/mesosphere-el-repo-7-1.noarch.rpm
        sudo yum -y install mesos marathon
        #注意：marathon不是必须的
- 安装Zookeeper
         
        sudo rpm -Uvh http://archive.cloudera.com/cdh4/one-click-install/redhat/6/x86_64/cloudera-cdh-4-0.x86_64.rpm
        sudo yum -y install zookeeper zookeeper-server
- 初始化和启动Zookeeper

        sudo -u zookeeper zookeeper-server-initialize --myid=1
        sudo service zookeeper-server start
- 测试安装是否成功

        /usr/lib/zookeeper/bin/zkCli.sh
- 验证是否可以启动或者停止Zookeeper
 
        sudo service zookeeper-server stop
        sudo service zookeeper-server start
        
      