
`poc.Vagrantfile` 是一个通过 vagrant 来模拟真实部署环境的一个脚本。可以通过运行 vagrant 来运行脚本，
来启动多个虚拟机，然后通过运行 ansible 脚本来执行自动化安装脚本

## 启动方法

你的电脑必须先安装 `vagrant` `virtualbox` 以及 `ansible`

> 安装过程中，需要下载 docker 镜像，由于网络问题（需要翻墙），可能会失败

1. 将 `poc.Vagrantfile` 重命名为 `Vagrantfile`
2. 运行命令 `vagrant up`, 启动虚拟机
3. 运行命令 `ansible-playbook -i ansible_inventory ansible/playbook.yml`，
将会给虚拟机装上需要安装的软件, 以及运行各种程序


## 在真实环境下运行 ansible 脚本

1. 将 `ansible` 文件夹拷贝到服务器局域网， 运行 ansible 脚本的那台机子必须先安装上 `ansible` 运行环境
2. 修改 `ansible/poc`， 分配角色（ansible group）给不同的计算机，并设置不同计算机登陆密码。
因为会下载 docker 镜像，可能会遇到网络不同的问题。可以通过在 `ansible/poc`设置 `docker_opts` 变量来设置 `docker registry mirror`,
并在 `registry mirror` 中预先下载好需要用到的镜像。需要用到的镜像可以在 `ansible/roles/*/tasks/main.yml` 文件下查看
3. 运行命令 `ansible-playbook -i ansible_inventory ansible/playbook.yml`


## 验证运行情况 ##

1. 验证 `zookeeper`, `echo stat | nc zookeeper_host 2181`
2. 验证 `mesos master` 和 `mesos slave`， 打开网页 `http://mesosmaster:5050`, 查看 slave 和 master 的运行情况
