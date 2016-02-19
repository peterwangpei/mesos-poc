## 运行 ansible 脚本

通过配置 `ansible/playbook.yml` 来配置需要自动安装的模块

~~~~~~
## docker must install in all machine
- include: module/docker.yml
- include: module/docker-configuration.yml
## mesos cluster
- include: module/zookeeper.yml
- include: module/mesos_slave.yml
- include: module/mesos_master.yml
~~~~~~

然后运行命令 `ansible-playbook -i ansible_inventory ansible/playbook.yml` 自动化安装、并允许所需要的环境
运行命令 `ansible-playbook -i ansible_inventory ansible/marathon.yml` 可以自动化安装marathon
运行命令 `ansible-playbook -i ansible_inventory ansible/bamboo.yml` 可以自动化安装bamboo（marathon的服务发现插件，集成了HAPROXY）


## 验证运行情况 ##

1. 验证 `zookeeper`, `echo stat | nc zookeeper_host 2181`
2. 验证 `mesos master` 和 `mesos slave`， 打开网页 `http://<mesosmaster>:5050`, 查看 master、slave 和 framework 的运行情况
3. 验证 `kubernetes`， 打开网页 `http://<k8s>:8888`, 查看 kubernetes 的运行界面
4. 验证 `marathon`， 打开网页 `http://<marathon>:8080`, 查看 marathon 的运行界面
5. 验证 `bamboo`， 打开网页 `http://<marathon>:8000`, 查看 bamboo 的运行界面
