## 运行 ansible 脚本

通过配置 `ansible/playbook.yml` 来配置需要自动安装的模块

~~~~~~
## docker must install in all machine
- include: module/docker.yml
## mesos cluster
- include: module/zookeeper.yml
- include: module/mesos_slave.yml
- include: module/mesos_master.yml
~~~~~~

然后运行命令 `ansible-playbook -i ansible_inventory ansible/playbook.yml` 自动化安装、并允许所需要的环境


## 验证运行情况 ##

1. 验证 `zookeeper`, `echo stat | nc zookeeper_host 2181`
2. 验证 `mesos master` 和 `mesos slave`， 打开网页 `http://<mesosmaster>:5050`, 查看 master、slave 和 framework 的运行情况
3. 验证 `kubernetes`， 打开网页 `http://<mesosmaster>:8888`, 查看 kubernetes 的运行界面
