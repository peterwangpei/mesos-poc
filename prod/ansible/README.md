
## 运行 ansible 脚本

1. 运行命令 `ansible-playbook -i ansible_inventory ansible/mesos_playbook.yml` 安装docker和mesos集群
2. 运行命令 `ansible-playbook -i ansible_inventory ansible/k8s_playbook.yml` 安装kubernetes


## 验证运行情况 ##

1. 验证 `zookeeper`, `echo stat | nc zookeeper_host 2181`
2. 验证 `mesos master` 和 `mesos slave`， 打开网页 `http://<mesosmaster>:5050`, 查看 master、slave 和 framework 的运行情况
3. 验证 `kubernetes`， 打开网页 `http://<mesosmaster>:8888`, 查看 kubernetes 的运行界面
